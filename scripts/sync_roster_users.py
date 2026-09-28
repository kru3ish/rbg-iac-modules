#!/usr/bin/env python3
"""Reconcile the engineering roster against Harness account users.

Run this ahead of the OpenTofu apply that builds the teams. It does three
things:

  1. Invites every roster member who is not a Harness account user yet, in one
     bulk call, when INVITE_MISSING_USERS is true.
  2. Works out which roster members are accepted account users right now.
  3. Writes that list onto the IACM workspace as provisioned_emails_csv, so the
     apply only puts real users into user groups.

Step 3 is the one that matters. A Harness user group accepts an email that is
not yet an accepted account user and then quietly drops it: the apply reports
success, the member is missing, and every later plan shows the same phantom
diff that never converges. Feeding the apply a list of users that genuinely
exist keeps the roster convergent, and the members who are still pending are
reported by name rather than disappearing.

Invites are not instant. A user becomes pickable when the invite is accepted,
which for a password account means clicking the emailed link. Accounts using
SAML with AUTO_ACCEPT_SAML_ACCOUNT_INVITES, or SCIM provisioning from the
identity provider, get accepted users immediately and never see a pending
bucket at all.

Environment:
  HARNESS_ACCOUNT_ID        account to reconcile against          (required)
  HARNESS_PLATFORM_API_KEY  API key                               (required)
  ROSTER_FILE               roster to read                        (required)
  WORKSPACE_ORG             org holding the roster workspace      (required)
  WORKSPACE_PROJECT         project holding the roster workspace  (required)
  WORKSPACE_NAME            IACM workspace to write the list to   (required)
  INVITE_MISSING_USERS      "true" to send invites, else report   (default false)
  ROSTER_SYNC_ENV           file to write output variables to     (default ./roster_sync.env)
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

import yaml

ACC = os.environ["HARNESS_ACCOUNT_ID"]
KEY = os.environ["HARNESS_PLATFORM_API_KEY"]
ROSTER_FILE = os.environ["ROSTER_FILE"]
ORG = os.environ["WORKSPACE_ORG"]
PROJ = os.environ["WORKSPACE_PROJECT"]
WS = os.environ["WORKSPACE_NAME"]
INVITE = os.environ.get("INVITE_MISSING_USERS", "false").strip().lower() == "true"
ENV_OUT = os.environ.get("ROSTER_SYNC_ENV", "roster_sync.env")

ROLES = ("owners", "contributors", "approvers")


def call(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "x-api-key": KEY, "Harness-Account": ACC, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw or "{}")
        except ValueError:
            return e.code, {"raw": raw[:400]}


def die(msg):
    sys.exit("roster sync: " + msg)


def roster_emails():
    with open(ROSTER_FILE) as fh:
        doc = yaml.safe_load(fh)
    teams = doc.get("teams") or []
    if not teams:
        die("no teams in %s" % ROSTER_FILE)
    out = set()
    for team in teams:
        for role in ROLES:
            for email in team.get(role) or []:
                out.add(email.strip().lower())
    return doc, sorted(out)


def account_users():
    """Every accepted account user. Pending invites are deliberately not here:
    they are exactly the addresses a user group would drop."""
    seen, page = set(), 0
    while True:
        url = ("https://app.harness.io/ng/api/user/batch"
               "?accountIdentifier=%s&pageIndex=%d&pageSize=100" % (ACC, page))
        code, body = call("POST", url, {"searchTerm": ""})
        if code != 200:
            die("listing users failed [%d]: %s" % (code, str(body)[:200]))
        data = body.get("data") or {}
        content = data.get("content") or []
        for user in content:
            if user.get("email"):
                seen.add(user["email"].strip().lower())
        page += 1
        if len(content) < 100 or page >= (data.get("totalPages") or 1):
            break
    return seen


def invite(emails):
    """One call for the whole batch. Returns the per-address result map."""
    url = "https://app.harness.io/ng/api/user/users?accountIdentifier=%s" % ACC
    code, body = call("POST", url, {"emails": sorted(emails), "userGroups": [], "roleBindings": []})
    if code != 200:
        die("inviting users failed [%d]: %s" % (code, str(body)[:300]))
    return (body.get("data") or {}).get("addUserResponseMap") or {}


def variables_map(raw):
    """The workspace update endpoint wants map[string]VariableRequestBody."""
    return {k: {"key": v.get("key", k), "value": v.get("value", ""),
                "value_type": v.get("value_type", "string")}
            for k, v in (raw or {}).items()}


def set_workspace_variable(name, value):
    """Update one Terraform variable, preserving the rest of the workspace.

    The endpoint replaces the whole workspace, so the current definition is read
    first. Secrets come back as references rather than values, so round-tripping
    them does not expose or break them.
    """
    base = ("https://app.harness.io/iacm/api/orgs/%s/projects/%s/workspaces/%s"
            % (urllib.parse.quote(ORG), urllib.parse.quote(PROJ), urllib.parse.quote(WS)))
    code, ws = call("GET", "%s?accountIdentifier=%s" % (base, ACC))
    if code != 200:
        die("reading workspace %s failed [%d]: %s" % (WS, code, str(ws)[:200]))

    tvars = variables_map(ws.get("terraform_variables"))
    tvars[name] = {"key": name, "value": value, "value_type": "string"}

    payload = {
        "name": ws["name"],
        "description": ws.get("description") or "",
        "provisioner": ws["provisioner"],
        "provisioner_version": ws["provisioner_version"],
        "repository": ws["repository"],
        "repository_branch": ws.get("repository_branch") or "",
        "repository_connector": ws["repository_connector"],
        "repository_path": ws.get("repository_path") or "",
        "cost_estimation_enabled": bool(ws.get("cost_estimation_enabled")),
        "provider_connector": ws.get("provider_connector") or "",
        "terraform_variables": tvars,
        "environment_variables": variables_map(ws.get("environment_variables")),
        "tags": ws.get("tags") or {},
    }
    code, body = call("PUT", "%s?accountIdentifier=%s" % (base, ACC), payload)
    if code not in (200, 201):
        die("updating workspace %s failed [%d]: %s" % (WS, code, str(body)[:300]))


def main():
    doc, roster = roster_emails()
    quarter = doc.get("quarter") or "unspecified"
    existing = account_users()

    missing = [e for e in roster if e not in existing]
    invited = {}
    if missing and INVITE:
        invited = invite(missing)
        existing = account_users()

    accepted = [e for e in roster if e in existing]
    pending = [e for e in roster if e not in existing]

    set_workspace_variable("provisioned_emails_csv", ",".join(accepted))

    print("Roster %s from %s" % (quarter, ROSTER_FILE))
    print("  teams              : %d" % len(doc.get("teams") or []))
    print("  roster members     : %d" % len(roster))
    print("  already users      : %d" % (len(roster) - len(missing)))
    if missing and not INVITE:
        print("  not users yet      : %d (INVITE_MISSING_USERS is false, so no invites were sent)"
              % len(missing))
    elif missing:
        print("  invited this run   : %d" % len(invited))
        for email, result in sorted(invited.items()):
            print("      %-45s %s" % (email, result))
    print("  applied to teams   : %d" % len(accepted))
    if pending:
        print("  awaiting acceptance: %d" % len(pending))
        for email in pending:
            print("      %s" % email)
        print("  These are left out of their teams for now and join automatically on the")
        print("  next run once their account exists. Nothing else in the roster is affected.")
    print("  workspace %s.provisioned_emails_csv updated" % WS)

    with open(ENV_OUT, "w") as fh:
        fh.write("ROSTER_QUARTER=%s\n" % quarter)
        fh.write("ROSTER_MEMBER_COUNT=%d\n" % len(roster))
        fh.write("ACCEPTED_COUNT=%d\n" % len(accepted))
        fh.write("INVITED_COUNT=%d\n" % len(invited))
        fh.write("PENDING_COUNT=%d\n" % len(pending))
        fh.write("PENDING_EMAILS=%s\n" % ",".join(pending))


if __name__ == "__main__":
    main()

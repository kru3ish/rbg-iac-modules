terraform {
  required_providers {
    harness = {
      source = "harness/harness"
      # harness_platform_idp_catalog_entity was introduced in v0.40.0 (2026-01-14).
      version = ">= 0.40.0"
    }
  }
}

locals {
  # The roster committed next to this module is the default source of truth.
  # roster_json exists so the same module can be driven over the API without a
  # commit, which is what the ServiceNow-style callers need.
  roster = var.roster_json != "" ? jsondecode(var.roster_json) : yamldecode(file("${path.module}/${var.roster_file}"))

  quarter          = try(local.roster.quarter, "")
  default_division = try(local.roster.defaults.division, "")
  default_domain   = try(local.roster.defaults.email_domain, var.email_domain)
  default_slack    = try(local.roster.defaults.slack_team_id, var.slack_team_id)

  # Normalise every team to one shape and lower-case every address, so a casing
  # difference between the roster and the account cannot look like a real change.
  teams = { for t in local.roster.teams : t.name => {
    name         = t.name
    description  = try(t.description, "")
    division     = try(t.division, local.default_division)
    owners       = [for e in try(t.owners, []) : lower(trimspace(e))]
    contributors = [for e in try(t.contributors, []) : lower(trimspace(e))]
    approvers    = [for e in try(t.approvers, []) : lower(trimspace(e))]
  } }

  provisioned_raw = concat(
    var.provisioned_emails,
    var.provisioned_emails_csv == "" ? [] : split(",", var.provisioned_emails_csv),
  )
  provisioned = distinct([for e in local.provisioned_raw : lower(trimspace(e)) if trimspace(e) != ""])
  filter_on   = length(local.provisioned) > 0

  # A Harness user group accepts an email that is not yet an accepted account
  # user and then drops it: the apply reports success, the member is missing,
  # and every later plan shows the identical phantom diff, which never
  # converges. So membership is intersected with the provisioned list and the
  # excluded addresses are surfaced as an output and a check warning rather
  # than vanishing.
  teams_resolved = { for name, t in local.teams : name => merge(t, {
    owners       = local.filter_on ? [for e in t.owners : e if contains(local.provisioned, e)] : t.owners
    contributors = local.filter_on ? [for e in t.contributors : e if contains(local.provisioned, e)] : t.contributors
    approvers    = local.filter_on ? [for e in t.approvers : e if contains(local.provisioned, e)] : t.approvers
  }) }

  pending_by_team = { for name, t in local.teams : name => sort(distinct([
    for e in concat(t.owners, t.contributors, t.approvers) : e if !contains(local.provisioned, e)
  ])) if local.filter_on }

  pending_all = sort(distinct(flatten([for name, e in local.pending_by_team : e])))

  roster_members = sort(distinct(flatten([
    for name, t in local.teams : concat(t.owners, t.contributors, t.approvers)
  ])))
}

# A team that disappears from the roster disappears from this map, so OpenTofu
# destroys its user groups and its catalog entity. That is the whole point: the
# quarterly reshuffle is a diff, and removals are handled by the same apply as
# additions, with no ticket and no manual cleanup.
module "team" {
  source   = "../engineering_team"
  for_each = local.teams_resolved

  name         = each.value.name
  description  = each.value.description
  owners       = each.value.owners
  contributors = each.value.contributors
  approvers    = each.value.approvers
  org_id       = each.value.division

  harness_account_id = var.harness_account_id
  harness_org        = var.harness_org
  harness_project    = var.harness_project
  harness_url        = var.harness_url

  email_domain      = local.default_domain
  slack_team_id     = local.default_slack
  annotation_prefix = var.annotation_prefix

  workspace_name    = var.workspace_name
  provisioned_by    = var.provisioned_by
  edit_url_override = var.roster_source_url
}

# Emits a warning on every plan and apply naming the people the roster asks for
# who are not yet Harness users. A warning rather than an error on purpose: the
# rest of the roster still reconciles, and these members join automatically on
# the next run once their account exists.
check "roster_members_are_provisioned" {
  assert {
    condition = length(local.pending_all) == 0
    error_message = format(
      "%d roster member(s) are not accepted Harness account users yet and were left out of their teams: %s. Invite them (or let SCIM provision them) and re-run; nothing else about the roster is affected.",
      length(local.pending_all),
      join(", ", local.pending_all),
    )
  }
}

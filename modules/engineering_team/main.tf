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
  ident       = lower(replace(replace(trimspace(var.name), "/[^a-zA-Z0-9]+/", "_"), "/^_+|_+$/", ""))
  all_members = distinct(concat(var.owners, var.contributors, var.approvers))

  entity_ident = "${local.ident}_team"

  # The IACM workspace this team is provisioned by. The workflow names it
  # RESOURCE_NAME, i.e. Engineering_Team_ plus the name with spaces and dashes
  # turned into underscores, case preserved. Mirror that rule exactly so the
  # link resolves even when workspace_name is not passed in.
  workspace = var.workspace_name != "" ? var.workspace_name : "Engineering_Team_${replace(replace(trimspace(var.name), " ", "-"), "-", "_")}"

  base_url      = "${var.harness_url}/ng/account/${var.harness_account_id}"
  workspace_url = "${local.base_url}/module/iacm/orgs/${var.harness_org}/projects/${var.harness_project}/workspaces/${local.workspace}"

  # Keys here must match the parameters.properties field names in the
  # Engineering_Team Workflow schema - that is what maps each value to its field.
  edit_form_data = jsonencode({
    name                 = var.name
    description          = var.description
    owners               = var.owners
    contributors         = var.contributors
    approvers            = var.approvers
    org_id               = var.org_id
    slack_team_id        = var.slack_team_id
    slack_is_new_project = var.slack_is_new_project
  })

  # urlencode() emits "+" for spaces; the IDP Create form expects %20.
  edit_team_url = join("", [
    local.base_url,
    "/module/idp/create/templates/account.${var.harness_org}.${var.harness_project}/${var.workflow_identifier}",
    "?formData=${replace(urlencode(local.edit_form_data), "+", "%20")}",
  ])

  # Prefix is a variable so each deployment can namespace these under its own
  # domain without editing the module.
  entity_annotations = {
    "${var.annotation_prefix}org-id"         = var.org_id
    "${var.annotation_prefix}slack-team-id"  = var.slack_team_id
    "${var.annotation_prefix}provisioned-by" = "harness-iacm-engineering-team"
  }

  entity_yaml = yamlencode({
    apiVersion = "harness.io/v1"
    kind       = "Group"
    type       = "team"
    identifier = local.entity_ident
    name       = var.name

    spec = merge(
      { profile = { displayName = var.name } },
      length(local.all_members) > 0
      ? { members = [for m in local.all_members : "user:account/${m}"] }
      : {},
    )

    metadata = {
      description = var.description != "" ? var.description : "Engineering Team provisioned via IACM."
      annotations = local.entity_annotations
      links = [
        {
          title = "IACM Workspace"
          url   = local.workspace_url
          icon  = "dashboard"
        },
        {
          title = "Edit this Team"
          url   = local.edit_team_url
          icon  = "edit"
        },
      ]
      tags = var.entity_tags
    }
  })
}

# Account-scoped deliberately, no org_id/project_id. A project-scoped group can
# only hold users who already have access at that scope, but the form's user
# picker queries account scope - so anyone without project access was accepted
# and then silently dropped. Account scope also matches the catalog entity and
# the group:account/<id> refs used throughout this catalog.
#
# Membership goes in user_emails: `users` takes Harness user UUIDs and
# ConflictsWith user_emails, so emails passed there are ignored without error.
#
# One-time migration note for a workspace that already holds project-scoped
# groups: org_id/project_id are not ForceNew on this resource, so changing scope
# plans an in-place update and the apply fails with "User Group in the given
# scope does not exist". Delete the old project-scoped groups once; the next
# refresh drops them from state and creates them at account scope. New teams
# start with empty state and are unaffected.
resource "harness_platform_usergroup" "team" {
  identifier  = local.ident
  name        = var.name
  user_emails = local.all_members
}

resource "harness_platform_usergroup" "owners" {
  identifier  = "${local.ident}_owners"
  name        = "${var.name} - Owners"
  user_emails = var.owners
}

resource "harness_platform_usergroup" "contributors" {
  identifier  = "${local.ident}_contributors"
  name        = "${var.name} - Contributors"
  user_emails = var.contributors
}

resource "harness_platform_usergroup" "approvers" {
  identifier  = "${local.ident}_approvers"
  name        = "${var.name} - Approvers"
  user_emails = var.approvers
}

# Account-scoped Team catalog entity, including its metadata.links.
# Deliberately no org_id/project_id: entity refs are group:account/<id>, matching
# the rest of this catalog. Updates are a full-YAML PUT, so re-running with
# changed owners/contributors/approvers genuinely rewrites spec.members - which
# the Catalog Ingestion API cannot do.
resource "harness_platform_idp_catalog_entity" "team" {
  identifier = local.entity_ident
  kind       = "group"
  yaml       = local.entity_yaml

  depends_on = [
    harness_platform_usergroup.team,
    harness_platform_usergroup.owners,
    harness_platform_usergroup.contributors,
    harness_platform_usergroup.approvers,
  ]
}

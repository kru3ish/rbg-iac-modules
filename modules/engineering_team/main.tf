terraform {
  required_providers {
    harness = {
      source = "harness/harness"
    }
  }
}

locals {
  ident = lower(replace(replace(trimspace(var.name), "/[^a-zA-Z0-9]+/", "_"), "/^_+|_+$/", ""))
  all_members = distinct(concat(var.owners, var.contributors, var.approvers))
}

resource "harness_platform_usergroup" "team" {
  identifier = local.ident
  name       = var.name
  org_id     = var.harness_org
  project_id = var.harness_project
  users      = local.all_members
}

resource "harness_platform_usergroup" "owners" {
  identifier = "${local.ident}_owners"
  name       = "${var.name} - Owners"
  org_id     = var.harness_org
  project_id = var.harness_project
  users      = var.owners
}

resource "harness_platform_usergroup" "contributors" {
  identifier = "${local.ident}_contributors"
  name       = "${var.name} - Contributors"
  org_id     = var.harness_org
  project_id = var.harness_project
  users      = var.contributors
}

resource "harness_platform_usergroup" "approvers" {
  identifier = "${local.ident}_approvers"
  name       = "${var.name} - Approvers"
  org_id     = var.harness_org
  project_id = var.harness_project
  users      = var.approvers
}

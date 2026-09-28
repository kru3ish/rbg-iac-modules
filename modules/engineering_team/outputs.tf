output "team_identifier" {
  value = local.ident
}

output "owners_count" {
  value = length(var.owners)
}

output "contributors_count" {
  value = length(var.contributors)
}

output "approvers_count" {
  value = length(var.approvers)
}

output "catalog_entity_identifier" {
  value = harness_platform_idp_catalog_entity.team.identifier
}

output "catalog_entity_ref" {
  value = "group:account/${local.entity_ident}"
}

output "edit_team_url" {
  value = local.edit_team_url
}

output "workspace_url" {
  value = local.workspace_url
}

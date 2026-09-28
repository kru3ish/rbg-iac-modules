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

output "parent_group_ref" {
  value       = local.parent_group
  description = "Division group this team rolls up into, empty when no division was given"
}

output "notification_email" {
  value = local.notification_email
}

output "entity_yaml" {
  value       = local.entity_yaml
  description = "The exact Team entity YAML this module PUTs, handy for reading back in the apply log"
}

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

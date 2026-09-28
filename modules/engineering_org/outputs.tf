output "quarter" {
  value       = local.quarter
  description = "Roster period this state represents"
}

output "team_count" {
  value = length(local.teams)
}

output "teams" {
  value       = sort(keys(local.teams))
  description = "Teams this workspace owns. A name that leaves this list on the next apply has its user groups and catalog entity destroyed."
}

output "catalog_entity_refs" {
  value       = { for name, m in module.team : name => m.catalog_entity_ref }
  description = "Entity ref of each team, usable as a spec.owner or parent elsewhere in the catalog"
}

output "team_identifiers" {
  value       = { for name, m in module.team : name => m.team_identifier }
  description = "Harness user group identifier backing each team"
}

output "membership" {
  value = { for name, t in local.teams_resolved : name => {
    owners       = t.owners
    contributors = t.contributors
    approvers    = t.approvers
  } }
  description = "Membership actually applied, after the provisioned-user filter"
}

output "roster_member_count" {
  value       = length(local.roster_members)
  description = "Distinct people named anywhere in the roster"
}

output "provisioned_filter_active" {
  value       = local.filter_on
  description = "False means no provisioned list was supplied, so membership was applied verbatim and un-provisioned addresses will be dropped by Harness without warning"
}

output "pending_members" {
  value       = local.pending_by_team
  description = "Per team, the roster members that are not Harness users yet and so were not added"
}

output "pending_member_count" {
  value = length(local.pending_all)
}

output "summary" {
  value = join("\n", concat(
    ["Roster ${local.quarter}: ${length(local.teams)} team(s), ${length(local.roster_members)} distinct member(s)."],
    [for name in sort(keys(local.teams_resolved)) :
      format("  %-28s %d owner(s), %d contributor(s), %d approver(s)",
        name,
        length(local.teams_resolved[name].owners),
        length(local.teams_resolved[name].contributors),
        length(local.teams_resolved[name].approvers),
      )
    ],
    local.filter_on ? [] : ["No provisioned-user list supplied: membership applied verbatim."],
    length(local.pending_all) == 0 ? [] : ["Awaiting a Harness account (${length(local.pending_all)}): ${join(", ", local.pending_all)}"],
  ))
  description = "Human-readable reconcile summary, printed in the apply log"
}

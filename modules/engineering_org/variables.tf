variable "roster_file" {
  type        = string
  default     = "roster.yaml"
  description = "Roster file to read, relative to this module directory. This is the source of truth: a quarterly reshuffle is a pull request against it."
}

variable "roster_json" {
  type        = string
  default     = ""
  description = "JSON roster that overrides roster_file when set, for callers that pass the roster in over the API instead of committing it."
}

variable "provisioned_emails" {
  type        = list(string)
  default     = []
  description = "Emails that are accepted Harness account users. When non-empty, team membership is intersected with this list and anything outside it is reported as pending instead of being silently dropped. Empty disables the filter."
}

variable "provisioned_emails_csv" {
  type        = string
  default     = ""
  description = "Comma-separated form of provisioned_emails, for pipeline steps that can only emit a flat string. Merged with provisioned_emails."
}

variable "harness_account_id" {
  type        = string
  description = "Account the catalog entity links point at. No default on purpose - a wrong account produces links that resolve but show the wrong catalog."
}

variable "harness_org" {
  type        = string
  description = "Harness org holding the roster IACM workspace, used to build the workspace link"
}

variable "harness_project" {
  type        = string
  description = "Harness project holding the roster IACM workspace, used to build the workspace link"
}

variable "harness_url" {
  type    = string
  default = "https://app.harness.io"
}

variable "workspace_name" {
  type        = string
  default     = "Engineering_Org_Roster"
  description = "IACM workspace backing every team in this roster. One workspace holds the whole org, which is what lets a single apply reconcile the entire quarter, removals included."
}

variable "annotation_prefix" {
  type        = string
  default     = "team.internal/"
  description = "Namespace for the entity annotations the team module writes. Set it to your own domain, e.g. example.com/"
}

variable "email_domain" {
  type        = string
  default     = ""
  description = "Fallback domain used to derive each team's notification address when the roster does not set defaults.email_domain"
}

variable "slack_team_id" {
  type        = string
  default     = ""
  description = "Fallback Slack workspace id when the roster does not set defaults.slack_team_id"
}

variable "roster_source_url" {
  type        = string
  default     = ""
  description = "URL of the roster file in git. Becomes each team's Edit this Team link, so the catalog sends people to the pull request path rather than to the single-team form, which would create a second Terraform state fighting over the same user groups."
}

variable "provisioned_by" {
  type        = string
  default     = "harness-iacm-engineering-org-roster"
  description = "provisioned-by annotation stamped on every team in this roster, so roster-managed teams are distinguishable from single-team ones in the catalog."
}

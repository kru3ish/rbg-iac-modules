variable "name" {
  type        = string
  description = "Name of the Engineering Team (used to derive the Harness user group identifier and name)"
}

variable "description" {
  type    = string
  default = ""
}

variable "owners" {
  type    = list(string)
  default = []
}

variable "contributors" {
  type    = list(string)
  default = []
}

variable "approvers" {
  type    = list(string)
  default = []
}

variable "org_id" {
  type        = string
  default     = ""
  description = "Division / business-unit the team belongs to. Not a Harness scope identifier - it becomes the division annotation and, lower-cased, the parent group ref."
}

variable "parent_group" {
  type        = string
  default     = ""
  description = "Entity ref of the parent division group, e.g. group:account/rba. Empty derives it from org_id."
}

variable "notification_email" {
  type        = string
  default     = ""
  description = "Team notification address written to spec.profile.email. Empty derives it from the name plus email_domain."
}

variable "email_domain" {
  type        = string
  default     = ""
  description = "Domain used to derive the team notification address when notification_email is not set, e.g. example.com"
}

variable "slack_team_id" {
  type    = string
  default = ""
}

variable "slack_is_new_project" {
  type    = bool
  default = true
}

variable "harness_org" {
  type        = string
  description = "Harness org holding the IACM workspace, used to build the workspace link"
}

variable "harness_project" {
  type        = string
  description = "Harness project holding the IACM workspace, used to build the workspace link"
}

variable "harness_url" {
  type    = string
  default = "https://app.harness.io"
}

variable "harness_account_id" {
  type        = string
  default     = "Qjf4MwsLRUes1w_efM3eIw"
  description = "Account the catalog entity links point at"
}

variable "workflow_identifier" {
  type        = string
  default     = "Engineering_Team"
  description = "Identifier of the Workflow template the Edit this Team link opens"
}

variable "annotation_prefix" {
  type        = string
  default     = "team.internal/"
  description = "Namespace for the entity annotations this module writes. Set it to your own domain, e.g. example.com/"
}

variable "entity_tags" {
  type        = list(string)
  default     = []
  description = "Tags applied to the Team catalog entity. Empty derives [<division>, team], matching the teams already in the catalog."
}

variable "workspace_name" {
  type        = string
  default     = ""
  description = "IACM workspace backing this team. Empty mirrors the workflow's RESOURCE_NAME rule."
}

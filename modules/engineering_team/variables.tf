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
  default     = "RBA"
  description = "RBG division/org tag, stored as a group description suffix - not a Harness scope identifier"
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
  type    = string
  default = "Playground"
}

variable "harness_project" {
  type    = string
  default = "RBG_Golden_Path"
}

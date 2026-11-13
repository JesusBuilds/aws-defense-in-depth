variable "region" {
  type    = string
  default = "us-east-1"
}
variable "project" {
  type    = string
  default = "defense-in-depth"
}
variable "enable_guardduty" {
  type    = bool
  default = true
}
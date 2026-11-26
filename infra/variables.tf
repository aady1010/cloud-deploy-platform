variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}
variable "project_name" {
  type    = string
  default = "cloud-deploy"
}
variable "environment" {
  type    = string
  default = "production"
}
variable "image_tag" {
  type        = string
  description = "Docker image tag (git SHA) to deploy"
}
variable "container_port" {
  type    = number
  default = 8080
}
variable "cpu" {
  type    = number
  default = 256
}
variable "memory" {
  type    = number
  default = 512
}
variable "desired_count" {
  type    = number
  default = 2
}
variable "min_capacity" {
  type    = number
  default = 2
}
variable "max_capacity" {
  type    = number
  default = 6
}
variable "alert_email" {
  type        = string
  default     = ""
  description = "Email subscribed to the alarm SNS topic (confirm the subscription email)"
}
variable "certificate_arn" {
  type        = string
  default     = ""
  description = "ACM certificate ARN. If set, enables HTTPS and redirects HTTP to HTTPS"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "todo-list"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "repo_url" {
  type        = string
  description = "URL HTTPS del repo publico de GitHub"
}

variable "app_version" {
  type    = string
  default = "v0.1.0"
}

variable "alert_email" {
  type        = string
  description = "Correo que recibe las notificaciones de las alarmas"
}


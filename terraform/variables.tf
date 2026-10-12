variable "docker_host" {
  description = "Docker daemon endpoint (the VM prepared by Ansible)"
  type        = string
  default     = "ssh://deployer@10.0.2.15"
}

variable "nginx_image" {
  description = "Pinned nginx image"
  type        = string
  default     = "nginx:1.27-alpine"
}

variable "external_port" {
  description = "Non-standard host port for the Terraform-managed nginx"
  type        = number
  default     = 8080

  validation {
    condition     = var.external_port > 1024 && var.external_port < 65536 && var.external_port != 80
    error_message = "Use a non-standard, unprivileged port (1025-65535, not 80)."
  }
}

output "url" {
  description = "Where the Terraform-managed nginx is reachable"
  value       = "http://10.0.2.15:${var.external_port}"
}

output "network" {
  value = docker_network.tf_net.name
}

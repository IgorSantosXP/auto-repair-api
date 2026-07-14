output "cluster_name" {
  value = kind_cluster.this.name
}

output "kubeconfig_path" {
  value = kind_cluster.this.kubeconfig_path
}

output "api_url" {
  value = "http://localhost:${var.api_host_port}"
}

output "mailpit_url" {
  value = "http://localhost:${var.mailpit_host_port}"
}

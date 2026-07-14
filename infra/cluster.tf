resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 30080
        host_port      = var.api_host_port
      }

      extra_port_mappings {
        container_port = 30025
        host_port      = var.mailpit_host_port
      }
    }

    node {
      role = "worker"
    }
  }
}

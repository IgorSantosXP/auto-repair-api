variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "auto-repair"
}

variable "postgres_password" {
  description = "Password for the postgres user inside the cluster"
  type        = string
  default     = "auto_repair_local_pg"
  sensitive   = true
}

variable "api_host_port" {
  description = "Host port mapped to the API NodePort (30080)"
  type        = number
  default     = 8080
}

variable "mailpit_host_port" {
  description = "Host port mapped to the Mailpit UI NodePort (30025)"
  type        = number
  default     = 8026
}

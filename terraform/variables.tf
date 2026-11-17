variable "project" {
  type    = string
  default = "auto-repair"
}

variable "service" {
  description = "Service name, also the value of the `destination` message attribute this queue receives"
  type        = string
  default     = "os"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environments" {
  description = "Environment => Kubernetes namespace where the service runs"
  type        = map(string)
  default = {
    prod    = "auto-repair-prod"
    homolog = "auto-repair-homolog"
  }
}

variable "service_account" {
  description = "Kubernetes service account used by the api and worker pods"
  type        = string
  default     = "os-service"
}

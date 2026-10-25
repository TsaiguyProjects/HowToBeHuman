variable "ovh_endpoint" {
  description = "OVHcloud API endpoint (ovh-eu, ovh-us, ovh-ca)."
  type        = string
  default     = "ovh-eu"
}

variable "ovh_application_key" {
  description = "OVHcloud API application key (prefer OVH_APPLICATION_KEY env var)."
  type        = string
  default     = null
  sensitive   = true
}

variable "ovh_application_secret" {
  description = "OVHcloud API application secret (prefer OVH_APPLICATION_SECRET env var)."
  type        = string
  default     = null
  sensitive   = true
}

variable "ovh_consumer_key" {
  description = "OVHcloud API consumer key (prefer OVH_CONSUMER_KEY env var)."
  type        = string
  default     = null
  sensitive   = true
}

variable "service_name" {
  description = "Public Cloud project ID (also via OVH_CLOUD_PROJECT_SERVICE env var)."
  type        = string
}

variable "project_name" {
  description = "App/infra name prefix."
  type        = string
  default     = "how-to-be-human"
}

variable "kube_region" {
  description = "Managed Kubernetes region (e.g. GRA11, DE1, EU-WEST-PAR)."
  type        = string
  default     = "GRA11"
}

variable "kube_version" {
  description = "Kubernetes version. Leave null to accept the MKS default."
  type        = string
  default     = null
}

variable "node_flavor" {
  description = "Node pool flavor (e.g. b3-8 = 3 vCPU / 8 GB)."
  type        = string
  default     = "b3-8"
}

variable "node_count" {
  description = "Desired worker node count."
  type        = number
  default     = 2
}

variable "nodepool_autoscale" {
  description = "Enable node pool autoscaling."
  type        = bool
  default     = false
}

variable "nodepool_min_nodes" {
  description = "Minimum nodes when autoscaling."
  type        = number
  default     = 1
}

variable "nodepool_max_nodes" {
  description = "Maximum nodes when autoscaling."
  type        = number
  default     = 4
}

variable "registry_region" {
  description = "Managed Private Registry region (e.g. GRA, DE, EU-WEST-PAR)."
  type        = string
  default     = "GRA"
}

variable "registry_plan" {
  description = "Managed Private Registry plan (SMALL, MEDIUM, LARGE)."
  type        = string
  default     = "SMALL"
}

variable "registry_name" {
  description = "Managed Private Registry name."
  type        = string
  default     = "how-to-be-human"
}

variable "harbor_project" {
  description = "Harbor project inside the registry for app images (created in the Harbor UI)."
  type        = string
  default     = "how-to-be-human"
}

variable "registry_user_email" {
  description = "Email for the Harbor registry user created by Terraform."
  type        = string
  default     = "registry@how-to-be-human.local"
}

variable "registry_user_login" {
  description = "Login for the Harbor registry user created by Terraform."
  type        = string
  default     = "how-to-be-human-ci"
}

variable "enable_cloudflare_edge" {
  description = "Manage a proxied Cloudflare DNS record and optional content-route challenge. Requires an existing Cloudflare zone."
  type        = bool
  default     = false
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the website domain."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_hostname" {
  description = "Website hostname to proxy through Cloudflare, e.g. www.example.com or example.com."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_origin_ipv4" {
  description = "Public IPv4 address of the OVHcloud Ingress LoadBalancer or VM origin."
  type        = string
  default     = null
  nullable    = true
}

variable "cloudflare_content_path_prefix" {
  description = "Optional URL path prefix for a Managed Challenge rule (e.g. /api/content). Leave null to create DNS/CDN only."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.cloudflare_content_path_prefix == null || can(regex("^/[A-Za-z0-9/_-]*$", var.cloudflare_content_path_prefix))
    error_message = "cloudflare_content_path_prefix must start with / and contain only letters, digits, /, _ or -."
  }
}

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = ">= 1.9.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# OVHcloud provider. Auth via env vars (preferred, keeps secrets out of git):
#   export OVH_ENDPOINT="ovh-eu" \
#          OVH_APPLICATION_KEY="..." OVH_APPLICATION_SECRET="..." \
#          OVH_CONSUMER_KEY="..." OVH_CLOUD_PROJECT_SERVICE="<project-id>"
# Or copy terraform.tfvars.example to terraform.tfvars (gitignored).
provider "ovh" {
  endpoint           = var.ovh_endpoint
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

# Optional Cloudflare edge resources. Set CLOUDFLARE_API_TOKEN when
# enable_cloudflare_edge is true; use a token scoped to the target zone.
provider "cloudflare" {}

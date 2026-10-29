# Cloudflare Free edge setup is opt-in. The Cloudflare zone must already exist,
# and its nameservers must be delegated to Cloudflare for proxy/WAF controls to apply.

resource "cloudflare_dns_record" "website" {
  count = var.enable_cloudflare_edge ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = var.cloudflare_hostname
  type    = "A"
  content = var.cloudflare_origin_ipv4
  ttl     = 1 # Cloudflare automatic TTL
  proxied = true

  lifecycle {
    precondition {
      condition = (
        var.cloudflare_zone_id != null &&
        var.cloudflare_hostname != null &&
        var.cloudflare_origin_ipv4 != null
      )
      error_message = "Set cloudflare_zone_id, cloudflare_hostname, and cloudflare_origin_ipv4 when enable_cloudflare_edge is true."
    }
  }
}

# Challenge only a dedicated content endpoint, not the whole SPA or health/API
# surface. This rule is absent unless a route prefix is explicitly configured.
resource "cloudflare_ruleset" "content_managed_challenge" {
  count = var.enable_cloudflare_edge && var.cloudflare_content_path_prefix != null ? 1 : 0

  zone_id     = var.cloudflare_zone_id
  name        = "HowToBeHuman content endpoint challenge"
  description = "Managed Challenge for the configured public content route."
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  lifecycle {
    precondition {
      condition     = var.cloudflare_zone_id != null
      error_message = "Set cloudflare_zone_id when enable_cloudflare_edge and cloudflare_content_path_prefix are configured."
    }
  }

  rules = [{
    ref         = "challenge_content_endpoint"
    description = "Challenge requests for the configured content route prefix."
    expression  = "starts_with(http.request.uri.path, \"${var.cloudflare_content_path_prefix}\")"
    action      = "managed_challenge"
    enabled     = true
  }]
}

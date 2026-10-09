# OVHcloud infrastructure for HowToBeHuman.
# Provisions: Managed Kubernetes cluster + node pool, Managed Private
# Registry (Harbor) + registry user for CI/deploy image pushes.
#
# Previous provider mapping:
#   T-Cloud CCE cluster + node pool -> ovh_cloud_project_kube + nodepool
#   T-Cloud SWR organization        -> OVHcloud Managed Private Registry (+ Harbor project)
#   CCE ELB Ingress annotations     -> NGINX Ingress (see ../k8s/ingress.yaml;
#                                      install via Helm, exposed by an OVH LoadBalancer)

resource "ovh_cloud_project_kube" "app" {
  service_name = var.service_name
  name         = "${var.project_name}-mks"
  region       = var.kube_region
  version      = var.kube_version
}

resource "ovh_cloud_project_kube_nodepool" "workers" {
  service_name   = ovh_cloud_project_kube.app.service_name
  kube_id        = ovh_cloud_project_kube.app.id
  name           = "${var.project_name}-pool"
  flavor_name    = var.node_flavor
  desired_nodes  = var.node_count
  min_nodes      = var.nodepool_autoscale ? var.nodepool_min_nodes : null
  max_nodes      = var.nodepool_autoscale ? var.nodepool_max_nodes : null
  autoscale      = var.nodepool_autoscale
  monthly_billed = false
}

data "ovh_cloud_project_capabilities_containerregistry_filter" "registry" {
  service_name = var.service_name
  plan_name    = var.registry_plan
  region       = var.registry_region
}

resource "ovh_cloud_project_containerregistry" "app" {
  service_name = data.ovh_cloud_project_capabilities_containerregistry_filter.registry.service_name
  plan_id      = data.ovh_cloud_project_capabilities_containerregistry_filter.registry.id
  region       = data.ovh_cloud_project_capabilities_containerregistry_filter.registry.region
  name         = var.registry_name
}

resource "ovh_cloud_project_containerregistry_user" "ci" {
  service_name = ovh_cloud_project_containerregistry.app.service_name
  registry_id  = ovh_cloud_project_containerregistry.app.id
  email        = var.registry_user_email
  login        = var.registry_user_login
}

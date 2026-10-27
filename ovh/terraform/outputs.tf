output "kube_id" {
  description = "Managed Kubernetes cluster ID."
  value       = ovh_cloud_project_kube.app.id
}

output "kubeconfig" {
  description = "Cluster kubeconfig (use `terraform output -raw kubeconfig > kubeconfig.yaml`)."
  value       = ovh_cloud_project_kube.app.kubeconfig
  sensitive   = true
}

output "registry_url" {
  description = "Harbor registry URL for `docker login` and image paths."
  value       = ovh_cloud_project_containerregistry.app.url
}

output "registry_user" {
  description = "Harbor user for CI/deploy pushes."
  value       = ovh_cloud_project_containerregistry_user.ci.user
}

output "registry_password" {
  description = "Harbor password for CI/deploy pushes."
  value       = ovh_cloud_project_containerregistry_user.ci.password
  sensitive   = true
}

output "backend_image" {
  description = "Push backend here (tag with :<git-sha> or :latest)."
  value       = "${ovh_cloud_project_containerregistry.app.url}/${var.harbor_project}/backend"
}

output "frontend_image" {
  value = "${ovh_cloud_project_containerregistry.app.url}/${var.harbor_project}/frontend"
}

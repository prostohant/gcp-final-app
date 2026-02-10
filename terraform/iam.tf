module "service_accounts" {
  source        = "terraform-google-modules/service-accounts/google//modules/simple-sa"
  project_id    = var.project_id
  name         = "cicd-builder"
  project_roles = [
    "roles/artifactregistry.writer",
    "roles/logging.logWriter"
  ]
  display_name  = "CI/CD builder"
}
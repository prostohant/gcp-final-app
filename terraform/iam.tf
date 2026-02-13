module "service_account_builder" {
  source     = "terraform-google-modules/service-accounts/google//modules/simple-sa"
  name       = "cicd-builder"
  project_id = var.project_id
  project_roles = [
    "roles/artifactregistry.writer",
    "roles/logging.logWriter"
  ]
  display_name = "CI/CD builder"
}

data "google_storage_project_service_account" "gcs_account" {}
resource "google_project_iam_member" "gcs_account_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

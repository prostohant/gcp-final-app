
resource "google_cloudbuild_trigger" "ingestion_trigger" {
  name        = "ingestion-dir-trigger"
  project = var.project_id
  location      = var.region
  service_account = module.service_accounts.id
  description = "Trigger for changes in the ingestion directory"

  github {
    owner = "prostohant"
    name  = "gcp-homework-ci"
    push {
      branch = "^main$"
    }
  }
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  included_files = ["ingestion/**"]
  filename = "cloudbuild-ingestor.yaml"

}
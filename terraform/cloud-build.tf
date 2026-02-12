
resource "google_cloudbuild_trigger" "ingestion_trigger" {
  name            = "ingestion-dir-trigger"
  project         = var.project_id
  location        = var.region
  service_account = module.service_accounts.id
  description     = "Trigger for changes in the ingestion directory"

  github {
    owner = "prostohant"
    name  = "gcp-final-app"
    push {
      branch = "^main$"
    }
  }
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  included_files     = ["ingestion/**"]
  filename           = "cloudbuild-ingestor.yaml"

}

resource "google_cloudbuild_trigger" "app_trigger" {
  name            = "app-dir-trigger"
  project         = var.project_id
  location        = var.region
  service_account = module.service_accounts.id
  description     = "Trigger for changes in the app directory"

  github {
    owner = "prostohant"
    name  = "gcp-final-app"
    push {
      branch = "^main$"
    }
  }
  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
  included_files     = ["app/**"]
  filename           = "cloudbuild-app.yaml"
}

#  
resource "terraform_data" "trigger_run_ingestion" {
  count = var.build_applications ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
      gcloud builds triggers run ${google_cloudbuild_trigger.ingestion_trigger.name} \
        --region=${var.region} \
        --branch=main
    EOT
  }
}
resource "terraform_data" "trigger_run_app" {
  count = var.build_applications ? 1 : 0
  provisioner "local-exec" {
    command = <<EOT
      gcloud builds triggers run ${google_cloudbuild_trigger.app_trigger.name} \
        --region=${var.region} \
        --branch=main
    EOT
  }
}
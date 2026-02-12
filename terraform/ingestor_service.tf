#cloud store
module "gcs_bucket" {
  source     = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  project_id = var.project_id
  location   = var.region
  name       = "docs-landing-zone-${var.project_id}"
}

resource "google_cloud_run_service" "ingestion" {
  name     = "rag-ingestor"
  location = var.region

  template {
    spec {
      containers {
        image = "${google_artifact_registry_repository.my-repo.registry_uri}/ingestion:latest"
        env {
          name  = "PROJECT_ID"
          value = "training-user-a-khlyst"
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_eventarc_trigger" "doc_upload_trigger" {
  name     = "doc-upload-trigger"
  location = var.region

  matching_criteria {
    attribute = "bucket"
    value     = module.gcs_bucket.name
  }
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  service_account = "${var.project_number}-compute@developer.gserviceaccount.com"
  destination {
    cloud_run_service {
      service = google_cloud_run_service.ingestion.name
      region  = var.region
    }
  }

}



#depends on
# Servive account
# "google_artifact_registry_repository" "my-repo"
# repo us-central1-docker.pkg.dev/$PROJECT_ID/my-app-repo/ingestion:
#vertex AI



#event arc

# output "debug" {
#  value = "${google_artifact_registry_repository.my-repo.registry_uri}/ingestion:latest"
# }

# output "debug" {
#  value = data.google_storage_project_service_account.gcs_account.email_address
# }
# data "google_storage_project_service_account" "gcs_account" {}

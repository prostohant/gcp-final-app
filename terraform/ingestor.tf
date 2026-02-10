#cloud store
module "gcs_bucket" {
  source     = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  project_id = var.project_id
  location   = var.region
  name       = "docs-landing-zone-${var.project_id}"
}

#Cloud run ingestion
resource "google_cloud_run_service" "ingestion" {
  name     = "ingestion-srv"
  location   = var.region
  
  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

#depends on
# Servive account
# "google_artifact_registry_repository" "my-repo"
# repo us-central1-docker.pkg.dev/$PROJECT_ID/my-app-repo/ingestion:
#vertex AI



#event arc
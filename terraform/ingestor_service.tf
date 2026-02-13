#cloud store
module "gcs_bucket" {
  source     = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  project_id = var.project_id
  location   = var.region
  name       = "docs-landing-zone-${var.project_id}"
}
resource "null_resource" "build_ingestion_image" {
  provisioner "local-exec" {
    command = "gcloud builds triggers run ${google_cloudbuild_trigger.ingestion_trigger.name} --branch=main --region=${var.region}"
  }
  depends_on = [ google_cloudbuild_trigger.ingestion_trigger ]
}

resource "null_resource" "wait_for_ingestion_image" {
  provisioner "local-exec" {
    command = "until gcloud artifacts docker images describe ${google_artifact_registry_repository.my-repo.registry_uri}/ingestion:latest> /dev/null 2>&1; do sleep 10; done"
  }
  depends_on = [ null_resource.build_ingestion_image ]
}

resource "google_cloud_run_service" "ingestion" {
  name     = "rag-ingestor"
  location = var.region
  depends_on = [ null_resource.wait_for_ingestion_image ]
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

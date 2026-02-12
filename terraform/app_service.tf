resource "google_cloud_run_service" "apis" {
  name     = "rag-agent"
  location   = var.region

  template {
    spec {
      containers {
        image = "${google_artifact_registry_repository.my-repo.registry_uri}/app:latest"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

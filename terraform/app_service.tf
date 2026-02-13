resource "null_resource" "build_app_image" {
  provisioner "local-exec" {
    command = "gcloud builds triggers run ${google_cloudbuild_trigger.app_trigger.name} --branch=main --region=${var.region}"
  }
  depends_on = [ google_cloudbuild_trigger.app_trigger ]
}

resource "null_resource" "wait_for_app_image" {
  provisioner "local-exec" {
    command = "until gcloud artifacts docker images describe ${google_artifact_registry_repository.my-repo.registry_uri}/app:latest> /dev/null 2>&1; do sleep 10; done"
  }
  depends_on = [ null_resource.build_app_image ]
}
resource "google_cloud_run_service" "apis" {
  name     = "rag-agent"
  location = var.region
  depends_on = [ null_resource.wait_for_app_image ]
  # service_account_name 
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

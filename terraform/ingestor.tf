#cloud store
module "gcs_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  project_id = var.project_id
  location = var.region
  name = "docs-landing-zone-${var.project_id}"
}
#event arc
#Cloud run 
  #depends on
    # Servive account
    # "google_artifact_registry_repository" "my-repo"
    # repo us-central1-docker.pkg.dev/$PROJECT_ID/my-app-repo/ingestion:

#vertex AI

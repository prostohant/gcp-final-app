#cloud store
module "gcs_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  project_id = var.project_id
  location = var.region
  name = "docs-landing-zone-${var.project_id}"
}
#event arc
#Cloud run 
#vertex AI

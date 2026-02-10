terraform {
  backend "gcs" {
    bucket = "tf-state-akhlyst"
    prefix = "terraform-final/state"
  }
}
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
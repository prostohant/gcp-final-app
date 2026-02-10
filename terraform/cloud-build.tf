resource "google_cloudbuild_trigger" "trigger-ingestor" {
  name =  "building-ingestor"
  location = var.region
  source_to_build {
    uri       = "hhttps://github.com/prostohant/gcp-homework-ci.git"
    ref       = "refs/heads/main"
    repo_type = "GITHUB"
  }
  filename = "cloudbuild-ingestor.yaml"
}
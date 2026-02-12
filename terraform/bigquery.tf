resource "google_bigquery_dataset" "rag_dataset" {
  dataset_id = "enterprise_rag_v2"
  location   = "US"
  # depends_on = [google_project_service.apis]
}

# Table for storing text chunks and their embeddings
resource "google_bigquery_table" "doc_embeddings" {
  dataset_id          = google_bigquery_dataset.rag_dataset.dataset_id
  table_id            = "doc_embeddings"
  deletion_protection = false

  # Scheme: content (String) and vector (Float64 array)
  schema = <<EOF
[
  {
    "name": "text_content",
    "type": "STRING",
    "mode": "REQUIRED"
  },
  {
    "name": "embedding",
    "type": "FLOAT",
    "mode": "REPEATED",
    "description": "768-dimensional vector from text-embedding-005"
  },
  {
    "name": "source_file",
    "type": "STRING",
    "mode": "NULLABLE"
  }
]
EOF
}

# # Connection for BigQuery ML to invoke Vertex AI models via SQL
resource "google_bigquery_connection" "vertex_ai_conn" {
  connection_id = "vertex-ai-gen2-conn"
  location      = "US"
  friendly_name = "Connection to Vertex AI"
  cloud_resource {}
  # depends_on = [google_project_service.apis]
}

# Grant the service account permission to use Vertex AI
resource "google_project_iam_member" "bq_connection_iam" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_bigquery_connection.vertex_ai_conn.cloud_resource[0].service_account_id}"
}

#2.4. terraform/iam.tf (Security) Create dedicated service accounts (least privilege principle). Terraform
# SA for Ingestion service (reading GCS, writing to BQ, using Vertex AI)
resource "google_service_account" "ingestor_sa" {
  account_id   = "rag-ingestor-sa"
  display_name = "RAG Ingestor Service Account"
}

resource "google_project_iam_member" "ingestor_roles" {
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/bigquery.dataEditor",
    "roles/aiplatform.user"
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.ingestor_sa.email}"
}

# SA for Agent API (BQ read, Gemini call)
resource "google_service_account" "api_agent_sa" {
  account_id   = "rag-api-agent-sa"
  display_name = "RAG API Agent Service Account"
}

resource "google_project_iam_member" "agent_roles" {
  for_each = toset([
    "roles/bigquery.dataViewer", # Read-only access
    "roles/bigquery.jobUser",    # Permission to run SQL queries
    "roles/aiplatform.user",     # Call Gemini
    "roles/bigquery.connectionUser"
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.api_agent_sa.email}"
}

# SA for Eventarc trigger (right to invoke Cloud Run)
resource "google_project_iam_member" "eventarc_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  # We use standard Compute SA for simplicity of the trigger; in production, it is better to create your own.
  member = "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"
}

resource "random_string" "random" {
  length = 5
  special = false
}

resource "google_bigquery_job" "create_ml_model_job" {
  job_id = "create_ml_model_${random_string.random.result}"
  
  # Configuration for a query job
  query {
    # The BQML SQL query to run
    query = <<EOF
        CREATE OR REPLACE MODEL `enterprise_rag_v2.embedding_model_005`
        REMOTE WITH CONNECTION `us.vertex-ai-gen2-conn`
        OPTIONS (ENDPOINT = 'text-embedding-005');
    EOF
    create_disposition = ""
    write_disposition  = ""
    # destination_table {
    #   dataset_id = google_bigquery_dataset.rag_dataset.dataset_id 
    #   project_id = var.project_id
    #   table_id   = "embedding_model_005"
    # }
  }
}

import os
import io
from fastapi import FastAPI, Request
from google.cloud import storage, bigquery
import vertexai
from vertexai.language_models import TextEmbeddingModel
from langchain_text_splitters import RecursiveCharacterTextSplitter
import pypdf

app = FastAPI()

#  Cloud Run config
PROJECT_ID = os.getenv("PROJECT_ID")
LOCATION = "us-central1"
DATASET_ID = "enterprise_rag_v2"
TABLE_ID = "doc_embeddings"

# Client initialisation
storage_client = storage.Client()
bq_client = bigquery.Client()
vertexai.init(project=PROJECT_ID, location=LOCATION)
# We use the current 2026 model
embedding_model = TextEmbeddingModel.from_pretrained("text-embedding-005")

def get_embedding(text: str) -> list:
    """Генерация вектора (768 dimension для модели 005)."""
    embeddings = embedding_model.get_embeddings([text])
    return embeddings[0].values

def extract_text_from_pdf(bucket_name, file_name):
    """Скачивание и парсинг PDF из GCS."""
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)
    content = blob.download_as_bytes()
    
    pdf = pypdf.PdfReader(io.BytesIO(content))
    text = ""
    for page in pdf.pages:
        text += page.extract_text()
    return text

@app.post("/")
async def handle_event(request: Request):
    """Web-хук, вызываемый Eventarc при загрузке файла."""
    event_data = await request.json()
    
    bucket_name = event_data.get("bucket")
    file_name = event_data.get("name")
    
    if not file_name or not file_name.endswith(".pdf"):
        print(f"Skipping non-pdf file: {file_name}")
        return {"status": "skipped", "reason": "Not a PDF"}

    print(f"Processing PDF: {file_name} from {bucket_name}...")

    try:
        # 1. Text extraction
        raw_text = extract_text_from_pdf(bucket_name, file_name)

        # 2. Chunking
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=100)
        chunks = text_splitter.split_text(raw_text)
        print(f"Split into {len(chunks)} chunks...")

        
        if not chunks or not raw_text.strip():
             print(f"Warning: No extractable text found in PDF: {file_name}. Skipping BQ insertion.")
          
             return {"status": "skipped", "reason": "No text content found"}
        # ------------------------

        print("Generating embeddings...")

        # 3. Generating vectors and preparing strings for BQ
        rows_to_insert = []
        for chunk in chunks:
            vector = get_embedding(chunk)
            rows_to_insert.append({
                "text_content": chunk,
                "embedding": vector,
                "source_file": file_name
            })

        # 4. Insert into BigQuery
        table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
        errors = bq_client.insert_rows_json(table_ref, rows_to_insert)

        if errors:
            print(f"BQ Errors: {errors}")
            return {"status": "error", "errors": str(errors)}

        print(f"Successfully indexed {len(chunks)} chunks from {file_name}.")
        return {"status": "success", "chunks": len(chunks)}

    except Exception as e:
        print(f"Error processing {file_name}: {e}")
        # We return 200 OK even when there is an error so that Eventarc does not retry indefinitely.
        return {"status": "error", "detail": str(e)}

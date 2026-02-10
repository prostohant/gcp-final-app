#!/bin/bash
set -e # Зупинити скрипт при будь-якій помилці

# --- КОНФІГУРАЦІЯ ---
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
# Автоматичний пошук правильного бакета (щоб уникнути помилок в імені)
BUCKET_NAME=$(gsutil ls | grep "docs-landing-zone" | head -n 1 | sed 's/gs:\/\///;s/\///')

if [ -z "$BUCKET_NAME" ]; then
    echo -e "${RED}❌ ERROR: Could not find your bucket. Please set BUCKET_NAME manually in the script.${NC}"
    exit 1
fi

API_SERVICE_NAME="rag-agent"
TEST_PDF="secret_project_omega.pdf"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔍 Starting Verification for Project: $PROJECT_ID${NC}"
echo "Bucket found: $BUCKET_NAME"
echo "===================================================="

# 1. Створення PDF за допомогою Python (100% надійно)
echo -e "\n📄 Step 1: Creating PDF using Python 'fpdf'..."

python3 -c "
from fpdf import FPDF
pdf = FPDF()
pdf.add_page()
pdf.set_font('Arial', size=12)
pdf.cell(200, 10, txt='CONFIDENTIAL DOCUMENT', ln=1, align='C')
pdf.cell(200, 10, txt='Project Omega is a secret initiative to replace all Kubernetes clusters with highly trained hamsters in 2026.', ln=1, align='L')
pdf.output('$TEST_PDF')
"

if [ -s "$TEST_PDF" ]; then
    echo "✅ Created $TEST_PDF (Clean PDF generated)"
else
    echo -e "${RED}❌ FAILED to create PDF.${NC}"
    exit 1
fi

# 2. Завантаження
echo -e "\n⬆️ Step 2: Uploading to gs://$BUCKET_NAME..."
gsutil cp $TEST_PDF gs://$BUCKET_NAME/
echo "✅ Upload complete."

# 3. Очікування
echo -e "\n⏳ Step 3: Waiting 45 seconds for ingestion..."
for i in {1..45}; do echo -ne "$i..."; sleep 1; done
echo -e "\n✅ Wait finished."

# 4. Отримання URL
echo -e "\n🌐 Step 4: Getting API URL..."
API_URL=$(gcloud run services describe $API_SERVICE_NAME --region $REGION --project $PROJECT_ID --format 'value(status.url)')
echo "✅ Found API URL: $API_URL"

# 5. Тест LLM
echo -e "\n🤖 Step 5: Testing Generic Query..."
Q1="What is the capital of France?"
echo "   Asking: '$Q1'"
R1=$(curl -s -G --data-urlencode "q=$Q1" "$API_URL/ask")
echo "   Response: $R1"

# 6. Тест RAG
echo -e "\n🧠 Step 6: Testing RAG Query (The Moment of Truth)..."
Q2="What is the secret initiative 'Project Omega'?"
echo "   Asking: '$Q2'"
R2=$(curl -s -G --data-urlencode "q=$Q2" "$API_URL/ask")
echo "   Response: $R2"

if echo "$R2" | grep -iq "hamsters"; then
    echo -e "\n🎉🎉🎉 ${GREEN}VERIFICATION SUCCESSFUL!${NC} 🎉🎉🎉"
else
    echo -e "\n${RED}❌ VERIFICATION FAILED.${NC}"
    echo "Check logs: https://console.cloud.google.com/run/detail/$REGION/rag-ingestor/logs"
    exit 1
fi

# 7. Очистка локального файлу
rm $TEST_PDF
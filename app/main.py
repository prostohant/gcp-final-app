import os
from fastapi import FastAPI, HTTPException
from google.cloud import bigquery
import vertexai
from vertexai.generative_models import GenerativeModel, Tool, FunctionDeclaration, Part

PROJECT_ID = os.getenv("PROJECT_ID")
LOCATION = "us-central1"
# We use the Gemini 2.0 Flash model.
MODEL_NAME = "gemini-2.0-flash-001" 

vertexai.init(project=PROJECT_ID, location=LOCATION)
bq_client = bigquery.Client(project=PROJECT_ID)
app = FastAPI()

# --- Tool Definition ---
def search_knowledge_base(query: str):
    """Performs a vector search in BigQuery."""
    print(f"🔧 Tool Call: Searching BQ for '{query}'...")
    # SQL The query uses a model to vectorise the query ‘on the fly’.
    sql = f"""
    SELECT base.text_content
    FROM VECTOR_SEARCH(
      TABLE `enterprise_rag_v2.doc_embeddings`,
      'embedding',
      (SELECT ml_generate_embedding_result 
       FROM ML.GENERATE_EMBEDDING(
         MODEL `enterprise_rag_v2.embedding_model_005`,
         (SELECT '{query}' as content),
         STRUCT('RETRIEVAL_QUERY' as task_type)
       )),
      top_k => 3
    )
    """
    job = bq_client.query(sql)
    results = job.result()
    chunks = [row.text_content for row in results]
    if not chunks:
        return "No relevant information found in the knowledge base."
    return "\n\n".join(chunks)

# We wrap the function as a tool for Gemini
rag_tool = Tool(
    function_declarations=[
        FunctionDeclaration(
            name="search_knowledge_base",
            description="Use this tool to search for technical information, internal documents, or facts within the corporate knowledge base.",
            parameters={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "The search query tailored for retrieval."}
                },
                "required": ["query"]
            },
        )
    ]
)

# Initialising the model with the tool connected
model = GenerativeModel(
    MODEL_NAME,
    tools=[rag_tool],
)

@app.get("/ask")
async def ask_agent(q: str):
    try:
        chat = model.start_chat()
        print(f"👤 User Query: {q}")
        
        # 1. We send a model request. Gemini 2.0 will decide whether a tool call is needed.
        response = chat.send_message(q)
        response_part = response.candidates[0].content.parts[0]

        # 2. We check whether the model wanted to call the function
        if response_part.function_call:
            func_call = response_part.function_call
            if func_call.name == "search_knowledge_base":
                # 3. Performing a search (RAG)
                search_query = func_call.args["query"]
                context = search_knowledge_base(search_query)
                
                print(f"📄 RAG Context retrieved. Sending back to LLM.")
                # 4. Return the model search results to generate the final response
                final_response = chat.send_message(
                    Part.from_function_response(
                        name="search_knowledge_base",
                        response={"content": context}
                    )
                )
                return {"answer": final_response.text, "source": "RAG via Tool"}
        
        # If the model answered without a tool (general knowledge)
        return {"answer": response.text, "source": "LLM Knowledge"}

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

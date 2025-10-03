"""
Qwen3-Embedding-8B API Server (CPU-optimized)
"""
import os
import torch
import torch.nn.functional as F
from typing import List, Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from transformers import AutoTokenizer, AutoModel
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global model and tokenizer
model = None
tokenizer = None
device = "cpu"

# CPU optimization: use all available cores
torch.set_num_threads(int(os.environ.get("OMP_NUM_THREADS", "48")))  # Half your cores for safety


def last_token_pool(last_hidden_states: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
    """Extract embeddings from last token (recommended by Qwen3)"""
    left_padding = (attention_mask[:, -1].sum() == attention_mask.shape[0])
    if left_padding:
        return last_hidden_states[:, -1]
    else:
        sequence_lengths = attention_mask.sum(dim=1) - 1
        batch_size = last_hidden_states.shape[0]
        return last_hidden_states[torch.arange(batch_size, device=last_hidden_states.device), sequence_lengths]


def get_detailed_instruct(task_description: str, query: str) -> str:
    """Format query with instruction (improves accuracy by 1-5%)"""
    return f'Instruct: {task_description}\nQuery: {query}'


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup, cleanup on shutdown"""
    global model, tokenizer

    logger.info("Loading Qwen3-Embedding-8B model (this may take a few minutes)...")

    try:
        # Load tokenizer with left padding (required for batching)
        tokenizer = AutoTokenizer.from_pretrained(
            'Qwen/Qwen3-Embedding-8B',
            padding_side='left'
        )

        # Load model on CPU
        model = AutoModel.from_pretrained(
            'Qwen/Qwen3-Embedding-8B',
            torch_dtype=torch.float32  # Use float32 on CPU
        )
        model.eval()

        # Optional: Compile model for faster inference (PyTorch 2.0+)
        # This can give 20-30% speedup on CPU
        try:
            logger.info("Compiling model with torch.compile (this takes time but speeds up inference)...")
            model = torch.compile(model, mode="reduce-overhead")
            logger.info("Model compilation successful!")
        except Exception as e:
            logger.warning(f"Model compilation failed (not critical): {e}")

        logger.info("Model loaded successfully on CPU!")
        logger.info(f"Using {torch.get_num_threads()} CPU threads for inference")

    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise

    yield

    # Cleanup
    logger.info("Shutting down...")
    del model
    del tokenizer


app = FastAPI(
    title="Qwen3-Embedding-8B API",
    description="CPU-based embedding API using Qwen3-Embedding-8B",
    version="1.0.0",
    lifespan=lifespan
)


class EmbedRequest(BaseModel):
    texts: List[str] = Field(..., description="List of texts to embed")
    instruction: Optional[str] = Field(
        default="Given a web search query, retrieve relevant passages that answer the query",
        description="Task instruction to improve embedding quality"
    )
    normalize: bool = Field(default=True, description="Normalize embeddings to unit vectors")
    max_length: int = Field(default=8192, description="Maximum sequence length")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "texts": ["What is the capital of China?", "Explain gravity"],
                    "instruction": "Given a web search query, retrieve relevant passages that answer the query",
                    "normalize": True
                }
            ]
        }
    }


class EmbedResponse(BaseModel):
    embeddings: List[List[float]]
    model: str = "Qwen/Qwen3-Embedding-8B"
    embedding_dim: int = 4096
    num_embeddings: int


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "model": "Qwen/Qwen3-Embedding-8B",
        "device": device,
        "cpu_threads": torch.get_num_threads()
    }


@app.post("/embed", response_model=EmbedResponse)
async def embed_texts(request: EmbedRequest):
    """
    Generate embeddings for input texts

    - **texts**: List of strings to embed (queries or documents)
    - **instruction**: Optional task description (use for queries, not documents)
    - **normalize**: Whether to L2-normalize embeddings (recommended)
    - **max_length**: Maximum sequence length (default 8192)
    """
    if not model or not tokenizer:
        raise HTTPException(status_code=503, detail="Model not loaded")

    if not request.texts:
        raise HTTPException(status_code=400, detail="No texts provided")

    try:
        # Optionally add instruction to queries (improves retrieval by 1-5%)
        # Note: Don't add instruction to documents, only to queries
        input_texts = request.texts

        # Tokenize
        batch_dict = tokenizer(
            input_texts,
            padding=True,
            truncation=True,
            max_length=request.max_length,
            return_tensors="pt",
        )

        # Generate embeddings
        with torch.no_grad():
            outputs = model(**batch_dict)
            embeddings = last_token_pool(outputs.last_hidden_state, batch_dict['attention_mask'])

            # Normalize if requested (recommended for similarity search)
            if request.normalize:
                embeddings = F.normalize(embeddings, p=2, dim=1)

        # Convert to list for JSON response
        embeddings_list = embeddings.tolist()

        return EmbedResponse(
            embeddings=embeddings_list,
            embedding_dim=len(embeddings_list[0]),
            num_embeddings=len(embeddings_list)
        )

    except Exception as e:
        logger.error(f"Embedding generation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/embed/query", response_model=EmbedResponse)
async def embed_query(request: EmbedRequest):
    """
    Embed queries with instruction (optimized for retrieval)

    This endpoint automatically adds the instruction to improve retrieval quality.
    """
    if not request.texts:
        raise HTTPException(status_code=400, detail="No texts provided")

    # Add instruction to queries
    formatted_queries = [
        get_detailed_instruct(request.instruction, query)
        for query in request.texts
    ]

    # Create modified request with formatted queries
    modified_request = EmbedRequest(
        texts=formatted_queries,
        normalize=request.normalize,
        max_length=request.max_length
    )

    return await embed_texts(modified_request)


@app.get("/")
async def root():
    """API info"""
    return {
        "name": "Qwen3-Embedding-8B API",
        "model": "Qwen/Qwen3-Embedding-8B",
        "embedding_dim": 4096,
        "max_sequence_length": 32768,
        "device": device,
        "endpoints": {
            "/health": "Health check",
            "/embed": "Generate embeddings for any text",
            "/embed/query": "Generate embeddings for queries (with instruction)",
            "/docs": "OpenAPI documentation"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=9000,
        log_level="info"
    )

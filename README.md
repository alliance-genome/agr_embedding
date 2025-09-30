# AGR Embedding API

Production-ready FastAPI server for running open-source embedding models with CPU optimization.

**Current Models:**
- Qwen3-Embedding (8B/4B/0.6B)

**Planned Models:**
- BGE-M3
- E5-Large
- GTE-Large

## Features

- **CPU-optimized**: Uses torch.compile and multi-threading for best CPU performance
- **OpenAPI docs**: Auto-generated at `/docs`
- **Health checks**: `/health` endpoint
- **Query optimization**: Automatic instruction formatting for queries
- **Batching**: Process multiple texts in one request

## Setup

### 1. Install Dependencies

```bash
cd ~/qwen3-embedding-api
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Set CPU Thread Count (Optional)

For your 96-core system, set to use ~48 threads (half your cores):

```bash
export OMP_NUM_THREADS=48
export MKL_NUM_THREADS=48
```

### 3. Start Server

```bash
# Development mode
python server.py

# Production mode with uvicorn
uvicorn server:app --host 0.0.0.0 --port 9000 --workers 1
```

**Note**: First startup downloads the ~16GB model from HuggingFace. This takes time!

## Usage

### Health Check

```bash
curl http://localhost:9000/health
```

### Embed Documents (No Instruction)

```bash
curl -X POST http://localhost:9000/embed \
  -H "Content-Type: application/json" \
  -d '{
    "texts": [
      "The capital of China is Beijing.",
      "Gravity is a fundamental force of nature."
    ],
    "normalize": true
  }'
```

### Embed Queries (With Instruction)

```bash
curl -X POST http://localhost:9000/embed/query \
  -H "Content-Type: application/json" \
  -d '{
    "texts": [
      "What is the capital of China?",
      "Explain gravity"
    ],
    "instruction": "Given a web search query, retrieve relevant passages that answer the query"
  }'
```

### Python Client Example

```python
import requests

# Embed documents
response = requests.post(
    "http://localhost:9000/embed",
    json={
        "texts": ["Document text 1", "Document text 2"],
        "normalize": True
    }
)
embeddings = response.json()["embeddings"]
print(f"Got {len(embeddings)} embeddings of dimension {len(embeddings[0])}")

# Embed queries (with instruction)
response = requests.post(
    "http://localhost:9000/embed/query",
    json={
        "texts": ["What is X?", "How does Y work?"],
        "instruction": "Given a web search query, retrieve relevant passages"
    }
)
query_embeddings = response.json()["embeddings"]
```

## API Endpoints

- **GET /** - API info
- **GET /health** - Health check
- **POST /embed** - Generate embeddings
- **POST /embed/query** - Generate query embeddings (auto-adds instruction)
- **GET /docs** - Interactive API documentation

## Performance Tips

### CPU Optimization

1. **Use all cores**: Set `OMP_NUM_THREADS` to your core count
2. **Batch requests**: Send multiple texts in one request
3. **Torch compile**: Enabled by default (20-30% speedup after warmup)

### Expected Performance (96-core Xeon Gold 6240R)

- **First request**: ~10-30 seconds (model compilation)
- **Subsequent requests**: ~1-5 seconds for small batches
- **Batch size**: Try batches of 8-32 texts for best throughput

### Memory Usage

- **Model size**: ~16GB on disk, ~20GB in RAM
- **Per request**: +1-2GB depending on batch size and sequence length

## Systemd Service (Optional)

Create `/etc/systemd/system/qwen3-embedding.service`:

```ini
[Unit]
Description=Qwen3 Embedding API
After=network.target

[Service]
Type=simple
User=your-user
WorkingDirectory=/home/your-user/qwen3-embedding-api
Environment="OMP_NUM_THREADS=48"
Environment="MKL_NUM_THREADS=48"
ExecStart=/home/your-user/qwen3-embedding-api/venv/bin/uvicorn server:app --host 0.0.0.0 --port 9000
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl daemon-reload
sudo systemctl enable qwen3-embedding
sudo systemctl start qwen3-embedding
```

## Troubleshooting

### Model download fails
```bash
# Set HuggingFace cache directory
export HF_HOME=/path/to/large/storage
```

### Out of memory
- Reduce batch size
- Reduce max_length
- Close other applications

### Slow inference
- Check `torch.get_num_threads()` in /health response
- Increase OMP_NUM_THREADS
- Wait for torch.compile to optimize (first few requests are slow)

## Model Info

- **Name**: Qwen/Qwen3-Embedding-8B
- **Parameters**: 8 billion
- **Embedding Dimension**: 4096
- **Max Sequence Length**: 32,768 tokens
- **Languages**: 100+ (multilingual)
- **MTEB Score**: 70.58 (multilingual leaderboard #1)

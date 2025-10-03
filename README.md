# Alliance Genome Resources - Local LLM Services

Self-hosted AI model services for the Alliance of Genome Resources (AGR), providing cost-effective alternatives to commercial API providers while maintaining data privacy and control.

## Overview

This repository contains infrastructure and deployment configurations for running large language models (LLMs) and embedding models locally within the Alliance infrastructure. These services enable AI-powered features in AGR applications without relying on external API providers.

## Services

### 1. Granite 4.0 LLM Service

**Location**: `granite-4.0/`

IBM's open-source Granite 4.0 language models optimized for CPU-based inference. Provides OpenAI-compatible API endpoints for seamless integration with existing applications.

**Features:**
- Multiple model sizes (3B to 32B parameters)
- Mixture of Experts (MoE) architecture for efficient inference
- Up to 128K token context window
- OpenAI-compatible REST API
- Docker-based deployment

**Use Cases:**
- CrewAI agent workflows
- Data extraction and curation
- Text classification and analysis
- Question answering systems

See [granite-4.0/README.md](granite-4.0/README.md) for deployment instructions.

---

### 2. Embedding Service

**Location**: `embedding-service/`

High-performance text embedding service using Qwen3-Embedding models. Generates semantic embeddings for similarity search and retrieval-augmented generation (RAG) applications.

**Features:**
- State-of-the-art multilingual embeddings
- CPU-optimized inference
- Batch processing support
- Query-specific instruction formatting

**Use Cases:**
- Semantic search
- Document similarity
- RAG pipelines
- Vector database integration

See [embedding-service/README.md](embedding-service/README.md) for deployment instructions.

## Architecture

```
┌─────────────────────────────────────────┐
│          AGR Applications               │
│  (AI Curation, Data Processing, etc.)   │
└──────────────┬──────────────────────────┘
               │
     ┌─────────┴─────────┐
     │                   │
     ▼                   ▼
┌─────────────┐   ┌──────────────┐
│  Granite    │   │  Embedding   │
│  LLM API    │   │  Service     │
│  (Port TBD) │   │  (Port TBD)  │
└─────────────┘   └──────────────┘
```

## Benefits

### Cost Savings
- **Eliminate API Costs**: No per-token charges for LLM/embedding usage
- **Infrastructure Only**: One-time setup on existing hardware
- **Scalable**: Handle unlimited requests without usage fees

### Data Privacy
- **On-Premise**: All data processing happens within Alliance infrastructure
- **No External APIs**: Sensitive genomic data never leaves the organization
- **Full Control**: Complete control over model versions and configurations

### Performance
- **Low Latency**: Local deployment minimizes network overhead
- **High Availability**: No dependency on external service uptime
- **Customizable**: Optimize for specific workloads and requirements

## Quick Start

### Prerequisites
- Docker and Docker Compose
- CPU with AVX-512 support (recommended)
- Minimum 8GB RAM (16GB+ recommended)
- 10GB+ free disk space

### Deployment

Each service has its own deployment guide:

**Granite 4.0 LLM:**
```bash
cd granite-4.0/
./deploy.sh
```

**Embedding Service:**
```bash
cd embedding-service/
./deploy.sh
```

### Management

Both services use similar management scripts:

```bash
./manage.sh status    # Check service health
./manage.sh logs      # View logs
./manage.sh restart   # Restart service
./manage.sh test      # Run tests
```

## Integration Examples

### Granite LLM with CrewAI
```python
from crewai import Agent, LLM

llm = LLM(
    model="granite-4.0-h-tiny",
    base_url="http://your-server:port/v1",
    api_key="dummy-key"
)

agent = Agent(
    role="Data Curator",
    llm=llm,
    ...
)
```

### Embedding Service
```python
import requests

response = requests.post(
    "http://your-server:port/embed",
    json={
        "texts": ["Your text here"],
        "normalize": True
    }
)
embeddings = response.json()["embeddings"]
```

## Model Selection

### Granite 4.0 Variants

| Model | Params | Active | Speed | Quality | Memory |
|-------|--------|--------|-------|---------|--------|
| H-Micro | 3B | 3B | ⚡⚡⚡⚡⚡ | ⭐⭐⭐ | 2-3 GB |
| H-Tiny | 7B | 1B MoE | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | 4-5 GB |
| H-Small | 32B | 9B MoE | ⚡⚡ | ⭐⭐⭐⭐⭐ | 15-20 GB |

See [granite-4.0/MODEL_COMPARISON.md](granite-4.0/MODEL_COMPARISON.md) for detailed comparison.

## Documentation

- **Granite 4.0**:
  - [README.md](granite-4.0/README.md) - Model overview
  - [QUICKSTART.md](granite-4.0/QUICKSTART.md) - Deployment guide
  - [CREWAI_INTEGRATION.md](granite-4.0/CREWAI_INTEGRATION.md) - CrewAI integration
  - [MODEL_COMPARISON.md](granite-4.0/MODEL_COMPARISON.md) - Model selection guide

- **Embedding Service**:
  - [README.md](embedding-service/README.md) - Service documentation

## Contributing

Contributions are welcome! Please ensure:
- Documentation is clear and up-to-date
- Scripts follow existing patterns
- Changes are tested in a development environment first

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or feature requests, please open an issue on GitHub.

---

**Alliance of Genome Resources**
*Advancing genomics through collaboration*

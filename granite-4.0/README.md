# IBM Granite 4.0 LLM Service

## Overview

IBM Granite 4.0 is a family of open-source large language models featuring a Hybrid (H) Mamba architecture that enables faster inference with lower memory usage. Trained on 15 trillion tokens, these models are optimized for enterprise and local deployment scenarios.

## Model Variants

### H-Small (32B total, 9B active) - MoE
- **Use Case**: Enterprise workhorse for complex reasoning tasks
- **Architecture**: Mixture of Experts (MoE)
- **Active Parameters**: 9B out of 32B total
- **Best For**: Multi-turn conversations, complex reasoning, production workloads
- **Hardware**: High-end CPUs or entry-level GPUs

### H-Tiny (7B total, 1B active) - MoE **← RECOMMENDED**
- **Use Case**: Optimal balance of quality and performance
- **Architecture**: Mixture of Experts (MoE)
- **Active Parameters**: 1B out of 7B total
- **Best For**: High-throughput tasks, production deployments
- **Hardware**: Excellent for CPU-based inference (48+ threads)

### H-Micro (3B) - Dense
- **Use Case**: Maximum throughput for simple tasks
- **Architecture**: Dense model
- **Parameters**: 3B total
- **Best For**: High-volume, low-complexity workloads
- **Hardware**: Good for any modern multi-core CPU

### Micro (3B) - Dense (Alternative)
- **Use Case**: Compatibility fallback
- **Architecture**: Dense model (traditional transformer, no Mamba)
- **Parameters**: 3B total
- **Best For**: Systems without Mamba2 support

## Model Capabilities

- **Context Window**: 128K tokens (131,072 max)
- **Recommended Minimum Context**: 16,384 tokens
- **Training Data**: 15 trillion tokens
- **License**: Apache 2.0 (Open Source)
- **Special Features**: Hybrid Mamba architecture for memory efficiency

## Deployment Options

### Option 1: llama.cpp (Recommended for CPU)
Best performance on CPU systems with AVX-512 support. Provides OpenAI-compatible API.

### Option 2: Ollama
Simpler setup with less configuration control.

### Option 3: Docker (Recommended for Production)
Containerized deployment with persistent storage and automatic restart.

## Hardware Requirements

### Minimum Requirements
- **CPU**: Modern multi-core processor (8+ cores)
- **RAM**: 8GB free memory
- **Storage**: 10GB for models and cache
- **Network**: Internet connection for initial model download

### Recommended Requirements
- **CPU**: AVX-512 capable processor (48+ threads)
- **RAM**: 16GB+ free memory
- **Storage**: 20GB+ for multiple models
- **Architecture**: x86_64 with AVX-512 support

## Expected Performance

### H-Micro (3B Dense)
- **First Token**: ~100-200ms
- **Throughput**: 50-100 tokens/second (high-thread CPU)
- **Memory**: ~2-3 GB RAM
- **Concurrent Users**: 10-15

### H-Tiny (7B/1B MoE)
- **First Token**: ~150-250ms
- **Throughput**: 40-80 tokens/second (high-thread CPU)
- **Memory**: ~4-5 GB RAM
- **Concurrent Users**: 8-12

### H-Small (32B/9B MoE)
- **First Token**: ~300-500ms
- **Throughput**: 10-30 tokens/second (high-thread CPU)
- **Memory**: ~15-20 GB RAM
- **Concurrent Users**: 3-5

*Performance estimates based on AVX-512 capable CPU with 48+ threads*

## Installation

See [QUICKSTART.md](QUICKSTART.md) for step-by-step deployment instructions.

Quick deployment:
```bash
./deploy.sh
```

## API Endpoints

Once deployed, the service provides OpenAI-compatible endpoints:

- **Health Check**: `GET /health`
- **List Models**: `GET /v1/models`
- **Chat Completions**: `POST /v1/chat/completions`

## Usage Example

```python
from crewai import LLM

llm = LLM(
    model="granite-4.0-h-tiny",
    base_url="http://your-server:port/v1",
    api_key="dummy-key",
    temperature=1.0
)
```

## Quantization Options

Models are available in multiple quantization formats:

- **Q4_K_M**: Recommended - best balance of quality and speed
- **Q4_K_S**: Faster inference, slightly lower quality
- **Q8_0**: Higher quality, slower inference
- **F16**: Full precision, highest quality, slowest

Default deployment uses Q4_K_M quantization.

## Integration

### CrewAI Agents
Full integration guide: [CREWAI_INTEGRATION.md](CREWAI_INTEGRATION.md)

### Custom Applications
The service provides standard OpenAI-compatible endpoints that work with any OpenAI client library.

## Model Selection

Need help choosing? See [MODEL_COMPARISON.md](MODEL_COMPARISON.md) for detailed comparison and decision tree.

**Quick Recommendation:**
- Start with H-Tiny (7B/1B MoE)
- Downgrade to H-Micro if speed is critical
- Upgrade to H-Small if quality is insufficient

## Resources

- **Model Source**: [Unsloth Granite 4.0 Collection](https://huggingface.co/collections/unsloth/granite-40-676ae8626c1a3c89f4bd3e5e)
- **IBM Announcement**: [IBM Granite](https://www.ibm.com/granite)
- **llama.cpp**: [GitHub Repository](https://github.com/ggml-org/llama.cpp)

## License

Models are released under Apache 2.0 license by IBM.

---

*Alliance of Genome Resources - Local LLM Infrastructure*

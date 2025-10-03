# CrewAI Integration with Granite 4.0

## Overview
This document explains how to integrate the locally-hosted Granite 4.0 LLM with CrewAI agents in the AI Curation Prototype application.

## Key Discovery: CrewAI Supports Custom Endpoints

CrewAI's `LLM` class supports custom endpoints via the `base_url` parameter, which allows us to point it at **any OpenAI-compatible API endpoint**.

### Standard CrewAI LLM Configuration
```python
from crewai import Agent, LLM

llm = LLM(
    model="custom-model-name",
    base_url="https://api.your-provider.com/v1",
    api_key="your-api-key"
)

agent = Agent(
    role='Your Role',
    goal='Your Goal',
    backstory="Your backstory",
    llm=llm
)
```

## Integration Strategy

### Architecture
```
┌─────────────────────┐
│  Your Application   │
│   (CrewAI Agents)   │
└──────────┬──────────┘
           │
           │ HTTP POST (OpenAI-compatible)
           │
┌──────────▼──────────┐
│   Granite 4.0 API   │
│  (Docker Container) │
│   on your server    │
└──────────┬──────────┘
           │
           │
┌──────────▼──────────┐
│   llama.cpp Server  │
│   (--api mode)      │
│   Granite H-Tiny    │
│   GGUF Q4_K_M       │
└─────────────────────┘
```

### Step 1: llama.cpp Server with OpenAI-Compatible API

**llama.cpp includes a built-in server mode** that provides an OpenAI-compatible API endpoint:

```bash
./llama-server \
    --model granite-4.0-h-tiny-UD-Q4_K_M.gguf \
    --host 0.0.0.0 \
    --port 8080 \
    --threads ${LLAMA_THREADS:-96} \
    --ctx-size ${LLAMA_CONTEXT_SIZE:-16384} \
    --n-gpu-layers 0 \
    --api-key "optional-secret-key"
```

#### Server Endpoints (OpenAI-Compatible)
- **Chat Completions**: `POST /v1/chat/completions`
- **Completions**: `POST /v1/completions`
- **Models**: `GET /v1/models`
- **Health**: `GET /health`

The `/v1/chat/completions` endpoint accepts the same format as OpenAI's API:
```json
{
  "model": "granite-4.0-h-tiny",
  "messages": [
    {"role": "user", "content": "Your prompt"}
  ],
  "temperature": 1.0,
  "max_tokens": 2048
}
```

### Step 2: Dockerize the llama.cpp Server

The provided Dockerfile creates a Docker container that:
1. Includes llama.cpp compiled for CPU with AVX-512 support
2. Downloads the Granite 4.0 H-Tiny GGUF model
3. Exposes port 8080
4. Runs `llama-server` on container start

See `Dockerfile` in this directory for the complete implementation.

### Step 3: Integrate with Your Application

Update your application to use the Granite endpoint.

**For applications using OpenAI client:**

**Current Code**:
```python
self.client = OpenAI(
    api_key=self.api_key,
    base_url=base_url  # defaults to None (OpenAI's API)
)
```

**Updated Code** (add environment variable support):
```python
# In config.py - add new function
def get_granite_llm_config() -> Dict[str, str]:
    """Get Granite LLM configuration from environment."""
    return {
        'base_url': os.getenv('GRANITE_BASE_URL', None),
        'api_key': os.getenv('GRANITE_API_KEY', 'dummy-key'),
        'model': os.getenv('GRANITE_MODEL', 'granite-4.0-h-tiny')
    }

# In your LLM initialization - modify __init__
def __init__(
    self,
    model: str = "gpt-4o-mini",
    temperature: float = 0.7,
    max_tokens: Optional[int] = None,
    api_key: Optional[str] = None,
    base_url: Optional[str] = None,
    use_granite: bool = False,  # NEW PARAMETER
    **kwargs
):
    if use_granite:
        from ..config import get_granite_llm_config
        granite_config = get_granite_llm_config()
        base_url = granite_config['base_url']
        api_key = granite_config['api_key']
        model = granite_config['model']
        logger.info(f"Using Granite LLM at {base_url}")

    # ... rest of initialization
```

**Environment Variables** (.env):
```bash
# Granite 4.0 Configuration
GRANITE_BASE_URL=http://your-server:8081/v1
GRANITE_API_KEY=dummy-key  # llama-server doesn't require real auth by default
GRANITE_MODEL=granite-4.0-h-tiny
```

### Step 4: Switch Between OpenAI and Granite

Create a simple toggle in the crew configuration:

```python
# For production OpenAI usage
llm = YourLLMClass(
    model="gpt-4o-mini",
    temperature=0.7
)

# For testing with Granite
llm = YourLLMClass(
    model="granite-4.0-h-tiny",
    use_granite=True,
    temperature=1.0  # Granite recommended settings
)
```

Or use CrewAI's native `LLM` class:
```python
from crewai import LLM

# Granite configuration
granite_llm = LLM(
    model="granite-4.0-h-tiny",
    base_url="http://your-server:8081/v1",
    api_key="dummy-key",
    temperature=1.0
)

agent = Agent(
    role='Data Curator',
    goal='Extract information',
    backstory="Expert curator",
    llm=granite_llm
)
```

## Performance Considerations

### Expected Performance (Granite H-Tiny on High-Thread CPU)
- **Model Size**: ~4-5 GB RAM (Q4_K_M quantization)
- **First Token Latency**: ~150-250ms
- **Throughput**: 40-80 tokens/second (estimated)
- **Concurrent Sessions**: 8-12 supported

### Optimization Tips
1. **Context Window**: Start with 16K, can go up to 128K if needed
2. **Threads**: Configure LLAMA_THREADS based on available CPU threads
3. **Batch Size**: Adjust based on concurrent requests
4. **Temperature**: Use 1.0 as recommended by IBM

## Testing Plan

### 1. Basic Connectivity Test
```bash
curl -X POST http://your-server:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-4.0-h-tiny",
    "messages": [{"role": "user", "content": "What is genomics?"}],
    "temperature": 1.0
  }'
```

### 2. CrewAI Integration Test
See `test_crewai_integration.py` for a complete test script:
```python
from crewai import Agent, Task, Crew, LLM

granite_llm = LLM(
    model="granite-4.0-h-tiny",
    base_url="http://your-server:8081/v1",
    api_key="dummy-key"
)

agent = Agent(
    role="Test Agent",
    goal="Respond to simple questions",
    backstory="A test agent",
    llm=granite_llm
)

task = Task(
    description="Explain what a gene is.",
    expected_output="A brief description",
    agent=agent
)

crew = Crew(agents=[agent], tasks=[task])
result = crew.kickoff()
print(result)
```

### 3. Full Application Test
Run your actual workflow with test data to verify:
- Output quality
- Response time
- Memory usage
- Concurrent request handling

## Fallback Strategy

Implement automatic fallback to OpenAI if Granite is unavailable:

```python
def get_llm_with_fallback():
    """Get LLM with automatic fallback to OpenAI."""
    granite_config = get_granite_llm_config()

    if granite_config['base_url']:
        try:
            # Test Granite availability
            response = requests.get(
                f"{granite_config['base_url']}/models",
                timeout=5
            )
            if response.status_code == 200:
                logger.info("Using Granite LLM")
                return LLM(
                    model=granite_config['model'],
                    base_url=granite_config['base_url'],
                    api_key=granite_config['api_key']
                )
        except Exception as e:
            logger.warning(f"Granite unavailable: {e}, falling back to OpenAI")

    # Fallback to OpenAI
    return OpenAIResponsesLLM(model="gpt-4o-mini")
```

## Cost Comparison

### OpenAI Costs (gpt-4o-mini)
- **Input**: $0.15 per 1M tokens
- **Output**: $0.60 per 1M tokens
- **Est. Monthly Cost**: $X (based on current usage)

### Granite 4.0 Costs
- **Infrastructure**: ~$0 (existing server infrastructure)
- **API Calls**: $0 (self-hosted)
- **Estimated Savings**: 100% of LLM API costs

## Next Steps

1. ✅ Deploy Granite 4.0 service using `./deploy.sh`
2. ⬜ Run basic connectivity tests
3. ⬜ Update application codebase with Granite support
4. ⬜ Run integration tests
5. ⬜ Benchmark performance vs OpenAI
6. ⬜ Deploy to production with fallback mechanism

---

*Created: October 3, 2025*
*References*:
- CrewAI LLM Connections: https://docs.crewai.com/concepts/llms
- llama.cpp Server: https://github.com/ggml-org/llama.cpp/blob/master/examples/server/README.md
- Granite 4.0 Models: https://huggingface.co/collections/unsloth/granite-40-676ae8626c1a3c89f4bd3e5e

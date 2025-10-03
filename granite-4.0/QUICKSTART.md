# Granite 4.0 Quick Start Guide

## Prerequisites

- Docker installed on your server
- At least 8GB free RAM
- Internet connection for initial model download (~4.5GB)
- 10GB free disk space

## Deployment (One Command!)

### Navigate to Installation Directory
```bash
cd /path/to/granite-4.0
```

### Deploy the Service
```bash
# Single command - builds, downloads model, and starts service
./deploy.sh
```

**What happens during deployment:**
1. Stops any existing container
2. Builds Docker image with llama.cpp (AVX-512 optimized)
3. Downloads Granite 4.0 H-Tiny model (~4.5GB)
4. Creates persistent `./models/` and `./logs/` directories
5. Starts service with `--restart unless-stopped`
6. Waits for health check
7. Displays service endpoints

**Time**: ~10-15 minutes for first deployment

## Verify Deployment

The deploy script automatically tests the health endpoint. You should see:

```
✓ Container is running
✓ Service is healthy and responding

=== Deployment Successful! ===
Service is running on:
  - Local:    http://localhost:8081
  - External: http://your-server:8081

OpenAI-Compatible Endpoints:
  - Health:           http://your-server:8081/health
  - Models:           http://your-server:8081/v1/models
  - Chat Completions: http://your-server:8081/v1/chat/completions
```

## Management Commands

All management is done via `./manage.sh`:

```bash
# Check status
./manage.sh status

# View logs (live)
./manage.sh logs

# View last 100 lines
./manage.sh logs-tail

# Run tests
./manage.sh test

# Test with custom prompt
./manage.sh test-custom "What is a gene?"

# Restart service
./manage.sh restart

# Stop service
./manage.sh stop

# Start service
./manage.sh start

# Rebuild and redeploy
./manage.sh rebuild

# Open shell in container
./manage.sh shell

# Full cleanup (removes container, keeps models)
./manage.sh cleanup
```

## Persistent Storage

Models and logs are stored locally and survive container restarts:

```
granite-4.0/
├── models/              # Downloaded models (~4.5GB)
│   └── granite-4.0-h-tiny.gguf
└── logs/                # Service logs (optional)
```

**Important**: Even if you remove the container, the model files remain in `./models/` so you don't need to re-download.

## Test from AI Curation

### Update AI Curation .env
```bash
# Add to your application .env file
GRANITE_BASE_URL=http://your-server:8081/v1
GRANITE_API_KEY=dummy-key
GRANITE_MODEL=granite-4.0-h-tiny
```

### Test with CrewAI
```python
from crewai import Agent, Task, Crew, LLM

# Configure Granite LLM
granite_llm = LLM(
    model="granite-4.0-h-tiny",
    base_url="http://your-server:8081/v1",
    api_key="dummy-key",
    temperature=1.0
)

# Create test agent
agent = Agent(
    role="Genomics Expert",
    goal="Answer questions about genomics",
    backstory="An expert in genomic data and bioinformatics",
    llm=granite_llm
)

# Create and run task
task = Task(
    description="What is the Alliance of Genome Resources?",
    expected_output="A brief, accurate description",
    agent=agent
)

crew = Crew(agents=[agent], tasks=[task])
result = crew.kickoff()
print(result)
```

## API Examples

### Health Check (curl)
```bash
curl http://your-server:8081/health
```

### List Models (curl)
```bash
curl http://your-server:8081/v1/models
```

### Chat Completion (curl)
```bash
curl -X POST http://your-server:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-4.0-h-tiny",
    "messages": [
      {"role": "user", "content": "Explain what a gene is in simple terms."}
    ],
    "temperature": 1.0,
    "max_tokens": 200
  }'
```

### Chat Completion (Python)
```python
import requests

response = requests.post(
    "http://your-server:8081/v1/chat/completions",
    json={
        "model": "granite-4.0-h-tiny",
        "messages": [
            {"role": "user", "content": "What is genomics?"}
        ],
        "temperature": 1.0,
        "max_tokens": 200
    }
)

print(response.json()["choices"][0]["message"]["content"])
```

## Performance Tuning

### Increase Context Window
Model supports up to 128K tokens. Edit container environment if needed:

```bash
# Stop service
./manage.sh stop

# Edit deploy.sh to change LLAMA_CONTEXT_SIZE
# Line: -e LLAMA_CONTEXT_SIZE=32768

# Redeploy
./deploy.sh
```

### Monitor Performance
```bash
# Real-time resource monitoring
./manage.sh status

# Follow logs to see token generation speed
./manage.sh logs | grep "tokens/s"
```

## Troubleshooting

### Service won't start
```bash
# Check logs
./manage.sh logs-tail

# Common issues:
# 1. Port already in use → Change PORT in deploy.sh
# 2. Out of memory → Free up RAM or reduce context size
# 3. Model download failed → Check internet connection
```

### Slow responses
```bash
# Check actual thread usage
docker exec granite-4.0-api top

# Verify AVX-512 is enabled (should see in logs during build)
```

### Connection refused from applications
```bash
# Test from the same server first
curl http://localhost:8081/health

# Test external access
curl http://your-server:8081/health

# Check if firewall is blocking the port
```

## Automatic Startup on Boot

The container is configured with `--restart unless-stopped`, so it will automatically start when Docker starts.

To ensure Docker starts on boot:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

## Switching Models

See [MODEL_COMPARISON.md](MODEL_COMPARISON.md) for instructions on switching between:
- H-Micro (3B) - faster
- H-Tiny (7B/1B MoE) - current default
- H-Small (32B/9B MoE) - best quality

## Next Steps

1. ✅ Service deployed and running
2. ⬜ Test with CrewAI integration script
3. ⬜ Update AI Curation to use Granite
4. ⬜ Benchmark performance vs OpenAI
5. ⬜ Monitor resource usage over time

---

*Updated for H-Tiny deployment pattern*
*Modeled after docling-service deployment structure*

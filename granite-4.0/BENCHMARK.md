# Granite 4.0 Benchmark Guide

## Overview

The `benchmark.py` script tests API performance and monitors system resource utilization to ensure Granite is using CPU threads and memory properly.

## Installation

The script requires `psutil` for resource monitoring:

```bash
pip install psutil requests
```

## Usage

### Basic Benchmark (Local)

```bash
python benchmark.py
```

### Remote Server Benchmark

```bash
python benchmark.py --host 10.0.70.22 --port 8081
```

### Custom Export Location

```bash
python benchmark.py --export /path/to/results.json
```

## What It Tests

The benchmark runs 5 tests with increasing complexity:

1. **Short Warmup** - Simple question, 10 tokens (warms up the model)
2. **Short/Medium** - Basic question, 50 tokens (typical chat)
3. **Medium/Long** - Complex explanation, 200 tokens (detailed response)
4. **Long/Long** - Comprehensive prompt, 300 tokens (stress test)
5. **Code Generation** - Programming task, 150 tokens (code output)

## Metrics Reported

### Performance Metrics
- **Tokens/sec** - Generation speed
- **First token latency** - Time to first response token
- **Total time** - End-to-end request time
- **Prompt/completion tokens** - Token counts

### Resource Metrics
- **CPU Usage** - Average and peak CPU utilization
- **Memory Usage** - Average and peak memory (GB)
- **Thread Count** - Number of threads llama-server is using

## Expected Results (Q8_0 Model, 48 Threads)

```
Average Speed: 20-30 tokens/sec (Q8_0 should be faster than BF16)
Average CPU Usage: 40-60% (48 threads on 96-core system)
Peak Memory Usage: 18-22GB (Q8_0 model + context)
Thread Count: 48+
```

## Resource Utilization Analysis

The benchmark automatically analyzes resource usage:

- **✓ Good utilization**: CPU >60%
- **✓ Moderate**: CPU 30-60%
- **⚠️ Low utilization**: CPU <30% (may indicate threading issues)

## Output Files

### Console Output
Real-time progress and formatted results table

### JSON Export (`benchmark_results.json`)
```json
{
  "timestamp": "2025-10-03T19:30:00",
  "system_info": {
    "cpu_count": 96,
    "total_memory_gb": 512
  },
  "results": [
    {
      "test_name": "short_prompt_warmup",
      "tokens_per_second": 25.3,
      "avg_cpu_percent": 45.2,
      ...
    }
  ]
}
```

## Troubleshooting

### Low Speed (<10 tok/s)
- Check CPU usage - should be 40-60%
- Verify thread count matches configuration (48)
- Check memory isn't maxed out

### Low CPU Usage (<30%)
- Threads may not be configured properly
- Check `LLAMA_THREADS` environment variable
- Verify `--cpus` Docker limit

### High Memory (>30GB)
- Context size may be too large
- Check for memory leaks
- Verify model file size matches Q8_0 (~7-8GB)

## Integration with CI/CD

You can run this benchmark automatically after deployment:

```bash
# In your deploy script
./deploy.sh
sleep 10  # Wait for model to load
python benchmark.py --export results/benchmark_$(date +%s).json
```

## Comparing Results

To compare Q8_0 vs BF16 performance:

```bash
# Before switching models
python benchmark.py --export bf16_results.json

# After switching to Q8_0
python benchmark.py --export q8_0_results.json

# Compare
diff <(jq '.results[].tokens_per_second' bf16_results.json) \
     <(jq '.results[].tokens_per_second' q8_0_results.json)
```

## API Integration

The benchmark is now available via HTTP API on port 8082.

### Trigger a Benchmark via API

```bash
# Trigger benchmark (runs in background)
curl -X POST http://10.0.70.22:8082/benchmark

# Check if benchmark is still running
curl http://10.0.70.22:8082/status

# Get results when complete
curl http://10.0.70.22:8082/results
```

### Python API Client Example

```python
import requests
import time

# Trigger benchmark
response = requests.post("http://10.0.70.22:8082/benchmark")
print(response.json())  # {'status': 'started', ...}

# Wait for completion
while True:
    status = requests.get("http://10.0.70.22:8082/status").json()
    if not status["running"]:
        break
    time.sleep(5)

# Get results
results = requests.get("http://10.0.70.22:8082/results").json()

# Extract summary
summary = results["summary"]
print(f"Average speed: {summary['avg_speed_tokens_per_sec']:.2f} tok/s")
print(f"Average CPU: {summary['avg_cpu_percent']:.1f}%")
print(f"Peak Memory: {summary['peak_memory_gb']:.2f}GB")
```

### API Endpoints

**POST /benchmark**
- Triggers a new benchmark run
- Returns immediately, benchmark runs in background
- Optional JSON body: `{"host": "localhost", "port": 8080}`

**GET /status**
- Check if benchmark is currently running
- Returns: `{"running": true/false, "has_results": true/false}`

**GET /results**
- Get the latest benchmark results
- Returns full JSON with all test results and summary

**GET /health**
- Health check for the benchmark API service

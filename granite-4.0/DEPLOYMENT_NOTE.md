# Deployment Configuration

## Model Selection: H-Tiny (7B/1B MoE)

**Decision Date**: October 3, 2025

### Why H-Tiny Instead of H-Micro?

The default configuration uses **H-Tiny (7B/1B MoE)** instead of H-Micro (3B) for:

1. **Better Quality**: 7B model intelligence at 1B inference speed
2. **MoE Efficiency**: Only 1B params active per token = fast inference
3. **Reasonable Resource Usage**: 4-5 GB RAM is manageable on modern servers
4. **Good Performance**: 40-80 tokens/second on high-thread CPUs

**Note**: This assumes adequate CPU resources (48+ threads recommended) and available RAM.

### What Changed

- **Dockerfile**: Downloads `unsloth/granite-4.0-h-tiny-GGUF` instead of h-micro
- **Model File**: `granite-4.0-h-tiny.gguf` (~4.5 GB)
- **Expected Memory**: ~4-5 GB RAM usage
- **Test Script**: Defaults to `granite-4.0-h-tiny`

### Expected Performance (H-Tiny on High-Thread CPU)

```
First token latency:  ~150-250ms
Throughput:           40-80 tokens/second
Context window:       128K tokens
Concurrent users:     8-12
Memory usage:         ~4-5 GB
```

### Downgrade to H-Micro (If Needed)

If H-Tiny is too slow or uses too much RAM, switch to H-Micro:

1. Edit `Dockerfile` line 47:
   ```dockerfile
   repo_id='unsloth/granite-4.0-h-micro-GGUF',
   ```

2. Edit `Dockerfile` line 53:
   ```dockerfile
   RUN find /app/models -name "*UD-Q4_K_M*.gguf" -exec ln -s {} /app/models/granite-4.0-h-micro.gguf \;
   ```

3. Edit `Dockerfile` line 71:
   ```dockerfile
   --model /app/models/granite-4.0-h-micro.gguf \
   ```

4. Rebuild:
   ```bash
   ./deploy.sh build
   ```

### Upgrade to H-Small (If Quality Needed)

If H-Tiny isn't good enough, upgrade to H-Small (32B/9B MoE):

1. Edit `Dockerfile` line 47:
   ```dockerfile
   repo_id='unsloth/granite-4.0-h-small-GGUF',
   ```

2. Edit `Dockerfile` line 53:
   ```dockerfile
   RUN find /app/models -name "*UD-Q4_K_M*.gguf" -exec ln -s {} /app/models/granite-4.0-h-small.gguf \;
   ```

3. Edit `Dockerfile` line 71:
   ```dockerfile
   --model /app/models/granite-4.0-h-small.gguf \
   ```

4. Rebuild:
   ```bash
   ./deploy.sh build
   ```

**Note**: H-Small uses ~15-20 GB RAM and is slower (10-30 tok/s)

### Testing Plan

1. Deploy H-Tiny
2. Run basic API tests (`./deploy.sh test`)
3. Run CrewAI integration test (`python test_crewai_integration.py`)
4. Test with real AI Curation workflows
5. Measure quality and speed
6. Downgrade to H-Micro if too slow
7. Upgrade to H-Small if quality insufficient

---

*Configuration: H-Tiny (7B/1B MoE) with Q4_K_M quantization*

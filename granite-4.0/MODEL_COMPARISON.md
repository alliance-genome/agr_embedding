# Granite 4.0 Model Comparison & Selection Guide

## Quick Recommendation

**Start here**: H-Micro (3B) → **Upgrade if needed**: H-Tiny (7B/1B MoE) → **Last resort**: H-Small (32B/9B MoE)

---

## Model Specifications

| Model | Architecture | Total Params | Active Params | Speed | Quality | Memory (Q4) |
|-------|-------------|--------------|---------------|-------|---------|-------------|
| **H-Micro** | Dense | 3B | 3B | ⚡⚡⚡⚡⚡ | ⭐⭐⭐ | 2-3 GB |
| **Micro** | Dense (no Mamba) | 3B | 3B | ⚡⚡⚡⚡ | ⭐⭐⭐ | 2-3 GB |
| **H-Tiny** | MoE | 7B | 1B | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | 4-5 GB |
| **H-Small** | MoE | 32B | 9B | ⚡⚡ | ⭐⭐⭐⭐⭐ | 15-20 GB |

---

## Architecture Explained

### Dense Models (H-Micro, Micro)

**How it works:**
```
Input → All 3B parameters process token → Output
```

**Characteristics:**
- ✅ Simple, predictable
- ✅ Consistent performance
- ✅ Lower memory overhead
- ❌ Every token uses full model

**Best for:** Production workloads where consistency matters

---

### MoE Models (H-Tiny, H-Small)

**How it works:**
```
Input → Router selects expert → Only that expert processes token → Output

Example (H-Tiny):
- Total experts: ~7 billion parameters
- Active per token: ~1 billion parameters
- Router picks best expert for each token
```

**Characteristics:**
- ✅ Get large model quality at small model speed
- ✅ Parameter efficient
- ✅ Specialized experts for different tasks
- ⚠️ More complex architecture
- ⚠️ Slightly higher memory overhead

**Best for:** When you need better quality without sacrificing too much speed

---

## Performance Estimates (High-Thread CPU with AVX-512)

### H-Micro (3B Dense) - Recommended Starting Point

**Expected Performance:**
- **First token**: ~100-200ms
- **Throughput**: 50-100 tokens/second
- **Context window**: 128K tokens
- **Concurrent users**: 10-15 easily

**Resource Usage:**
- **Memory**: ~2-3 GB
- **CPU**: Can use all 96 threads
- **Disk**: ~2.5 GB model file

**Use Cases:**
- ✅ Simple data extraction
- ✅ Template-based generation
- ✅ Classification tasks
- ✅ Basic Q&A
- ⚠️ Complex reasoning
- ⚠️ Multi-step logic

---

### H-Tiny (7B/1B MoE) - Quality Upgrade

**Expected Performance:**
- **First token**: ~150-250ms
- **Throughput**: 40-80 tokens/second
- **Context window**: 128K tokens
- **Concurrent users**: 8-12

**Resource Usage:**
- **Memory**: ~4-5 GB
- **CPU**: Can use all 96 threads
- **Disk**: ~4.5 GB model file

**Use Cases:**
- ✅ Complex data extraction
- ✅ Nuanced text generation
- ✅ Better classification
- ✅ Improved Q&A
- ✅ Multi-step reasoning
- ⚠️ Very complex logic

**When to upgrade from H-Micro:**
- Outputs lack detail or nuance
- Domain-specific knowledge is weak
- Multi-step reasoning fails
- Classification accuracy is poor

---

### H-Small (32B/9B MoE) - Enterprise Grade

**Expected Performance:**
- **First token**: ~300-500ms
- **Throughput**: 10-30 tokens/second
- **Context window**: 128K tokens
- **Concurrent users**: 3-5

**Resource Usage:**
- **Memory**: ~15-20 GB
- **CPU**: Uses ALL 96 threads heavily
- **Disk**: ~18 GB model file

**Use Cases:**
- ✅ Complex reasoning
- ✅ Advanced data extraction
- ✅ High-quality generation
- ✅ Multi-step analysis
- ✅ Domain expertise
- ❌ High-throughput scenarios

**When to use:**
- H-Tiny still isn't good enough
- Quality matters more than speed
- You have 20+ GB RAM to spare
- Concurrent load is low (<5 users)

---

## Model Selection Decision Tree

```
Start here
    ↓
┌─────────────────────┐
│   Try H-Micro (3B)  │
│   Fast & Efficient  │
└──────────┬──────────┘
           │
    Test quality
           │
    ┌──────┴──────┐
    │             │
Quality OK?   Quality poor?
    │             │
    ↓             ↓
┌─────────┐   ┌──────────────┐
│  DONE!  │   │ Try H-Tiny   │
│ Use it  │   │ (7B/1B MoE)  │
└─────────┘   └──────┬───────┘
                     │
              Test quality
                     │
              ┌──────┴──────┐
              │             │
        Quality OK?   Still poor?
              │             │
              ↓             ↓
          ┌─────────┐   ┌──────────────┐
          │  DONE!  │   │ Try H-Small  │
          │ Use it  │   │ (32B/9B MoE) │
          └─────────┘   └──────────────┘
```

---

## How to Switch Models

### Method 1: Environment Variable (Easiest)

Edit `.env`:
```bash
# Choose one:
GRANITE_MODEL=h-micro    # 3B, fastest
GRANITE_MODEL=h-tiny     # 7B/1B MoE, balanced
GRANITE_MODEL=h-small    # 32B/9B MoE, best quality
```

Then rebuild:
```bash
./deploy.sh stop
./deploy.sh build
./deploy.sh start
```

### Method 2: Docker Compose Override

Edit `docker-compose.yml`:
```yaml
environment:
  - GRANITE_MODEL=h-tiny  # Change this
```

### Method 3: Multiple Containers (Run Them All!)

Run multiple models simultaneously on different ports:

```yaml
services:
  granite-micro:
    # ... H-Micro on port 8080

  granite-tiny:
    # ... H-Tiny on port 8081

  granite-small:
    # ... H-Small on port 8082
```

Then switch in your app config:
```python
# Fast responses
llm = LLM(base_url="http://your-server:8080/v1")  # H-Micro

# Better quality
llm = LLM(base_url="http://your-server:8081/v1")  # H-Tiny

# Best quality
llm = LLM(base_url="http://your-server:8082/v1")  # H-Small
```

---

## Testing Methodology

### 1. Establish Baseline (H-Micro)
```python
# Run standard test prompts
test_prompts = [
    "Extract the gene name from: 'The FBgn0001 gene...'",
    "Classify this abstract as relevant or not...",
    "Summarize these key findings..."
]

# Measure:
# - Accuracy
# - Response time
# - Quality (human eval)
```

### 2. Compare with H-Tiny
```python
# Same prompts on H-Tiny
# Measure improvement in:
# - Accuracy (should improve)
# - Quality (should improve)
# - Speed (may be similar or slightly slower)
```

### 3. Decide
- **If H-Micro is good enough**: STOP, use it
- **If H-Tiny is noticeably better**: Upgrade
- **If neither is good enough**: Consider H-Small OR re-evaluate if local LLM is right approach

---

## Real-World Benchmarks (When You Test)

Create `benchmark_results.md` and track:

```markdown
## H-Micro (3B)
- Avg response time: X seconds
- Tokens/second: Y
- Accuracy on test set: Z%
- Quality rating (1-5): N

## H-Tiny (7B/1B MoE)
- Avg response time: X seconds
- Tokens/second: Y
- Accuracy on test set: Z%
- Quality rating (1-5): N

## H-Small (32B/9B MoE)
- Avg response time: X seconds
- Tokens/second: Y
- Accuracy on test set: Z%
- Quality rating (1-5): N
```

---

## Model Download URLs

All from Unsloth's optimized GGUFs:

```bash
# H-Micro (recommended start)
unsloth/granite-4.0-h-micro-GGUF

# H-Tiny (quality upgrade)
unsloth/granite-4.0-h-tiny-GGUF

# H-Small (enterprise grade)
unsloth/granite-4.0-h-small-GGUF

# Quantization options for each:
# - UD-Q4_K_M (recommended - good balance)
# - UD-Q4_K_S (faster, slightly lower quality)
# - UD-Q8_0 (higher quality, slower)
# - F16 (full precision, slowest)
```

---

## My Strong Recommendation

**Phase 1 (This Week):**
1. Deploy H-Micro (3B)
2. Test with real AI Curation workflows
3. Measure quality and speed

**Phase 2 (If Needed):**
1. If quality is lacking, deploy H-Tiny alongside
2. A/B test them on same tasks
3. Pick winner

**Phase 3 (Unlikely):**
1. Only if H-Tiny fails, try H-Small
2. Accept slower throughput
3. OR consider using OpenAI for complex tasks, Granite for simple ones

**Why this approach?**
- Start small, iterate fast
- Don't over-engineer
- H-Micro might be perfectly fine
- Easy to upgrade if needed

---

*Updated: October 3, 2025*

#!/bin/bash
# Start Qwen3-Embedding API with optimized CPU settings

# Set CPU thread count (use half of available cores for stability)
export OMP_NUM_THREADS=48
export MKL_NUM_THREADS=48

# Optional: Set HuggingFace cache directory if you have limited space in home
# export HF_HOME=/path/to/large/storage/.cache/huggingface

# Activate virtual environment
source venv/bin/activate

# Start server
echo "Starting Qwen3-Embedding-8B API on http://0.0.0.0:9000"
echo "CPU threads: $OMP_NUM_THREADS"
echo "First startup will download ~16GB model - please be patient!"
echo ""
echo "OpenAPI docs: http://localhost:9000/docs"
echo "Health check: http://localhost:9000/health"
echo ""

python server.py

#!/bin/bash

# Deployment script for Granite 4.0 LLM service on flysql26
# Run this on flysql26 server

set -e

CONTAINER_NAME="granite-4.0-api"
IMAGE_NAME="granite-4.0-llm"
PORT=8081
BENCHMARK_PORT=8082

echo "=== Granite 4.0 LLM Service Deployment Script ==="

# Step 1: Stop and remove existing container if it exists
echo "Checking for existing container..."
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Stopping existing container..."
    docker stop $CONTAINER_NAME || true
    docker rm $CONTAINER_NAME || true
fi

# Step 2: Build the Docker image
echo "Building Docker image (this may take 10-15 minutes on first build)..."
echo "  - Compiling llama.cpp with AVX-512 support"
echo "  - Downloading Granite 4.0 H-Tiny model (~4.5 GB)"
docker build -t $IMAGE_NAME:latest .

# Step 3: Create persistent directories for models and logs
echo "Creating persistent directories..."
mkdir -p $(pwd)/models
mkdir -p $(pwd)/logs

# Step 4: Run the container
echo "Starting Granite 4.0 service..."
docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -p $PORT:8080 \
    -p $BENCHMARK_PORT:8082 \
    -e LLAMA_THREADS=48 \
    -e LLAMA_CONTEXT_SIZE=16384 \
    -e LLAMA_PORT=8080 \
    -e LLAMA_HOST=0.0.0.0 \
    -e BENCHMARK_API_PORT=8082 \
    -e PYTHONUNBUFFERED=1 \
    --cpus="48.0" \
    --memory="32g" \
    -v $(pwd)/models:/app/models \
    -v $(pwd)/logs:/app/logs \
    $IMAGE_NAME:latest

# Step 5: Check if container is running
sleep 2
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✓ Container started successfully"
    echo ""
    echo "=== Deployment Complete! ==="
    echo "Service is running on:"
    echo "  - Local:    http://localhost:$PORT"
    echo "  - External: http://flysql26.alliancegenome.org:$PORT"
    echo ""
    echo "OpenAI-Compatible Endpoints:"
    echo "  - Health:           http://flysql26.alliancegenome.org:$PORT/health"
    echo "  - Models:           http://flysql26.alliancegenome.org:$PORT/v1/models"
    echo "  - Chat Completions: http://flysql26.alliancegenome.org:$PORT/v1/chat/completions"
    echo ""
    echo "Benchmark API:"
    echo "  - Trigger Benchmark: POST http://flysql26.alliancegenome.org:$BENCHMARK_PORT/benchmark"
    echo "  - Get Results:       GET  http://flysql26.alliancegenome.org:$BENCHMARK_PORT/results"
    echo "  - Status:            GET  http://flysql26.alliancegenome.org:$BENCHMARK_PORT/status"
    echo ""
    echo "Model: Granite 4.0 H-Tiny Q8_0 (7B/1B MoE, 8-bit quantization)"
    echo "Context: 16,384 tokens (expandable to 128K)"
    echo "Resources: 48 CPU threads, 32GB RAM"
    echo "Quality: 99.9% of full precision, 3-4x faster"
    echo ""
    echo "Note: Model is loading. Check status with:"
    echo "  ./manage.sh status"
    echo "  ./manage.sh logs"
else
    echo "✗ Failed to start container"
    echo "Check logs: ./manage.sh logs"
    exit 1
fi

#!/bin/bash

# Deployment script for Granite 4.0 LLM service on flysql26
# Run this on flysql26 server

set -e

CONTAINER_NAME="granite-4.0-api"
IMAGE_NAME="granite-4.0-llm"
PORT=8081

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
    -e LLAMA_THREADS=96 \
    -e LLAMA_CONTEXT_SIZE=16384 \
    -e LLAMA_PORT=8080 \
    -e LLAMA_HOST=0.0.0.0 \
    -e PYTHONUNBUFFERED=1 \
    --cpus="96.0" \
    --memory="16g" \
    -v $(pwd)/models:/app/models \
    -v $(pwd)/logs:/app/logs \
    $IMAGE_NAME:latest

# Step 5: Check if container is running
sleep 5
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✓ Container is running"

    # Test health endpoint
    echo "Testing health endpoint..."
    echo "  (Waiting 15 seconds for model to load...)"
    sleep 15

    if curl -f http://localhost:$PORT/health > /dev/null 2>&1; then
        echo "✓ Service is healthy and responding"
        echo ""
        echo "=== Deployment Successful! ==="
        echo "Service is running on:"
        echo "  - Local:    http://localhost:$PORT"
        echo "  - External: http://flysql26.alliancegenome.org:$PORT"
        echo ""
        echo "OpenAI-Compatible Endpoints:"
        echo "  - Health:           http://flysql26.alliancegenome.org:$PORT/health"
        echo "  - Models:           http://flysql26.alliancegenome.org:$PORT/v1/models"
        echo "  - Chat Completions: http://flysql26.alliancegenome.org:$PORT/v1/chat/completions"
        echo ""
        echo "Model: Granite 4.0 H-Tiny (7B/1B MoE)"
        echo "Context: 16,384 tokens (expandable to 128K)"
        echo "Threads: 96 CPU threads"
        echo ""
        echo "Management:"
        echo "  View logs:    ./manage.sh logs"
        echo "  Check status: ./manage.sh status"
        echo "  Quick test:   ./manage.sh test"
    else
        echo "⚠ Warning: Container is running but health check failed"
        echo "The model may still be loading. Check logs:"
        echo "  ./manage.sh logs"
    fi
else
    echo "✗ Failed to start container"
    echo "Check logs: ./manage.sh logs"
    exit 1
fi

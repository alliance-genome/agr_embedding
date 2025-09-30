#!/bin/bash

# Deployment script for AGR Embedding service
# Run this on your target server (flysql26 or similar)

set -e

CONTAINER_NAME="agr-embedding-service"
IMAGE_NAME="agr-embedding-api"
PORT=9000

echo "=== AGR Embedding Service Deployment Script ==="

# Step 1: Stop and remove existing container if it exists
echo "Checking for existing container..."
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Stopping existing container..."
    docker stop $CONTAINER_NAME || true
    docker rm $CONTAINER_NAME || true
fi

# Step 2: Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME:latest .

# Step 3: Create persistent directories for models and logs
echo "Creating persistent directories..."
mkdir -p $(pwd)/models
mkdir -p $(pwd)/logs

# Step 4: Run the container
echo "Starting AGR Embedding service..."
docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -p $PORT:9000 \
    -e OMP_NUM_THREADS=48 \
    -e MKL_NUM_THREADS=48 \
    -e NUMEXPR_NUM_THREADS=48 \
    -e PYTHONUNBUFFERED=1 \
    -e HF_HOME=/app/models \
    -e TRANSFORMERS_CACHE=/app/models \
    -e TORCH_HOME=/app/models \
    --cpus="48.0" \
    --memory="64g" \
    -v $(pwd)/models:/app/models \
    -v $(pwd)/logs:/app/logs \
    $IMAGE_NAME:latest

# Step 5: Check if container is running
sleep 5
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✓ Container is running"

    # Test health endpoint
    echo "Testing health endpoint..."
    echo "NOTE: First startup will download ~16GB model - this may take 10-20 minutes!"
    echo "Waiting 30 seconds before health check..."
    sleep 30

    if curl -f http://localhost:$PORT/health > /dev/null 2>&1; then
        echo "✓ Service is healthy and responding"
        echo ""
        echo "=== Deployment Successful! ==="
        echo "Service is running on:"
        echo "  - Local: http://localhost:$PORT"
        echo "  - VPN:   http://10.0.70.22:$PORT"
        echo ""
        echo "Endpoints:"
        echo "  - Health:     http://10.0.70.22:$PORT/health"
        echo "  - API Docs:   http://10.0.70.22:$PORT/docs"
        echo "  - Embed:      POST http://10.0.70.22:$PORT/embed"
        echo "  - Embed Query: POST http://10.0.70.22:$PORT/embed/query"
        echo ""
        echo "View logs: docker logs -f $CONTAINER_NAME"
    else
        echo "⚠ Warning: Container is running but health check failed"
        echo "This is normal on first startup - model is downloading"
        echo "Check logs: docker logs -f $CONTAINER_NAME"
        echo ""
        echo "The service will be ready once model download completes"
    fi
else
    echo "✗ Failed to start container"
    echo "Check logs: docker logs $CONTAINER_NAME"
    exit 1
fi

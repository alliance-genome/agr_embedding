#!/bin/bash

# Management script for AGR Embedding service

CONTAINER_NAME="agr-embedding-service"
IMAGE_NAME="agr-embedding-api"
PORT=9000

case "$1" in
    start)
        echo "Starting AGR Embedding service..."
        docker start $CONTAINER_NAME
        ;;

    stop)
        echo "Stopping AGR Embedding service..."
        docker stop $CONTAINER_NAME
        ;;

    restart)
        echo "Restarting AGR Embedding service..."
        docker restart $CONTAINER_NAME
        ;;

    status)
        echo "=== Container Status ==="
        docker ps -a | grep $CONTAINER_NAME || echo "Container not found"
        echo ""
        echo "=== Health Check ==="
        curl -s http://localhost:$PORT/health | python3 -m json.tool || echo "Service not responding"
        ;;

    logs)
        docker logs -f $CONTAINER_NAME
        ;;

    logs-tail)
        docker logs --tail 100 $CONTAINER_NAME
        ;;

    shell)
        echo "Opening shell in container..."
        docker exec -it $CONTAINER_NAME /bin/bash
        ;;

    rebuild)
        echo "Rebuilding and redeploying..."
        ./deploy.sh
        ;;

    test)
        echo "Testing embedding service..."

        echo ""
        echo "1. Testing /health endpoint..."
        curl -s http://localhost:$PORT/health | python3 -m json.tool

        echo ""
        echo "2. Testing /embed endpoint (documents)..."
        curl -s -X POST http://localhost:$PORT/embed \
            -H "Content-Type: application/json" \
            -d '{
                "texts": ["The capital of China is Beijing.", "Gravity is a fundamental force."],
                "normalize": true
            }' | python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"✓ Embedded {data['num_embeddings']} texts, dimension: {data['embedding_dim']}\")"

        echo ""
        echo "3. Testing /embed/query endpoint (queries with instruction)..."
        curl -s -X POST http://localhost:$PORT/embed/query \
            -H "Content-Type: application/json" \
            -d '{
                "texts": ["What is the capital of China?"],
                "instruction": "Given a web search query, retrieve relevant passages"
            }' | python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"✓ Embedded query, dimension: {data['embedding_dim']}\")"

        echo ""
        echo "All tests completed!"
        ;;

    benchmark)
        echo "Running performance benchmark..."
        echo "This will test embedding speed with different batch sizes"
        echo ""

        for batch_size in 1 4 8 16; do
            echo "Testing batch size: $batch_size"

            # Generate test texts
            texts=$(python3 -c "import json; print(json.dumps([f'Test document {i}' for i in range($batch_size)]))")

            # Time the request
            start=$(date +%s.%N)
            curl -s -X POST http://localhost:$PORT/embed \
                -H "Content-Type: application/json" \
                -d "{\"texts\": $texts, \"normalize\": true}" > /dev/null
            end=$(date +%s.%N)

            elapsed=$(echo "$end - $start" | bc)
            per_text=$(echo "$elapsed / $batch_size" | bc -l)

            printf "  Batch %2d: %.2fs total, %.3fs per text\n" $batch_size $elapsed $per_text
        done
        ;;

    cleanup)
        echo "Cleaning up Docker resources..."
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true
        docker rmi $IMAGE_NAME:latest 2>/dev/null || true
        echo "Cleanup complete"
        echo ""
        echo "Note: Model cache in ./models/ directory was NOT deleted"
        echo "To delete model cache: rm -rf ./models/"
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|status|logs|logs-tail|shell|rebuild|test|benchmark|cleanup}"
        echo ""
        echo "Commands:"
        echo "  start      - Start the service"
        echo "  stop       - Stop the service"
        echo "  restart    - Restart the service"
        echo "  status     - Check service status and health"
        echo "  logs       - Follow container logs"
        echo "  logs-tail  - Show last 100 log lines"
        echo "  shell      - Open shell in container"
        echo "  rebuild    - Rebuild and redeploy"
        echo "  test       - Run API tests"
        echo "  benchmark  - Run performance benchmark"
        echo "  cleanup    - Remove container and image (keeps model cache)"
        exit 1
        ;;
esac

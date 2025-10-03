#!/bin/bash

# Management script for Granite 4.0 LLM service

CONTAINER_NAME="granite-4.0-api"
IMAGE_NAME="granite-4.0-llm"
PORT=8081

case "$1" in
    start)
        echo "Starting Granite 4.0 service..."
        docker start $CONTAINER_NAME
        ;;

    stop)
        echo "Stopping Granite 4.0 service..."
        docker stop $CONTAINER_NAME
        ;;

    restart)
        echo "Restarting Granite 4.0 service..."
        docker restart $CONTAINER_NAME
        ;;

    status)
        echo "=== Container Status ==="
        docker ps -a | grep $CONTAINER_NAME || echo "Container not found"
        echo ""
        echo "=== Resource Usage ==="
        docker stats --no-stream $CONTAINER_NAME 2>/dev/null || echo "Container not running"
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
        echo "=== Testing Granite 4.0 API ==="
        echo ""

        # Test 1: Health check
        echo "Test 1: Health Check"
        if curl -f http://localhost:$PORT/health > /dev/null 2>&1; then
            echo "✓ Health check passed"
        else
            echo "✗ Health check failed"
            exit 1
        fi

        echo ""

        # Test 2: List models
        echo "Test 2: List Models"
        curl -s http://localhost:$PORT/v1/models | python3 -m json.tool

        echo ""

        # Test 3: Simple chat completion
        echo "Test 3: Chat Completion Test"
        echo "Prompt: 'What is genomics in one sentence?'"
        echo ""
        curl -s http://localhost:$PORT/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d '{
                "model": "granite-4.0-h-tiny",
                "messages": [
                    {"role": "user", "content": "What is genomics in one sentence?"}
                ],
                "temperature": 1.0,
                "max_tokens": 100
            }' | python3 -m json.tool

        echo ""
        echo "✓ All tests completed"
        ;;

    test-custom)
        if [ -z "$2" ]; then
            echo "Usage: $0 test-custom \"Your prompt here\""
            exit 1
        fi

        echo "Testing with custom prompt: $2"
        echo ""
        curl -s http://localhost:$PORT/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"granite-4.0-h-tiny\",
                \"messages\": [
                    {\"role\": \"user\", \"content\": \"$2\"}
                ],
                \"temperature\": 1.0,
                \"max_tokens\": 500
            }" | python3 -m json.tool
        ;;

    cleanup)
        echo "Cleaning up Docker resources..."
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true
        docker rmi $IMAGE_NAME:latest 2>/dev/null || true
        echo "Cleanup complete"
        echo ""
        echo "Note: Model files in ./models/ are preserved"
        echo "To remove them: rm -rf ./models/"
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|status|logs|logs-tail|shell|rebuild|test|test-custom|cleanup}"
        echo ""
        echo "Commands:"
        echo "  start           - Start the service"
        echo "  stop            - Stop the service"
        echo "  restart         - Restart the service"
        echo "  status          - Check service status, resource usage, and health"
        echo "  logs            - Follow container logs (live)"
        echo "  logs-tail       - Show last 100 log lines"
        echo "  shell           - Open shell in container"
        echo "  rebuild         - Rebuild and redeploy from scratch"
        echo "  test            - Run complete API test suite"
        echo "  test-custom \"prompt\" - Test with custom prompt"
        echo "  cleanup         - Remove container and image (keeps models)"
        exit 1
        ;;
esac

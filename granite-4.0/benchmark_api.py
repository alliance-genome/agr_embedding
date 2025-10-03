#!/usr/bin/env python3
"""
Benchmark API Server

Provides HTTP endpoints to trigger benchmarks and retrieve results.
Runs on port 8082 alongside llama-server on port 8080.

Endpoints:
  POST /benchmark - Trigger a new benchmark run
  GET /results - Get the latest benchmark results
  GET /health - Health check
"""

import os
import sys
import json
import threading
from flask import Flask, jsonify, request
from datetime import datetime

# Import the benchmark module
sys.path.insert(0, os.path.dirname(__file__))
from benchmark import GraniteBenchmark

app = Flask(__name__)

# Global state
benchmark_running = False
latest_results = None
benchmark_lock = threading.Lock()


def run_benchmark_async(host: str, port: int):
    """Run benchmark in background thread"""
    global benchmark_running, latest_results

    try:
        benchmark = GraniteBenchmark(host=host, port=port)

        # Run all tests
        benchmark.run_all_tests()

        # Store results
        results_data = {
            "timestamp": datetime.now().isoformat(),
            "results": [
                {
                    "test_name": r.test_name,
                    "prompt_tokens": r.prompt_tokens,
                    "completion_tokens": r.completion_tokens,
                    "total_time_sec": r.total_time_sec,
                    "tokens_per_second": r.tokens_per_second,
                    "first_token_latency_ms": r.first_token_latency_ms,
                    "avg_cpu_percent": r.avg_cpu_percent,
                    "peak_cpu_percent": r.peak_cpu_percent,
                    "avg_memory_gb": r.avg_memory_gb,
                    "peak_memory_gb": r.peak_memory_gb,
                    "thread_count": r.thread_count,
                    "success": r.success,
                    "error": r.error
                }
                for r in benchmark.results
            ]
        }

        # Calculate summary
        successful = [r for r in benchmark.results if r.success]
        if successful:
            results_data["summary"] = {
                "total_tests": len(benchmark.results),
                "successful": len(successful),
                "failed": len(benchmark.results) - len(successful),
                "avg_speed_tokens_per_sec": sum(r.tokens_per_second for r in successful) / len(successful),
                "avg_cpu_percent": sum(r.avg_cpu_percent for r in successful) / len(successful),
                "peak_memory_gb": max(r.peak_memory_gb for r in successful)
            }

        with benchmark_lock:
            latest_results = results_data

    except Exception as e:
        with benchmark_lock:
            latest_results = {
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
    finally:
        with benchmark_lock:
            benchmark_running = False


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "benchmark-api",
        "timestamp": datetime.now().isoformat()
    })


@app.route('/benchmark', methods=['POST'])
def trigger_benchmark():
    """Trigger a new benchmark run"""
    global benchmark_running

    with benchmark_lock:
        if benchmark_running:
            return jsonify({
                "error": "Benchmark already running",
                "status": "busy"
            }), 409

        benchmark_running = True

    # Get parameters from request
    data = request.get_json() if request.is_json else {}
    host = data.get('host', 'localhost')
    port = data.get('port', 8080)

    # Start benchmark in background
    thread = threading.Thread(target=run_benchmark_async, args=(host, port))
    thread.daemon = True
    thread.start()

    return jsonify({
        "status": "started",
        "message": "Benchmark started in background",
        "timestamp": datetime.now().isoformat()
    })


@app.route('/status', methods=['GET'])
def status():
    """Check if benchmark is running"""
    with benchmark_lock:
        return jsonify({
            "running": benchmark_running,
            "has_results": latest_results is not None,
            "timestamp": datetime.now().isoformat()
        })


@app.route('/results', methods=['GET'])
def get_results():
    """Get the latest benchmark results"""
    with benchmark_lock:
        if latest_results is None:
            return jsonify({
                "error": "No results available. Run /benchmark first.",
                "status": "no_data"
            }), 404

        return jsonify(latest_results)


if __name__ == '__main__':
    # Run on port 8082 (llama-server uses 8080)
    port = int(os.environ.get('BENCHMARK_API_PORT', 8082))
    app.run(host='0.0.0.0', port=port, debug=False)

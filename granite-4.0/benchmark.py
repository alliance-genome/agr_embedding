#!/usr/bin/env python3
"""
Granite 4.0 LLM Benchmark Script

Tests API performance and monitors system resource utilization.
Can be run locally on the server to validate proper resource usage.

Usage:
    python benchmark.py [--host HOST] [--port PORT]
"""

import argparse
import json
import time
import requests
import psutil
import threading
from dataclasses import dataclass, asdict
from typing import List, Dict, Any
from datetime import datetime


@dataclass
class BenchmarkResult:
    """Results from a single benchmark test"""
    test_name: str
    prompt_tokens: int
    completion_tokens: int
    total_time_sec: float
    tokens_per_second: float
    first_token_latency_ms: float
    avg_cpu_percent: float
    peak_cpu_percent: float
    avg_memory_gb: float
    peak_memory_gb: float
    thread_count: int
    success: bool
    error: str = None


class ResourceMonitor:
    """Monitor CPU and memory usage during benchmark"""

    def __init__(self):
        self.monitoring = False
        self.cpu_samples = []
        self.memory_samples = []
        self.thread = None

    def start(self):
        """Start monitoring resources"""
        self.monitoring = True
        self.cpu_samples = []
        self.memory_samples = []
        self.thread = threading.Thread(target=self._monitor_loop)
        self.thread.daemon = True
        self.thread.start()

    def stop(self):
        """Stop monitoring and return results"""
        self.monitoring = False
        if self.thread:
            self.thread.join(timeout=1.0)

        return {
            'avg_cpu': sum(self.cpu_samples) / len(self.cpu_samples) if self.cpu_samples else 0,
            'peak_cpu': max(self.cpu_samples) if self.cpu_samples else 0,
            'avg_memory_gb': sum(self.memory_samples) / len(self.memory_samples) if self.memory_samples else 0,
            'peak_memory_gb': max(self.memory_samples) if self.memory_samples else 0,
        }

    def _monitor_loop(self):
        """Internal monitoring loop"""
        while self.monitoring:
            # Sample CPU usage (percentage across all cores)
            cpu_percent = psutil.cpu_percent(interval=0.1)
            self.cpu_samples.append(cpu_percent)

            # Sample memory usage (in GB)
            memory = psutil.virtual_memory()
            memory_gb = memory.used / (1024 ** 3)
            self.memory_samples.append(memory_gb)

            time.sleep(0.1)


class GraniteBenchmark:
    """Benchmark suite for Granite 4.0 LLM API"""

    def __init__(self, host: str = "localhost", port: int = 8081):
        self.base_url = f"http://{host}:{port}"
        self.results: List[BenchmarkResult] = []

    def test_health(self) -> bool:
        """Check if the API is healthy"""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            return response.status_code == 200
        except Exception as e:
            print(f"Health check failed: {e}")
            return False

    def run_inference_test(
        self,
        test_name: str,
        prompt: str,
        max_tokens: int = 100,
        temperature: float = 0.7
    ) -> BenchmarkResult:
        """Run a single inference test with resource monitoring"""

        monitor = ResourceMonitor()
        monitor.start()

        start_time = time.time()
        first_token_time = None

        try:
            # Make the API request
            response = requests.post(
                f"{self.base_url}/v1/chat/completions",
                headers={"Content-Type": "application/json"},
                json={
                    "model": "granite-4.0-h-tiny",
                    "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                },
                timeout=120
            )

            total_time = time.time() - start_time

            if response.status_code != 200:
                raise Exception(f"API returned status {response.status_code}")

            data = response.json()

            # Extract metrics
            usage = data.get("usage", {})
            timings = data.get("timings", {})

            prompt_tokens = usage.get("prompt_tokens", 0)
            completion_tokens = usage.get("completion_tokens", 0)

            # Get detailed timings if available
            if timings:
                tokens_per_sec = timings.get("predicted_per_second", 0)
                first_token_latency = timings.get("prompt_ms", 0)
            else:
                tokens_per_sec = completion_tokens / total_time if total_time > 0 else 0
                first_token_latency = 0

            # Stop monitoring and get resource stats
            resource_stats = monitor.stop()

            # Get thread count from the process (find llama-server process)
            thread_count = self._get_llama_thread_count()

            result = BenchmarkResult(
                test_name=test_name,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_time_sec=total_time,
                tokens_per_second=tokens_per_sec,
                first_token_latency_ms=first_token_latency,
                avg_cpu_percent=resource_stats['avg_cpu'],
                peak_cpu_percent=resource_stats['peak_cpu'],
                avg_memory_gb=resource_stats['avg_memory_gb'],
                peak_memory_gb=resource_stats['peak_memory_gb'],
                thread_count=thread_count,
                success=True
            )

        except Exception as e:
            monitor.stop()
            result = BenchmarkResult(
                test_name=test_name,
                prompt_tokens=0,
                completion_tokens=0,
                total_time_sec=0,
                tokens_per_second=0,
                first_token_latency_ms=0,
                avg_cpu_percent=0,
                peak_cpu_percent=0,
                avg_memory_gb=0,
                peak_memory_gb=0,
                thread_count=0,
                success=False,
                error=str(e)
            )

        self.results.append(result)
        return result

    def _get_llama_thread_count(self) -> int:
        """Get the number of threads used by llama-server process"""
        try:
            for proc in psutil.process_iter(['name', 'num_threads']):
                if 'llama-server' in proc.info['name']:
                    return proc.info['num_threads']
        except:
            pass
        return 0

    def run_all_tests(self):
        """Run comprehensive benchmark suite"""

        print("=" * 60)
        print("Granite 4.0 LLM Benchmark Suite")
        print("=" * 60)
        print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

        # Test 1: Short prompt, short completion (warmup)
        print("Test 1: Short prompt (warmup)...")
        self.run_inference_test(
            "short_prompt_warmup",
            "What is 2+2?",
            max_tokens=10
        )

        # Test 2: Short prompt, medium completion
        print("Test 2: Short prompt, medium completion...")
        self.run_inference_test(
            "short_prompt_medium_completion",
            "What model are you?",
            max_tokens=50
        )

        # Test 3: Medium prompt, long completion
        print("Test 3: Medium prompt, long completion...")
        self.run_inference_test(
            "medium_prompt_long_completion",
            "Explain how photosynthesis works in plants. Include details about light-dependent and light-independent reactions.",
            max_tokens=200
        )

        # Test 4: Long prompt, long completion (stress test)
        print("Test 4: Long prompt, long completion (stress test)...")
        long_prompt = """
        You are an expert biologist. Please provide a comprehensive explanation of cellular respiration,
        including glycolysis, the Krebs cycle, and the electron transport chain. Explain how ATP is
        generated in each stage, what molecules are involved, and how the process differs between
        aerobic and anaerobic conditions. Also discuss the role of mitochondria in this process.
        """
        self.run_inference_test(
            "long_prompt_stress_test",
            long_prompt.strip(),
            max_tokens=300
        )

        # Test 5: Code generation test
        print("Test 5: Code generation...")
        self.run_inference_test(
            "code_generation",
            "Write a Python function to calculate the Fibonacci sequence up to n terms.",
            max_tokens=150
        )

        print("\n" + "=" * 60)
        print("Benchmark Complete!")
        print("=" * 60)

    def print_results(self):
        """Print formatted results"""
        if not self.results:
            print("No results to display")
            return

        print("\n" + "=" * 60)
        print("BENCHMARK RESULTS")
        print("=" * 60)

        for result in self.results:
            print(f"\nTest: {result.test_name}")
            if result.success:
                print(f"  Status: ✓ SUCCESS")
                print(f"  Tokens: {result.prompt_tokens} prompt + {result.completion_tokens} completion")
                print(f"  Speed: {result.tokens_per_second:.2f} tokens/sec")
                print(f"  Latency: {result.first_token_latency_ms:.1f}ms first token")
                print(f"  Total Time: {result.total_time_sec:.2f}s")
                print(f"  CPU Usage: {result.avg_cpu_percent:.1f}% avg, {result.peak_cpu_percent:.1f}% peak")
                print(f"  Memory: {result.avg_memory_gb:.2f}GB avg, {result.peak_memory_gb:.2f}GB peak")
                print(f"  Threads: {result.thread_count}")
            else:
                print(f"  Status: ✗ FAILED")
                print(f"  Error: {result.error}")

        # Summary statistics
        successful_tests = [r for r in self.results if r.success]
        if successful_tests:
            avg_speed = sum(r.tokens_per_second for r in successful_tests) / len(successful_tests)
            avg_cpu = sum(r.avg_cpu_percent for r in successful_tests) / len(successful_tests)
            max_memory = max(r.peak_memory_gb for r in successful_tests)

            print("\n" + "=" * 60)
            print("SUMMARY")
            print("=" * 60)
            print(f"Total Tests: {len(self.results)}")
            print(f"Successful: {len(successful_tests)}")
            print(f"Failed: {len(self.results) - len(successful_tests)}")
            print(f"\nAverage Speed: {avg_speed:.2f} tokens/sec")
            print(f"Average CPU Usage: {avg_cpu:.1f}%")
            print(f"Peak Memory Usage: {max_memory:.2f}GB")

            # Resource utilization analysis
            print("\n" + "=" * 60)
            print("RESOURCE UTILIZATION ANALYSIS")
            print("=" * 60)

            cpu_count = psutil.cpu_count()
            print(f"Total CPU Cores: {cpu_count}")
            print(f"CPU Usage: {avg_cpu:.1f}% of total capacity")
            print(f"Expected with 48 threads: ~50% (48/{cpu_count} cores)")

            if successful_tests[0].thread_count > 0:
                print(f"Actual Threads Used: {successful_tests[0].thread_count}")

            if avg_cpu < 30:
                print("⚠️  WARNING: Low CPU utilization - may not be using all allocated threads")
            elif avg_cpu > 60:
                print("✓ Good CPU utilization")
            else:
                print("✓ Moderate CPU utilization")

    def export_json(self, filename: str = "benchmark_results.json"):
        """Export results to JSON file"""
        data = {
            "timestamp": datetime.now().isoformat(),
            "system_info": {
                "cpu_count": psutil.cpu_count(),
                "total_memory_gb": psutil.virtual_memory().total / (1024 ** 3),
            },
            "results": [asdict(r) for r in self.results]
        }

        with open(filename, 'w') as f:
            json.dump(data, f, indent=2)

        print(f"\nResults exported to: {filename}")


def main():
    parser = argparse.ArgumentParser(description="Benchmark Granite 4.0 LLM API")
    parser.add_argument("--host", default="localhost", help="API host")
    parser.add_argument("--port", type=int, default=8081, help="API port")
    parser.add_argument("--export", default="benchmark_results.json", help="Export results to JSON file")

    args = parser.parse_args()

    benchmark = GraniteBenchmark(host=args.host, port=args.port)

    # Health check
    print(f"Checking API health at {args.host}:{args.port}...")
    if not benchmark.test_health():
        print("ERROR: API is not responding. Please check the service.")
        return 1

    print("✓ API is healthy\n")

    # Run benchmarks
    benchmark.run_all_tests()

    # Display results
    benchmark.print_results()

    # Export to JSON
    if args.export:
        benchmark.export_json(args.export)

    return 0


if __name__ == "__main__":
    exit(main())

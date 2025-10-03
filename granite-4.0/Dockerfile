# Granite 4.0 LLM API Server
# Provides OpenAI-compatible API endpoint for Granite 4.0 H-Tiny (7B/1B MoE)
# Optimized for Intel Xeon Gold 6240R (96 threads, AVX-512)

FROM ubuntu:22.04

# Allow pinning to specific llama.cpp commit (default: master)
ARG LLAMA_CPP_COMMIT=master
ENV LLAMA_CPP_COMMIT=${LLAMA_CPP_COMMIT}

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies, Python, and OpenBLAS
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    libcurl4-openssl-dev \
    git \
    python3 \
    python3-pip \
    numactl \
    libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone and build llama.cpp with full CPU optimizations
# - AVX-512 + VNNI for Intel Xeon 6240R
# - OpenBLAS for accelerated prompt processing
# - K-quants enabled for KV cache quantization support
RUN rm -rf llama.cpp && \
    git clone https://github.com/ggml-org/llama.cpp && \
    cd llama.cpp && \
    if [ "${LLAMA_CPP_COMMIT}" != "master" ]; then git checkout "${LLAMA_CPP_COMMIT}"; fi && \
    echo "Building llama.cpp commit: $(git rev-parse HEAD)" && \
    cmake -B build \
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_CUDA=OFF \
        -DLLAMA_CURL=ON \
        -DGGML_AVX512=ON \
        -DGGML_AVX512_VNNI=ON \
        -DLLAMA_BLAS=ON \
        -DLLAMA_BLAS_VENDOR=OpenBLAS \
        -DGGML_K_QUANTS=ON \
        -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --config Release -j$(nproc) --target llama-server && \
    install -m 0755 build/bin/llama-server /usr/local/bin/llama-server && \
    echo "=== llama-server build verification ===" && \
    /usr/local/bin/llama-server -h | head -n 30

# Install Python packages for model download, benchmarking, and bc for calculations
RUN apt-get update && apt-get install -y bc && \
    pip3 install --no-cache-dir "huggingface_hub[cli,hf_transfer]" psutil requests flask && \
    rm -rf /var/lib/apt/lists/*

# Create directory for models
RUN mkdir -p /app/models

# Note: Model download happens at runtime via entrypoint.sh
# This allows volume mounts to work properly and shows download progress

# Copy scripts
COPY entrypoint.sh /app/entrypoint.sh
COPY benchmark.py /app/benchmark.py
COPY benchmark_api.py /app/benchmark_api.py
RUN chmod +x /app/entrypoint.sh /app/benchmark.py /app/benchmark_api.py

# Expose ports for API and benchmark
EXPOSE 8080
EXPOSE 8082

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set environment variables for runtime configuration
ENV LLAMA_THREADS=24
ENV LLAMA_CONTEXT_SIZE=8192
ENV LLAMA_PORT=8080
ENV LLAMA_HOST=0.0.0.0

# Thread control - CRITICAL for preventing thread explosion
# OpenBLAS uses pthreads backend (not OpenMP), so OMP_NUM_THREADS doesn't control it!
ENV OPENBLAS_NUM_THREADS=1
ENV GOTO_NUM_THREADS=1
ENV OMP_NUM_THREADS=1
ENV OMP_DYNAMIC=FALSE
ENV OMP_NESTED=FALSE
ENV OMP_MAX_ACTIVE_LEVELS=1

# Use entrypoint script to handle model validation and download
ENTRYPOINT ["/app/entrypoint.sh"]

# Granite 4.0 LLM API Server
# Provides OpenAI-compatible API endpoint for Granite 4.0 H-Tiny (7B/1B MoE)
# Optimized for Intel Xeon Gold 6240R (96 threads, AVX-512)

FROM ubuntu:22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies and Python
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    libcurl4-openssl-dev \
    git \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone and build llama.cpp with CPU optimizations (AVX-512)
# Note: GGML_CUDA=OFF since this is CPU-only
RUN git clone https://github.com/ggml-org/llama.cpp && \
    cd llama.cpp && \
    cmake -B build \
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_CUDA=OFF \
        -DLLAMA_CURL=ON \
        -DGGML_AVX512=ON && \
    cmake --build build --config Release -j$(nproc) --target llama-server && \
    cp build/bin/llama-server /usr/local/bin/

# Install Python packages for model download and bc for calculations
RUN apt-get update && apt-get install -y bc && \
    pip3 install --no-cache-dir "huggingface_hub[cli,hf_transfer]" && \
    rm -rf /var/lib/apt/lists/*

# Create directory for models
RUN mkdir -p /app/models

# Note: Model download happens at runtime via entrypoint.sh
# This allows volume mounts to work properly and shows download progress

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose port for API
EXPOSE 8080

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set environment variables for runtime configuration
ENV LLAMA_THREADS=96
ENV LLAMA_CONTEXT_SIZE=16384
ENV LLAMA_PORT=8080
ENV LLAMA_HOST=0.0.0.0

# Use entrypoint script to handle model validation and download
ENTRYPOINT ["/app/entrypoint.sh"]

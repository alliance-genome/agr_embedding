#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Granite 4.0 H-Tiny LLM Server Starting...${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Configuration
MODEL_REPO="unsloth/granite-4.0-h-tiny-GGUF"
MODEL_PATTERN="*Q8_0*"
MODEL_DIR="/app/models"
MODEL_FILE="${MODEL_DIR}/granite-4.0-h-tiny-Q8_0.gguf"

echo -e "\n${BLUE}[INFO]${NC} Configuration:"
echo -e "  Model Repository: ${MODEL_REPO}"
echo -e "  Model Directory:  ${MODEL_DIR}"
echo -e "  Model File:       ${MODEL_FILE}"
echo -e "  Threads:          ${LLAMA_THREADS}"
echo -e "  Context Size:     ${LLAMA_CONTEXT_SIZE}"
echo -e "  Port:             ${LLAMA_PORT}"
echo -e "  Host:             ${LLAMA_HOST}"

# Check if model directory exists
if [ ! -d "${MODEL_DIR}" ]; then
    echo -e "\n${RED}[ERROR]${NC} Model directory ${MODEL_DIR} does not exist!"
    echo -e "${YELLOW}[ACTION]${NC} Creating directory..."
    mkdir -p "${MODEL_DIR}"
fi

# Clean up incomplete downloads and lock files from previous failed attempts
echo -e "\n${BLUE}[INFO]${NC} Cleaning up incomplete downloads and lock files..."
find "${MODEL_DIR}" -name "*.incomplete" -delete 2>/dev/null || true
find "${MODEL_DIR}" -name "*.lock" -delete 2>/dev/null || true
find "${MODEL_DIR}" -name "*.metadata" -delete 2>/dev/null || true
find "${MODEL_DIR}" -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true

# Remove old model files that don't match current configuration (saves space)
echo -e "${BLUE}[INFO]${NC} Removing old model files to save space..."
MODEL_BASENAME=$(basename "${MODEL_FILE}")
find "${MODEL_DIR}" -maxdepth 1 -name "*.gguf" ! -name "${MODEL_BASENAME}" -exec rm -f {} \; 2>/dev/null || true

# Check if model file exists
if [ -f "${MODEL_FILE}" ]; then
    echo -e "\n${GREEN}[SUCCESS]${NC} Model file found: ${MODEL_FILE}"
    MODEL_SIZE=$(du -h "${MODEL_FILE}" | cut -f1)
    echo -e "  Size: ${MODEL_SIZE}"
else
    echo -e "\n${YELLOW}[WARNING]${NC} Model file not found: ${MODEL_FILE}"

    # Check if any GGUF files exist in the directory
    GGUF_COUNT=$(find "${MODEL_DIR}" -name "*.gguf" -type f | wc -l)

    if [ "${GGUF_COUNT}" -gt 0 ]; then
        echo -e "${BLUE}[INFO]${NC} Found ${GGUF_COUNT} existing GGUF file(s) in ${MODEL_DIR}"
        find "${MODEL_DIR}" -name "*.gguf" -type f -exec ls -lh {} \;

        # Try to find the Q8_0 model
        Q8_MODEL=$(find "${MODEL_DIR}" -name "*Q8_0*.gguf" -type f | head -n 1)

        if [ -n "${Q8_MODEL}" ]; then
            echo -e "${YELLOW}[ACTION]${NC} Creating symlink from existing Q8_0 model..."
            ln -sf "${Q8_MODEL}" "${MODEL_FILE}"
            echo -e "${GREEN}[SUCCESS]${NC} Symlink created: ${MODEL_FILE} -> ${Q8_MODEL}"
        else
            echo -e "${RED}[ERROR]${NC} No Q8_0 model found in directory"
            echo -e "${YELLOW}[ACTION]${NC} Will attempt to download..."
        fi
    fi

    # If still no model file, download it
    if [ ! -f "${MODEL_FILE}" ]; then
        echo -e "\n${BLUE}[INFO]${NC} Downloading model from HuggingFace..."
        echo -e "${YELLOW}[WARNING]${NC} This will download ~7-8GB and may take several minutes"

        export HF_HUB_ENABLE_HF_TRANSFER=1

        # Download Q8_0 (8-bit quantization) - NEAR-PERFECT QUALITY, 3-4x FASTER THAN BF16
        # Q8_0 provides the best balance of quality and speed:
        #   - File size: ~7-8GB (vs 13GB for BF16)
        #   - Quality: 99.9% of BF16 (0.1% perplexity difference, imperceptible)
        #   - Speed: 3-4x faster inference than BF16 (20-30 tok/s vs 6-10 tok/s)
        #   - Memory bandwidth: Half of BF16, much better CPU cache utilization
        #   - Perfect for production: Near-identical quality at practical speeds
        echo -e "${BLUE}[INFO]${NC} Downloading Q8_0 (8-bit) variant from ${MODEL_REPO}..."

        hf download "${MODEL_REPO}" \
            --include "*Q8_0*.gguf" \
            --local-dir "${MODEL_DIR}"

        if [ $? -ne 0 ]; then
            echo -e "${RED}[ERROR]${NC} Failed to download model!"
            exit 1
        fi

        echo -e "${GREEN}[SUCCESS]${NC} Download completed!"

        # Debug: Show what was actually downloaded
        echo -e "\n${BLUE}[DEBUG]${NC} Contents of ${MODEL_DIR} after download:"
        ls -lah "${MODEL_DIR}"
        echo -e "\n${BLUE}[DEBUG]${NC} All GGUF files found:"
        find "${MODEL_DIR}" -type f -name "*.gguf" 2>/dev/null | while read f; do
            size=$(du -h "$f" | cut -f1)
            echo "  $f ($size)"
        done

        # Find the Q8_0 model
        echo -e "\n${BLUE}[INFO]${NC} Looking for Q8_0 model..."
        DOWNLOADED_MODEL=$(find "${MODEL_DIR}" -type f -name "*Q8_0*.gguf" 2>/dev/null | head -n 1)

        if [ -z "${DOWNLOADED_MODEL}" ]; then
            echo -e "${YELLOW}[WARNING]${NC} Q8_0 model not found, trying case variations..."
            DOWNLOADED_MODEL=$(find "${MODEL_DIR}" -type f -name "*q8*0*.gguf" -o -name "*Q8*0*.gguf" 2>/dev/null | head -n 1)
        fi

        if [ -n "${DOWNLOADED_MODEL}" ]; then
            # Only create symlink if the downloaded file has a different name
            if [ "${DOWNLOADED_MODEL}" != "${MODEL_FILE}" ]; then
                echo -e "${YELLOW}[ACTION]${NC} Creating symlink to downloaded model..."
                ln -s "${DOWNLOADED_MODEL}" "${MODEL_FILE}"
                echo -e "${GREEN}[SUCCESS]${NC} Model ready: ${MODEL_FILE}"
            else
                echo -e "${GREEN}[SUCCESS]${NC} Model ready: ${MODEL_FILE}"
            fi
        else
            echo -e "${RED}[ERROR]${NC} Downloaded model not found!"
            exit 1
        fi
    fi
fi

# Final validation
if [ ! -f "${MODEL_FILE}" ]; then
    echo -e "\n${RED}[FATAL ERROR]${NC} Model file still not available: ${MODEL_FILE}"
    echo -e "${YELLOW}[DEBUG]${NC} Contents of ${MODEL_DIR}:"
    ls -lah "${MODEL_DIR}"
    exit 1
fi

# Verify model file is not empty and has reasonable size
MODEL_SIZE_BYTES=$(stat -c%s "${MODEL_FILE}" 2>/dev/null || echo "0")
MODEL_SIZE_GB=$(echo "scale=2; ${MODEL_SIZE_BYTES}/1024/1024/1024" | bc 2>/dev/null || echo "0")

if [ "${MODEL_SIZE_BYTES}" -lt 5000000000 ]; then
    echo -e "\n${RED}[ERROR]${NC} Model file appears to be invalid or incomplete!"
    echo -e "  Expected size: ~7-8 GB (Q8_0 8-bit quantization)"
    echo -e "  Actual size:   ${MODEL_SIZE_GB} GB (${MODEL_SIZE_BYTES} bytes)"
    exit 1
fi

echo -e "\n${GREEN}[SUCCESS]${NC} Model validated successfully!"
echo -e "  File: ${MODEL_FILE}"
echo -e "  Size: ${MODEL_SIZE_GB} GB"

# Start benchmark API server in background
echo -e "\n${BLUE}[INFO]${NC} Starting benchmark API server on port 8082..."
python3 /app/benchmark_api.py &
BENCHMARK_API_PID=$!

# Give it a moment to start
sleep 2

# Start llama-server with NUMA awareness for dual-socket optimization
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Starting llama-server with NUMA optimizations...${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Control OpenBLAS threading (critical fix for thread explosion)
# OpenBLAS in Ubuntu/Debian uses pthreads backend, NOT OpenMP
# OMP_NUM_THREADS does NOT control OpenBLAS pthreads!
# Must use OpenBLAS-specific environment variables:
export OPENBLAS_NUM_THREADS=1
export GOTO_NUM_THREADS=1

# Additional OpenMP controls for any remaining OpenMP usage
export OMP_NUM_THREADS=1
export OMP_DYNAMIC=FALSE
export OMP_NESTED=FALSE
export OMP_MAX_ACTIVE_LEVELS=1

echo -e "${BLUE}[INFO]${NC} Thread control environment:"
echo -e "  OPENBLAS_NUM_THREADS=${OPENBLAS_NUM_THREADS}"
echo -e "  GOTO_NUM_THREADS=${GOTO_NUM_THREADS}"
echo -e "  OMP_NUM_THREADS=${OMP_NUM_THREADS}"
echo -e "  OMP_DYNAMIC=${OMP_DYNAMIC}"

# Optimized configuration for dual-socket Xeon 6240R:
# - threads=56: Conservative thread count (leaves headroom for OS/server threads)
# - threads-batch=56: Same as threads for balanced processing
# - batch-size=512: Reduced from 1024 for better CPU cache utilization
# - ubatch-size=128: Reduced from 160 for better CPU performance
# - parallel=1: Single request focus for testing (can increase after optimization)
# - cache-type-k/v q8_0: Quantize KV cache to 8-bit (saves memory, minimal quality loss)
# - mlock: Lock model in RAM to prevent swapping
# - no-mmap: Disable memory mapping for better NUMA locality
# Note: Removed --numa distribute (was creating 153 threads instead of 56!)
# Note: OS-level NUMA scheduling handles cross-socket memory access
# Note: No OpenBLAS linked (blank ldd output confirmed)

exec llama-server \
    --model "${MODEL_FILE}" \
    --host "${LLAMA_HOST}" \
    --port "${LLAMA_PORT}" \
    --threads 56 \
    --threads-batch 56 \
    --ctx-size "${LLAMA_CONTEXT_SIZE}" \
    -ngl 0 \
    --batch-size 512 \
    --ubatch-size 128 \
    --parallel 1 \
    --cache-type-k q8_0 \
    --cache-type-v q8_0 \
    --mlock \
    --no-mmap \
    --metrics \
    --verbose

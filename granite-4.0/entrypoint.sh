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
MODEL_PATTERN="*UD-Q4_K_M*"
MODEL_DIR="/app/models"
MODEL_FILE="${MODEL_DIR}/granite-4.0-h-tiny.gguf"

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

        # Try to find the Q4_K_M model
        Q4_MODEL=$(find "${MODEL_DIR}" -name "*Q4_K_M*.gguf" -type f | head -n 1)

        if [ -n "${Q4_MODEL}" ]; then
            echo -e "${YELLOW}[ACTION]${NC} Creating symlink from existing Q4_K_M model..."
            ln -sf "${Q4_MODEL}" "${MODEL_FILE}"
            echo -e "${GREEN}[SUCCESS]${NC} Symlink created: ${MODEL_FILE} -> ${Q4_MODEL}"
        else
            echo -e "${RED}[ERROR]${NC} No Q4_K_M model found in directory"
            echo -e "${YELLOW}[ACTION]${NC} Will attempt to download..."
        fi
    fi

    # If still no model file, download it
    if [ ! -f "${MODEL_FILE}" ]; then
        echo -e "\n${BLUE}[INFO]${NC} Downloading model from HuggingFace..."
        echo -e "${YELLOW}[WARNING]${NC} This will download ~4.5GB and may take several minutes"

        export HF_HUB_ENABLE_HF_TRANSFER=1

        # Download the entire repo first to see what's available
        echo -e "${BLUE}[INFO]${NC} Downloading from ${MODEL_REPO}..."

        hf download "${MODEL_REPO}" \
            --include "*.gguf" \
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

        # Find the Q4_K_M model (trying various patterns)
        echo -e "\n${BLUE}[INFO]${NC} Looking for Q4_K_M model..."
        DOWNLOADED_MODEL=$(find "${MODEL_DIR}" -type f -name "*Q4_K_M*.gguf" 2>/dev/null | head -n 1)

        if [ -z "${DOWNLOADED_MODEL}" ]; then
            echo -e "${YELLOW}[WARNING]${NC} Q4_K_M model not found, trying other patterns..."
            DOWNLOADED_MODEL=$(find "${MODEL_DIR}" -type f -name "*q4*k*m*.gguf" -o -name "*Q4*K*M*.gguf" 2>/dev/null | head -n 1)
        fi

        if [ -n "${DOWNLOADED_MODEL}" ]; then
            echo -e "${YELLOW}[ACTION]${NC} Creating symlink to downloaded model..."
            ln -s "${DOWNLOADED_MODEL}" "${MODEL_FILE}"
            echo -e "${GREEN}[SUCCESS]${NC} Model ready: ${MODEL_FILE}"
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

if [ "${MODEL_SIZE_BYTES}" -lt 1000000000 ]; then
    echo -e "\n${RED}[ERROR]${NC} Model file appears to be invalid or incomplete!"
    echo -e "  Expected size: ~4-5 GB"
    echo -e "  Actual size:   ${MODEL_SIZE_GB} GB (${MODEL_SIZE_BYTES} bytes)"
    exit 1
fi

echo -e "\n${GREEN}[SUCCESS]${NC} Model validated successfully!"
echo -e "  File: ${MODEL_FILE}"
echo -e "  Size: ${MODEL_SIZE_GB} GB"

# Start llama-server
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Starting llama-server...${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

exec llama-server \
    --model "${MODEL_FILE}" \
    --host "${LLAMA_HOST}" \
    --port "${LLAMA_PORT}" \
    --threads "${LLAMA_THREADS}" \
    --ctx-size "${LLAMA_CONTEXT_SIZE}" \
    --n-gpu-layers 0 \
    --metrics \
    --verbose

# ================================================================
#  Password Crack Simulator — Makefile
#
#  Targets:
#    make cpu          — builds CPU version (g++, any machine)
#    make gpu          — builds GPU version (nvcc, requires CUDA)
#    make run-front    — starts frontend server
#    make clean        — removes binaries
# ================================================================

PORT      ?= 8081
FRONT_DIR  = src/front

# ── CPU ──────────────────────────────────────────────────────────
CPU_TARGET = password-crack-cpu
CPU_DIR    = src/backend/cpu
CPU_SRCS   = $(CPU_DIR)/main.cpp \
             $(CPU_DIR)/cracker/cracker.cpp \
             $(CPU_DIR)/output/output.cpp
CPU_FLAGS  = -O3 -march=native -mavx2 -std=c++17 -pthread \
             -I$(CPU_DIR)

# ── GPU ──────────────────────────────────────────────────────────
GPU_TARGET = password-crack-gpu
GPU_DIR    = src/backend/gpu
GPU_SRC    = $(GPU_DIR)/main.cu

# Auto-detect GPU SM (override with: make gpu SM=89)
SM        ?= $(shell nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null \
               | head -1 | tr -d '.' || echo "86")
GPU_FLAGS  = -O3 -arch=sm_$(SM) -std=c++17 \
             --compiler-options "-O3 -march=native -mavx2"

# ── Targets ──────────────────────────────────────────────────────
all: cpu
	@echo ""
	@echo "  make cpu          - CPU version (any machine)"
	@echo "  make gpu          - GPU version (needs CUDA + nvcc)"
	@echo "  make run-front    - frontend on localhost:$(PORT)"

build:
	bash utils/download_data.sh

cpu: $(CPU_SRCS)
	g++ $(CPU_FLAGS) -o $(CPU_TARGET) $^
	@echo "✔  CPU binary: ./$(CPU_TARGET)"
	@echo "   usage: ./$(CPU_TARGET) <password> <strength>"

gpu: $(GPU_SRC)
	nvcc $(GPU_FLAGS) -o $(GPU_TARGET) $<
	@echo "✔  GPU binary: ./$(GPU_TARGET)  (sm_$(SM))"
	@echo "   usage: ./$(GPU_TARGET) <password> <strength>"

run-front:
	@echo "Front running on http://localhost:$(PORT)"
	@echo "Press CTRL+C to stop."
	@python3 -m http.server $(PORT) --directory $(FRONT_DIR)

clean:
	rm -f $(CPU_TARGET) $(GPU_TARGET)

help:
	@echo ""
	@echo "  make              - builds CPU version"
	@echo "  make cpu          - builds CPU version (g++)"
	@echo "  make gpu          - builds GPU version (nvcc, CUDA required)"
	@echo "  make gpu SM=89    - GPU for RTX 4090 (Ada Lovelace)"
	@echo "  make gpu SM=120   - GPU for RTX 5060 (Blackwell)"
	@echo "  make run-front           - frontend on port $(PORT)"
	@echo "  make run-front PORT=3000 - frontend on custom port"
	@echo "  make clean        - removes binaries"
	@echo ""

.PHONY: all build cpu gpu run-front clean help
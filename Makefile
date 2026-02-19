-include config.env

USE_GPU ?= false
GPU_SM ?= 86
FRONT_PORT ?= 8081
BACKEND_PORT ?= 8082

CPU_FLAGS = -O3 -march=native -mavx2 -std=c++17 -pthread -Isrc/backend/cpu
GPU_FLAGS = -O3 -arch=sm_$(GPU_SM) -std=c++17 --compiler-options "-O3 -march=native -mavx2"

TARGETS = cpu
ifeq ($(USE_GPU),true)
	TARGETS += gpu
endif

all: $(TARGETS)
	@echo ""
	@echo "build complete! (USE_GPU=$(USE_GPU))"

cpu:
	@echo "building CPU binary."
	@g++ $(CPU_FLAGS) -o password-crack-cpu src/backend/cpu/main.cpp src/backend/cpu/cracker/cracker.cpp src/backend/cpu/output/output.cpp

gpu:
	@echo "building GPU binary (sm_$(GPU_SM))."
	@nvcc $(GPU_FLAGS) -o password-crack-gpu src/backend/gpu/main.cu

run-front:
	@echo "running frontend on port $(FRONT_PORT)."
	@python3 -m http.server $(FRONT_PORT) --directory src/front

build-data:
	bash utils/download_data.sh

clean:
	rm -f password-crack-cpu password-crack-gpu results.csv

help:
	@echo "  make all       - Build based on config.env"
	@echo "  make cpu       - Build CPU binary only"
	@echo "  make gpu       - Build GPU binary (sm_$(GPU_SM))"
	@echo "  make build-data- Download rockyou.txt"
	@echo "  make clean     - Remove binaries"

.PHONY: all cpu gpu run-front build-data clean help
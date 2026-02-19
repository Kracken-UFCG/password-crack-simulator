# Password Crack Simulator (Kracken)

This project is a password cracking simulator designed to evaluate and compare the performance of CPU and NVIDIA GPU (CUDA) brute-force algorithms, alongside dictionary attacks. It provides a local API backend and a web frontend to test password strengths and measure cracking times.

## Configuration

Before running the application, configure your environment using the `config.env` file located in the root directory:

1. Set `USE_GPU=true` if you have an NVIDIA GPU and want to compile the CUDA binary. Set it to `false` for CPU-only execution.
2. Set `GPU_SM` to match your NVIDIA architecture (e.g., 120 for RTX 5000 series, 89 for RTX 4000 series, 86 for RTX 3000 series).
3. Set `FRONT_PORT` and `BACKEND_PORT` (defaults are 8081 and 8082).

## How to Use

### Prerequisites

* Docker and Docker Compose installed.
* NVIDIA Container Toolkit installed on the host machine (only required if using the GPU).

### Setup Steps

1. Download the dictionary dataset (RockYou):

```bash
make build-data

```

2. If you are using an NVIDIA GPU, open the `docker-compose.yaml` file and uncomment the `deploy` block under the `backend` service to enable hardware passthrough. If you are running on a CPU-only machine, leave it commented.
4. Build and start the containers:

```bash
docker compose up -d --build

```

### Accessing the Simulator

* **Web Interface:** Open your browser and navigate to `http://localhost:8081` (or your configured `FRONT_PORT`).
* **API Endpoint:** You can send HTTP POST requests directly to the backend. Example using cURL:

```bash
curl -X POST http://localhost:8082/crack \
  -d "password=krak" \
  -d "strength=Weak" \
  -d "gpu=true"

```
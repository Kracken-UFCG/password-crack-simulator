# 🦑 KRACKEN - Password Crack Simulator

![System Status](https://img.shields.io/badge/System-ONLINE-00ff88?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20WSL2%20%7C%20Docker-0f6fff?style=for-the-badge)
![CUDA](https://img.shields.io/badge/CUDA-Supported-76b900?style=for-the-badge)

**KRACKEN** is an advanced, educational Password Crack Simulator designed to demonstrate the real-world implications of password strength, computational power, and Key Derivation Functions (KDFs). 

It features a retro-cyberpunk web interface, a multi-threaded CPU engine with POSIX thread affinity, and a blazing-fast GPU brute-force engine powered by CUDA.

> ! **Disclaimer:** This tool is strictly for educational purposes and local benchmarking. Do not use it against systems or hashes you do not explicitly own.

---

## Features

- **Dual-Engine Architecture:**
  - **CPU Cracker:** Multi-threaded C++ engine utilizing `sched_setaffinity` for core pinning. Supports `bcrypt` Key Derivation Function (KDF) simulation via `libxcrypt`.
  - **GPU Cracker:** Highly optimized CUDA C++ engine using constant/shared memory and AVX2 (for phase 1). Capable of checking millions of hashes per second.
- **Two-Phase Attack Pipeline:**
  - *Phase 1:* AVX2-accelerated Dictionary Attack (using `rockyou.txt`).
  - *Phase 2:* Exhaustive Brute-Force Attack.
- **Advanced Metrics:** Calculates Maximum Entropy, Shannon Entropy, Class-based Entropy, Search Space, and Latency per operation (in nanoseconds).
- **Batch Processing:** Python CLI script (`batch_crack.py`) to process large `.csv` lists of passwords automatically.
- **Retro Web UI:** Vanilla JS/HTML/CSS interface with real-time strength classification (Weak/Medium/Strong) and live terminal output.

---

## Architecture & Tech Stack

- **Frontend:** Vanilla HTML5, CSS3 (Custom Cyberpunk theme), JavaScript (`regex.js`, `classifier.js`).
- **Backend API:** Python 3 `http.server` (`server.py`) handling POST requests and CSV logging.
- **Core Cracking Engines:** C++17, CUDA.
- **Dependencies:** `glibc` / `libxcrypt` (for `<crypt.h>`), `pthread`, `nvcc` (CUDA Toolkit).

---

## Prerequisites

- **Docker (Recommended):** Docker and Docker Compose installed.
- **Manual Build:** Due to low-level POSIX thread management and Linux-native cryptography libraries (`<crypt.h>`), manual builds require **Linux** (Ubuntu 24.04 recommended) or **WSL2** on Windows.
- **GPU Acceleration (Optional):** NVIDIA GPU (e.g., RTX 5060) and CUDA Toolkit / NVIDIA Container Toolkit installed for Docker GPU passthrough.

---

## Installation & Setup

### 1. Clone the Repository
```bash
git clone [https://github.com/Kracken-UFCG/password-crack-simulator.git](https://github.com/Kracken-UFCG/password-crack-simulator.git)
cd password-crack-simulator
```

### 2. Download the Wordlist

Run the setup script to automatically fetch and extract the `rockyou.txt` dictionary into the `data/` folder:

```bash
chmod +x download_data.sh
./download_data.sh
```

### 3. Configuration (`config.env`)

Create or edit the `config.env` file in the root directory to match your hardware:

```env
USE_GPU=true
GPU_SM=120           # Example: 120 for RTX 5060 (Blackwell), 89 for Ada Lovelace, 86 for Ampere
FRONT_PORT=8081
BACKEND_PORT=8082
KDF=default          # Or specify bcrypt cost (e.g., KDF=12)
```

---

## Usage

### Method 1: Docker Deployment (Easiest & Recommended)

Containerization is the fastest way to get KRACKEN running with all dependencies pre-configured.

**For CPU-only mode:**

```bash
docker compose up --build
```

**For GPU acceleration:**

1. Open `docker-compose.yml`.
2. Uncomment the `deploy` block under the backend service to enable NVIDIA GPU support.
3. Run the container:

```bash
docker compose up --build
```

Once running, open your browser and navigate to `http://localhost:8081`.

---

### Method 2: Manual Local Build (Linux / WSL2)

If you prefer running the services natively without Docker:

**1. Compile the engines:**

```bash
make all
```

*(To compile specifically for an RTX 5060 manually: `nvcc -O3 -arch=sm_120 -std=c++17 --compiler-options "-O3 -march=native -mavx2 -pthread" -o password-crack-gpu src/backend/gpu/main.cu`)*

**2. Start the Python API Server:**

```bash
python3 src/backend/server.py
```

**3. Serve the Frontend:**
Open a new terminal session:

```bash
cd src/front
python3 -m http.server 8081
```

Access the UI at `http://localhost:8081`.

---

### Option 3: Batch CLI Mode

Use the batch script to test multiple passwords at once without the web UI.

1. Create a `senhas.csv` file in the root directory with one password per line.
2. Run the script:

```bash
python3 batch_crack.py
```

3. Check the detailed output in `batch_results.csv`.

---

## Output Metrics Explained

When an analysis completes, KRACKEN logs detailed metrics to `results.csv` and displays them in the UI:

* **Strength Class:** Weak, Medium, or Strong based on regex rules.
* **Method:** Evaluates if the password was `leaked` (Dictionary) or `cracked` (Brute Force).
* **Latency/Op:** Nanoseconds taken per individual hash check.
* **KDF Simulation:** Time added to the cracking process by enforcing a Key Derivation Function cost (e.g., bcrypt).
* **Entropy:** Measures the unpredictability of the password (Max, Shannon, and Class-based algorithms).

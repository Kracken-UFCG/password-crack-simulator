/**
 * ================================================================
 *  password-crack-gpu — CUDA brute force
 *
 *  Compilation (RTX 5060 = Blackwell = sm_120):
 *    nvcc -O3 -arch=sm_120 -std=c++17 \
 *         --compiler-options "-O3 -march=native -mavx2 -pthread" \
 *         -o password-crack-gpu main.cu
 *
 *  For other GPUs, replace sm_120:
 *    RTX 4070/4090  →  sm_89
 *    RTX 3060/3070  →  sm_86
 *    RTX 2060/2070  →  sm_75
 *
 *  Usage:
 *    ./password-crack-gpu <password> <strength>
 * ================================================================
 */

#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <cstring>
#include <cstdio>
#include <cstdint>
#include <algorithm>
#include <iomanip>
#include <immintrin.h>
#include <cuda_runtime.h>

using namespace std;
using namespace chrono;

static const char* ROCKYOU_PATH = "data/rockyou.txt";
static const int   MAX_LEN      = 10;   // GPU can handle up to 10 chars

// Host-side charset (also copied to GPU constant memory)
static const char HOST_CHARSET[] =
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "0123456789!@#$%&*()";
static const int CHARSET_LEN = 71;

// ── GPU constant memory — fast read-only cache on every SM ──────
__constant__ char   d_charset[72];
__constant__ char   d_target[11];
__constant__ int    d_target_len;
__constant__ int    d_str_len;

// ================================================================
//  CUDA Kernel — each thread tests one candidate per step.
//
//  Candidate is generated from a linear index converted to base-71.
//  Threads are organized in a 1D grid covering the full batch.
//  Uses __shared__ flag so the entire warp exits on first match.
// ================================================================
__global__ void kernel_brute(
    uint64_t base_idx,
    uint64_t batch_size,
    int*     d_found,
    char*    d_result)
{
    __shared__ int s_found;
    if (threadIdx.x == 0) s_found = *d_found;
    __syncthreads();
    if (s_found) return;

    uint64_t tid  = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    uint64_t step = (uint64_t)gridDim.x  * blockDim.x;

    char candidate[11];
    int  len = d_str_len;

    for (uint64_t i = tid; i < batch_size; i += step) {
        if (s_found) return;

        // Convert linear index → string in base CHARSET_LEN
        uint64_t tmp = base_idx + i;
        for (int j = len - 1; j >= 0; j--) {
            candidate[j] = d_charset[tmp % (uint64_t)CHARSET_LEN];
            tmp          /= (uint64_t)CHARSET_LEN;
        }
        candidate[len] = '\0';

        // Compare with target
        bool match = true;
        for (int j = 0; j < len; j++) {
            if (candidate[j] != d_target[j]) { match = false; break; }
        }

        if (match) {
            int old = atomicExch(d_found, 1);
            if (old == 0) {
                for (int j = 0; j <= len; j++) d_result[j] = candidate[j];
                s_found = 1;
            }
            return;
        }
    }
}

// ================================================================
//  Structs
// ================================================================
struct DictResult {
    bool     leaked;
    uint64_t lines_checked;
    double   elapsed_sec;
};

struct BruteResult {
    bool     found;
    string   password;
    uint64_t attempts;
    double   elapsed_sec;
    double   latency_ns;
    string   method;
};

// ================================================================
//  AVX2 fast comparison — dictionary phase runs on CPU
// ================================================================
static inline bool fast_eq(const char* a, const char* b, int len) {
#ifdef __AVX2__
    if (len >= 16 && len <= 32) {
        __m256i va  = _mm256_loadu_si256(reinterpret_cast<const __m256i*>(a));
        __m256i vb  = _mm256_loadu_si256(reinterpret_cast<const __m256i*>(b));
        __m256i cmp = _mm256_cmpeq_epi8(va, vb);
        int     msk = _mm256_movemask_epi8(cmp);
        int     req = (len == 32) ? -1 : ((1 << len) - 1);
        return (msk & req) == req;
    }
#endif
    return memcmp(a, b, len) == 0;
}

// ================================================================
//  Phase 1 — Dictionary attack (CPU + AVX2)
// ================================================================
static DictResult check_dictionary(const string& password) {
    FILE* f = fopen(ROCKYOU_PATH, "rb");
    if (!f) return { false, 0, 0.0 };

    int target_len = (int)password.size();
    alignas(32) char target_buf[32] = {0};
    memcpy(target_buf, password.c_str(), min(target_len, 32));

    char     raw[512];
    uint64_t count = 0;
    bool     found = false;

    auto t0 = high_resolution_clock::now();

    while (fgets(raw, sizeof(raw), f)) {
        int len = (int)strlen(raw);
        while (len > 0 && (raw[len-1] == '\n' || raw[len-1] == '\r'))
            raw[--len] = '\0';

        if (len != target_len) { count++; continue; }

        alignas(32) char line_buf[32] = {0};
        memcpy(line_buf, raw, len);

        if (fast_eq(line_buf, target_buf, len)) {
            found = true; count++; break;
        }
        count++;
    }

    double elapsed = duration<double>(high_resolution_clock::now() - t0).count();
    fclose(f);
    return { found, count, elapsed };
}

// ================================================================
//  Phase 2 — GPU Brute Force
// ================================================================
static BruteResult brute_force_gpu(const string& password) {
    int dev_count = 0;
    cudaGetDeviceCount(&dev_count);
    if (dev_count == 0) {
        cerr << "[gpu] no CUDA device found.\n";
        return { false, "", 0, 0.0, 0.0, "not_found" };
    }

    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    cerr << "[gpu] device: " << prop.name
         << " | SMs: " << prop.multiProcessorCount
         << " | VRAM: " << prop.totalGlobalMem / 1024 / 1024 << " MB\n";

    int target_len = (int)password.size();
    if (target_len > MAX_LEN) {
        cerr << "[gpu] password too long (max " << MAX_LEN << " chars).\n";
        return { false, "", 0, 0.0, 0.0, "not_found" };
    }

    // Copy charset and target to GPU constant memory
    char target_padded[11] = {0};
    memcpy(target_padded, password.c_str(), target_len);

    cudaMemcpyToSymbol(d_charset,    HOST_CHARSET,   CHARSET_LEN + 1);
    cudaMemcpyToSymbol(d_target,     target_padded,  11);
    cudaMemcpyToSymbol(d_target_len, &target_len,    sizeof(int));
    cudaMemcpyToSymbol(d_str_len,    &target_len,    sizeof(int));

    // Allocate result buffers on GPU
    int*  dev_found;  cudaMalloc(&dev_found,  sizeof(int));
    char* dev_result; cudaMalloc(&dev_result, 11);
    cudaMemset(dev_found,  0, sizeof(int));
    cudaMemset(dev_result, 0, 11);

    // Grid configuration — maximize occupancy
    // Each SM runs 32 blocks × 256 threads = 8192 threads/SM
    const int BLOCK_SIZE = 256;
    const int GRID_SIZE  = prop.multiProcessorCount * 32;

    // Batch size: how many candidates per kernel launch
    // Large batches = fewer kernel launches = less overhead
    const uint64_t BATCH = (uint64_t)BLOCK_SIZE * GRID_SIZE * 512ULL;

    // Compute total search space: CHARSET_LEN ^ target_len
    uint64_t total = 1;
    for (int i = 0; i < target_len; i++) {
        if (total > UINT64_MAX / (uint64_t)CHARSET_LEN) { total = UINT64_MAX; break; }
        total *= (uint64_t)CHARSET_LEN;
    }

    cerr << "[gpu] search space: " << total << " candidates\n";
    cerr << "[gpu] grid: " << GRID_SIZE << " blocks x " << BLOCK_SIZE << " threads"
         << " | batch: " << BATCH << "\n";

    int      h_found  = 0;
    char     h_result[11] = {0};
    bool     success  = false;
    uint64_t attempts = 0;

    auto t0 = high_resolution_clock::now();

    for (uint64_t base = 0; base < total && !h_found; base += BATCH) {
        uint64_t batch_sz = min(BATCH, total - base);

        kernel_brute<<<GRID_SIZE, BLOCK_SIZE>>>(base, batch_sz, dev_found, dev_result);

        cudaError_t err = cudaDeviceSynchronize();
        if (err != cudaSuccess) {
            cerr << "[gpu] kernel error: " << cudaGetErrorString(err) << "\n";
            break;
        }

        attempts += batch_sz;
        cudaMemcpy(&h_found, dev_found, sizeof(int), cudaMemcpyDeviceToHost);
    }

    if (h_found) {
        cudaMemcpy(h_result, dev_result, 11, cudaMemcpyDeviceToHost);
        success = true;
    }

    double elapsed  = duration<double>(high_resolution_clock::now() - t0).count();
    double lat_ns   = (attempts > 0) ? (elapsed * 1e9 / (double)attempts) : 0.0;
    string method   = success ? "brute_force_gpu" : "not_found";

    cudaFree(dev_found);
    cudaFree(dev_result);

    return { success, string(h_result, target_len), attempts, elapsed, lat_ns, method };
}

// ================================================================
//  CSV output
// ================================================================
static void print_csv_header() {
    cout << "password"
         << ",strength"
         << ",leaked"
         << ",dict_entries_checked"
         << ",dict_time_s"
         << ",cracktime_s"
         << ",attempts"
         << ",latency_ns"
         << ",method"
         << "\n";
}

static void print_csv_row(
    const string&     password,
    const string&     strength,
    const DictResult& dict,
    const BruteResult& brute)
{
    string   method;
    double   cracktime  = 0.0;
    uint64_t attempts   = 0;
    double   latency_ns = 0.0;

    if (dict.leaked) {
        method     = "dictionary";
        cracktime  = dict.elapsed_sec;
        attempts   = dict.lines_checked;
        latency_ns = (attempts > 0)
            ? (dict.elapsed_sec * 1e9 / (double)attempts)
            : 0.0;
    } else {
        method     = brute.method;
        cracktime  = brute.elapsed_sec;
        attempts   = brute.attempts;
        latency_ns = brute.latency_ns;
    }

    cout << fixed << setprecision(9);
    cout << password
         << "," << strength
         << "," << (dict.leaked ? "yes" : "no")
         << "," << dict.lines_checked
         << "," << dict.elapsed_sec
         << "," << cracktime
         << "," << attempts
         << "," << latency_ns
         << "," << method
         << "\n";
}

// ================================================================
//  Main
// ================================================================
int main(int argc, char* argv[]) {
    if (argc != 3) {
        cerr << "usage: ./password-crack-gpu <password> <strength>\n";
        cerr << "  ex:  ./password-crack-gpu \"abc123\" \"weak\"\n";
        return 1;
    }

    string password = argv[1];
    string strength = argv[2];

    cerr << "[gpu] target=" << password << " strength=" << strength << "\n";

    // Phase 1 — dictionary (always runs on CPU)
    cerr << "[gpu] running dictionary attack (cpu)...\n";
    DictResult dict = check_dictionary(password);

    // Phase 2 — GPU brute force (only if not found in dictionary)
    BruteResult brute = { false, "", 0, 0.0, 0.0, "not_found" };
    if (!dict.leaked && (int)password.size() <= MAX_LEN) {
        cerr << "[gpu] running brute force (gpu)...\n";
        brute = brute_force_gpu(password);
    } else if (dict.leaked) {
        cerr << "[gpu] found in dictionary — skipping brute force.\n";
    }

    print_csv_header();
    print_csv_row(password, strength, dict, brute);

    return 0;
}

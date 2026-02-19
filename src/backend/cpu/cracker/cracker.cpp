#include "cracker.hpp"

#include <thread>
#include <atomic>
#include <mutex>
#include <vector>
#include <chrono>
#include <cstring>
#include <cstdio>
#include <cstdint>
#include <algorithm>
#include <immintrin.h>
#include <pthread.h>
#include <sched.h>

using namespace std;
using namespace chrono;

static const char* ROCKYOU_PATH = "data/rockyou.txt";
static const char* CHARSET      = "abcdefghijklmnopqrstuvwxyz"
                                   "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                   "0123456789!@#$%&*()";
static const int   CHARSET_LEN  = 71;
static const int   MAX_LEN      = 8;

static atomic<bool>     g_found(false);
static atomic<uint64_t> g_tested(0);
static string           g_found_str;
static mutex            g_mtx;

// ================================================================
//  AVX2 fast comparison — 32 bytes in a single CPU instruction.
//  Falls back to memcmp on CPUs without AVX2 support.
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
//  Phase 1 — Dictionary attack (RockYou)
// ================================================================
DictResult check_dictionary(const string& password) {
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
            found = true;
            count++;
            break;
        }
        count++;
    }

    double elapsed = duration<double>(high_resolution_clock::now() - t0).count();
    fclose(f);
    return { found, count, elapsed };
}

// ================================================================
//  Phase 2 — Optimized multithreaded brute force
//
//  Optimizations:
//  1. Incremental generation  — no divisions in the hot loop (odometer)
//  2. uint64_t comparison     — one integer op replaces memcmp for <=8 chars
//  3. Batched atomic check    — g_found read every 4096 iters, not every iter
//  4. CPU affinity            — each thread pinned to a physical core
// ================================================================
struct WorkerArgs {
    int  thread_id;
    int  num_threads;
    int  str_len;
    char target[MAX_LEN + 1];
    int  target_len;
    int  num_cores;
};

static void worker(WorkerArgs a) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(a.thread_id % a.num_cores, &cpuset);
    sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);

    uint64_t total = 1;
    for (int i = 0; i < a.str_len; i++) {
        if (total > UINT64_MAX / (uint64_t)CHARSET_LEN) { total = UINT64_MAX; break; }
        total *= (uint64_t)CHARSET_LEN;
    }

    uint64_t per   = total / (uint64_t)a.num_threads;
    uint64_t start = (uint64_t)a.thread_id * per;
    uint64_t end   = (a.thread_id == a.num_threads - 1) ? total : start + per;
    if (start >= end) return;

    // Build initial candidate from start index (one-time division only)
    int indices[MAX_LEN] = {0};
    {
        uint64_t tmp = start;
        for (int i = a.str_len - 1; i >= 0; i--) {
            indices[i] = (int)(tmp % (uint64_t)CHARSET_LEN);
            tmp        /= (uint64_t)CHARSET_LEN;
        }
    }

    // Pack target into uint64 for single-shot comparison
    uint64_t target_u64 = 0;
    memcpy(&target_u64, a.target, MAX_LEN);

    char     candidate[MAX_LEN + 1] = {0};
    uint64_t candidate_u64          = 0;
    uint64_t local_count            = 0;

    for (uint64_t idx = start; idx < end; idx++) {
        if ((local_count & 0xFFF) == 0 && g_found) {
            g_tested.fetch_add(local_count, memory_order_relaxed);
            return;
        }

        for (int i = 0; i < a.str_len; i++)
            candidate[i] = CHARSET[indices[i]];

        memcpy(&candidate_u64, candidate, MAX_LEN);
        if (candidate_u64 == target_u64) {
            lock_guard<mutex> lk(g_mtx);
            if (!g_found) {
                g_found     = true;
                g_found_str = string(candidate, a.str_len);
            }
            g_tested.fetch_add(local_count + 1, memory_order_relaxed);
            return;
        }

        // Odometer increment — zero divisions
        for (int i = a.str_len - 1; i >= 0; i--) {
            if (++indices[i] < CHARSET_LEN) break;
            indices[i] = 0;
        }

        local_count++;
    }

    g_tested.fetch_add(local_count, memory_order_relaxed);
}

BruteResult brute_force(const string& password) {
    g_found     = false;
    g_found_str = "";
    g_tested    = 0;

    int num_threads = max(1, (int)thread::hardware_concurrency());
    int target_len  = (int)password.size();

    auto t0 = high_resolution_clock::now();

    for (int len = 1; len <= min(target_len, MAX_LEN) && !g_found; len++) {
        if (len != target_len) continue;

        vector<thread> pool;
        pool.reserve(num_threads);

        for (int t = 0; t < num_threads; t++) {
            WorkerArgs a;
            a.thread_id   = t;
            a.num_threads = num_threads;
            a.str_len     = len;
            a.target_len  = target_len;
            a.num_cores   = num_threads;
            memset(a.target, 0, sizeof(a.target));
            memcpy(a.target, password.c_str(), target_len);
            pool.emplace_back(worker, a);
        }

        for (auto& th : pool) th.join();
    }

    double   elapsed  = duration<double>(high_resolution_clock::now() - t0).count();
    uint64_t attempts = g_tested.load();
    double   lat_ns   = (attempts > 0) ? (elapsed * 1e9 / (double)attempts) : 0.0;
    string   method   = g_found.load() ? "brute_force" : "not_found";

    return { g_found.load(), g_found_str, attempts, elapsed, lat_ns, method };
}
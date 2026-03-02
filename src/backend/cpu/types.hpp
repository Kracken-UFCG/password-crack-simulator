#pragma once
#include <string>
#include <cstdint>

struct DictResult {
    bool        leaked;
    uint64_t    lines_checked;
    double      elapsed_sec;
};

// Novo: metadados do KDF usados no crack
struct KdfMeta {
    bool   enabled;
    int    cost;          // expoente 
    int    rounds;        // 2^cost
    double time_per_attempt_sec;  // tempo de UMA derivação (medido antes do crack)
};

struct BruteResult {
    bool        found;
    std::string password;
    uint64_t    attempts;
    double      elapsed_sec;   // tempo total do crack (já inclui KDF por tentativa)
    double      kdf_total_sec; // tempo acumulado só no KDF durante o crack
    double      latency_ns;    // ns por tentativa (com KDF embutido)
    std::string method;
};
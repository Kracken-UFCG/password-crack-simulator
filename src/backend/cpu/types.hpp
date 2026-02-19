#pragma once
#include <string>
#include <cstdint>

// ================================================================
//  types.hpp — shared structs across all modules
// ================================================================

struct DictResult {
    bool        leaked;
    uint64_t    lines_checked;
    double      elapsed_sec;
};

struct BruteResult {
    bool        found;
    std::string password;
    uint64_t    attempts;
    double      elapsed_sec;
    double      latency_ns;
    std::string method;    // "dictionary" | "brute_force" | "not_found"
};
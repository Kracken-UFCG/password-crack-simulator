#pragma once
#include <string>

// ================================================================
//  kdf.hpp — bcrypt Key Derivation Function
//
//  cost = expoente bcrypt (10, 12, 14…)
//  rounds = 2^cost (calculado internamente)
// ================================================================

struct KdfResult {
    std::string hash;         // hash bcrypt completo (60 chars)
    int         cost;         // expoente passado (ex: 12)
    int         rounds;       // 2^cost
    double      elapsed_sec;  // tempo de UMA derivação
};

KdfResult kdf_bcrypt(const std::string& password, int cost);

bool kdf_bcrypt_verify(const std::string& password,
                       const std::string& hash,
                       double*            elapsed_sec);
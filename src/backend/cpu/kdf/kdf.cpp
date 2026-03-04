#include "kdf.hpp"
#include <openssl/evp.h>
#include <cstring>
#include <stdexcept>
#include <chrono>

// OpenSSL expõe bcrypt via PKCS5_v2_bcrypt_pbkdf — disponível em libcrypto.
// Para um hash bcrypt completo (com salt embutido no formato $2b$), usamos
// a função crypt_ra do libxcrypt (glibc moderna já inclui).
//
// Dependências: -lcrypt  (glibc/libxcrypt) já presente em qualquer Linux.
// Alternativa se não tiver: -lbcrypt (OpenBSD portable bcrypt).

#include <crypt.h>   // crypt_r, crypt_gensalt_r  — libxcrypt / glibc

using namespace std;
using namespace chrono;

// ----------------------------------------------------------------
//  Gera salt bcrypt no formato $2b$<cost>$<22 chars base64>
// ----------------------------------------------------------------
static string make_bcrypt_salt(int cost) {
    struct crypt_data cd{};
    // crypt_gensalt_ra aloca e retorna um salt novo
    char* salt = crypt_gensalt_ra("$2b$", cost, nullptr, 0);
    if (!salt) throw runtime_error("crypt_gensalt_ra failed");
    string s(salt);
    free(salt);
    return s;
}

// ----------------------------------------------------------------
KdfResult kdf_bcrypt(const string& password, int cost) {
    string salt = make_bcrypt_salt(cost);

    struct crypt_data cd{};
    cd.initialized = 0;

    auto t0 = high_resolution_clock::now();
    char* result = crypt_r(password.c_str(), salt.c_str(), &cd);
    double elapsed = duration<double>(high_resolution_clock::now() - t0).count();

    if (!result) throw runtime_error("crypt_r failed");

    return KdfResult {
        .hash        = string(result),
        .cost        = cost,
        .rounds      = 1 << cost,   // 2^cost
        .elapsed_sec = elapsed
    };
}

// ----------------------------------------------------------------
bool kdf_bcrypt_verify(const string& password,
                       const string& hash,
                       double*       elapsed_sec) {
    struct crypt_data cd{};
    cd.initialized = 0;

    auto t0 = high_resolution_clock::now();
    char* result = crypt_r(password.c_str(), hash.c_str(), &cd);
    *elapsed_sec = duration<double>(high_resolution_clock::now() - t0).count();

    if (!result) return false;
    return hash == string(result);
}
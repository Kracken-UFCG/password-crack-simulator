#include <iostream>
#include <string>
#include <thread>
#include "types.hpp"
#include "cracker/cracker.hpp"
#include "kdf/kdf.hpp"
#include "output/output.hpp"

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "usage: ./password-crack-cpu <password> <strength> [--kdf <cost>]\n";
        std::cerr << "  ex:  ./password-crack-cpu \"abc123\" \"weak\" --kdf 12\n";
        return 1;
    }

    std::string password = argv[1];
    std::string strength = argv[2];

    // Parse --kdf <cost>
    KdfMeta kdf{ .enabled = false, .cost = 0, .rounds = 0, .time_per_attempt_sec = 0.0 };
    for (int i = 3; i < argc - 1; i++) {
        if (std::string(argv[i]) == "--kdf") {
            kdf.cost    = std::stoi(argv[i + 1]);
            kdf.rounds  = 1 << kdf.cost;   // 2^cost
            kdf.enabled = true;
        }
    }

    std::cerr << "[cpu] target=" << password
              << " strength=" << strength
              << " threads=" << std::thread::hardware_concurrency();
    if (kdf.enabled)
        std::cerr << " kdf=bcrypt cost=" << kdf.cost
                  << " rounds=" << kdf.rounds;
    std::cerr << "\n";

    // Mede tempo de UMA derivação para reportar time_per_attempt
    if (kdf.enabled) {
        std::cerr << "[cpu] calibrating KDF (1 round)...\n";
        KdfResult sample = kdf_bcrypt(password, kdf.cost);
        kdf.time_per_attempt_sec = sample.elapsed_sec;
        std::cerr << "[cpu] kdf time/attempt=" << sample.elapsed_sec << "s\n";
    }

    // Phase 1 — dictionary
    std::cerr << "[cpu] running dictionary attack...\n";
    DictResult dict = check_dictionary(password);

    // Phase 2 — brute force
    BruteResult brute = { false, "", 0, 0.0, 0.0, 0.0, "not_found" };
    if (!dict.leaked && (int)password.size() <= 8) {
        std::cerr << "[cpu] running brute force...\n";
        brute = brute_force(password, kdf);
    } else if (dict.leaked) {
        std::cerr << "[cpu] found in dictionary — skipping brute force.\n";
    }

    print_csv_header();
    print_csv_row(password, strength, kdf, dict, brute);
    return 0;
}
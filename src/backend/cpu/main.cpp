#include <iostream>
#include <string>
#include <thread>

#include "types.hpp"
#include "cracker/cracker.hpp"
#include "output/output.hpp"

// ================================================================
//  main.cpp (CPU) — entry point
//
//  Usage:
//    ./password-crack-cpu <password> <strength>
//
//  <strength> is determined by the frontend regex — passed as-is.
//  Output: one CSV row to stdout (header always printed first).
// ================================================================

int main(int argc, char *argv[])
{
    if (argc != 3)
    {
        std::cerr << "usage: ./password-crack-cpu <password> <strength>\n";
        std::cerr << "  ex:  ./password-crack-cpu \"abc123\" \"weak\"\n";
        return 1;
    }

    const std::string password = argv[1];
    const std::string strength = argv[2];

    if (password.size() > 8)
    {
        std::cerr << "[!] Password longer than 8 chars — brute force skipped.\n";
    }

    std::cerr << "[cpu] target=" << password
              << " strength=" << strength
              << " threads=" << std::thread::hardware_concurrency()
              << "\n";

    // ========================
    // Phase 1 — Dictionary
    // ========================
    std::cerr << "[cpu] running dictionary attack...\n";
    DictResult dict = check_dictionary(password);

    // ========================
    // Phase 2 — Brute Force
    // ========================
    BruteResult brute{false, "", 0, 0.0, 0.0};

    if (!dict.leaked && password.size() <= 8)
    {
        std::cerr << "[cpu] running brute force...\n";
        brute = brute_force(password);
    }
    else if (dict.leaked)
    {
        std::cerr << "[cpu] found in dictionary — skipping brute force.\n";
    }

    // ========================
    // Output
    // ========================
    print_csv_header();
    print_csv_row(password, strength, dict, brute);

    return 0;
}
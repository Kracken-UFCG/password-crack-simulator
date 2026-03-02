#pragma once
#include <string>
#include "../types.hpp"

// Prints CSV header to stdout
void print_csv_header();

// Prints one CSV row with all Password Achieve metrics
void print_csv_row(
    const std::string& password,
    const std::string& strength,
    const KdfMeta&     kdf,
    const DictResult&  dict,
    const BruteResult& brute
);
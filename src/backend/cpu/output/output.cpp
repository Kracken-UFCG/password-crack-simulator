#include "output.hpp"
#include <iostream>
#include <iomanip>
#include <sstream>
#include <cmath>
#include <unordered_map>
#include <cctype>

using namespace std;

// ================================================================
//  output.cpp — CSV output matching the Password Achieve columns:
//
//  password, strength, leaked, dict_entries, dict_time_s,
//  cracktime_s, attempts, latency_ns, method
// ================================================================

static const int GLOBAL_CHARSET_LEN = 71;

// Entropia máxima (pool inteira)
double entropy_max(int length)
{
    return length * log2((double)GLOBAL_CHARSET_LEN);
}

// Entropia baseada nas classes usadas
double entropy_class_based(const std::string &password)
{
    bool has_lower = false, has_upper = false, has_digit = false, has_symbol = false;

    for (char c : password)
    {
        if (std::islower(c))
            has_lower = true;
        else if (std::isupper(c))
            has_upper = true;
        else if (std::isdigit(c))
            has_digit = true;
        else
            has_symbol = true;
    }

    int charset = 0;
    if (has_lower)
        charset += 26;
    if (has_upper)
        charset += 26;
    if (has_digit)
        charset += 10;
    if (has_symbol)
        charset += 9;

    if (charset == 0)
        return 0.0;

    return password.size() * log2((double)charset);
}

// Shannon real
double entropy_shannon(const std::string &password)
{
    std::unordered_map<char, int> freq;

    for (char c : password)
        freq[c]++;

    double entropy = 0.0;
    int len = password.size();

    for (auto &[ch, count] : freq)
    {
        double p = (double)count / len;
        entropy -= p * log2(p);
    }

    return entropy * len;
}

// Espaço total teórico
long double compute_search_space(int length)
{
    return pow((long double)GLOBAL_CHARSET_LEN, length);
}

// =======

void print_csv_header()
{
    cout << "password"
         << ",strength"
         << ",entropy_max"
         << ",entropy_class"
         << ",entropy_shannon"
         << ",search_space"
         << ",early_ratio"
         << ",leaked"
         << ",dict_entries_checked"
         << ",dict_time_s"
         << ",cracktime_s"
         << ",attempts"
         << ",attempts_per_sec"
         << ",latency_ns"
         << ",method"
         << "\n";
}

void print_csv_row(
    const string &password,
    const string &strength,
    const DictResult &dict,
    const BruteResult &brute)
{
    string method;
    double cracktime = 0.0;
    uint64_t attempts = 0;
    double latency_ns = 0.0;

    if (dict.leaked)
    {
        method = "dictionary";
        cracktime = dict.elapsed_sec;
        attempts = dict.lines_checked;
        latency_ns = (attempts > 0)
                         ? (dict.elapsed_sec * 1e9 / (double)attempts)
                         : 0.0;
    }
    else if (brute.found)
    {
        method = "brute_force";
        cracktime = brute.elapsed_sec;
        attempts = brute.attempts;
        latency_ns = brute.latency_ns;
    }
    else
    {
        method = "not_found";
        cracktime = brute.elapsed_sec;
        attempts = brute.attempts;
        latency_ns = brute.latency_ns;
    }

    // ===== NOVAS MÉTRICAS =====

    int len = password.size();

    double ent_max = entropy_max(len);
    double ent_class = entropy_class_based(password);
    double ent_shannon = entropy_shannon(password);

    uint64_t search_space = compute_search_space(len);

    double early_ratio = (search_space > 0)
                             ? (double)attempts / (double)search_space
                             : 0.0;

    double attempts_per_sec = (cracktime > 0.0)
                                  ? (double)attempts / cracktime
                                  : 0.0;

    cout << fixed << setprecision(9);

    cout << password
         << "," << strength
         << "," << ent_max
         << "," << ent_class
         << "," << ent_shannon
         << "," << search_space
         << "," << early_ratio
         << "," << (dict.leaked ? "yes" : "no")
         << "," << dict.lines_checked
         << "," << dict.elapsed_sec
         << "," << cracktime
         << "," << attempts
         << "," << attempts_per_sec
         << "," << latency_ns
         << "," << method
         << "\n";
}
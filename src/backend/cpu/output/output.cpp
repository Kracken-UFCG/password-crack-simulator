#include "output.hpp"
#include <iostream>
#include <iomanip>
#include <sstream>

using namespace std;

// ================================================================
//  output.cpp — CSV output matching the Password Achieve columns:
//
//  password, strength, leaked, dict_entries, dict_time_s,
//  cracktime_s, attempts, latency_ns, method
// ================================================================

void print_csv_header() {
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

void print_csv_row(
    const string& password,
    const string& strength,
    const DictResult&  dict,
    const BruteResult& brute)
{
    // Determine final method and cracktime
    string method;
    double cracktime = 0.0;
    uint64_t attempts = 0;
    double latency_ns = 0.0;

    if (dict.leaked) {
        method    = "dictionary";
        cracktime = dict.elapsed_sec;
        attempts  = dict.lines_checked;
        latency_ns = (attempts > 0)
            ? (dict.elapsed_sec * 1e9 / (double)attempts)
            : 0.0;
    } else if (brute.found) {
        method     = "brute_force";
        cracktime  = brute.elapsed_sec;
        attempts   = brute.attempts;
        latency_ns = brute.latency_ns;
    } else {
        method     = "not_found";
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
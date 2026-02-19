#pragma once
#include <string>
#include "../types.hpp"

DictResult  check_dictionary(const std::string& password);
BruteResult brute_force(const std::string& password);
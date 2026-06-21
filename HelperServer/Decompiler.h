#pragma once
#include "Common.h"

void ensure_decompiler_running();
std::string decompile_bytecode(const std::string& bytecode);

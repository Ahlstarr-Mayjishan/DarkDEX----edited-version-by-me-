#pragma once
#include "Common.h"

extern std::string g_tool_state_json;
extern std::mutex g_tool_state_mutex;
extern std::mutex g_log_mutex;

size_t file_size_or_zero(const char* path);
bool file_exists(const std::string& path);
std::string read_text_file(const std::string& path);
std::string temp_file_path(const char* prefix);
std::string shell_quote(const std::string& path);
bool run_command_with_input(const std::string& command, const std::string& input, std::string& output);
std::string resolve_worker_path(const std::string& relative_path);
bool command_available(const char* command);
std::string resolve_toolchain_setup_path();
std::string toolchain_status();
std::string open_toolchain_setup();
bool run_python_analyzer(const std::string& source, std::string& output);
bool run_rust_analyzer(const std::string& source, std::string& output);
std::string worker_status();
std::string analyze_source_fast(const std::string& source);
std::string analyze_source_deep(const std::string& source);
std::string analyze_source_auto(const std::string& source);
std::string get_tool_state_response();
std::string script_status_response();
std::string set_tool_state_response(const std::string& body);
void rotate_log_if_needed(const char* path);
std::string detect_running_ides_json();


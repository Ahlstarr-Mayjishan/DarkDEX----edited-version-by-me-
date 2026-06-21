#include "Toolchain.h"
#include "Index.h"
#include <tlhelp32.h>

std::string g_tool_state_json = "{\"ok\":true,\"tools\":{},\"updatedAt\":0}";
std::mutex g_tool_state_mutex;
std::mutex g_log_mutex;

size_t file_size_or_zero(const char* path) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) return 0;
    std::streampos size = file.tellg();
    if (size <= 0) return 0;
    return static_cast<size_t>(size);
}

bool file_exists(const std::string& path) {
    DWORD attrs = GetFileAttributesA(path.c_str());
    return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
}

std::string read_text_file(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) return "";
    std::stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

std::string temp_file_path(const char* prefix) {
    char temp_dir[MAX_PATH + 1];
    char temp_file[MAX_PATH + 1];
    DWORD len = GetTempPathA(MAX_PATH, temp_dir);
    if (len == 0 || len > MAX_PATH) return "";
    if (GetTempFileNameA(temp_dir, prefix, 0, temp_file) == 0) return "";
    return std::string(temp_file);
}

std::string shell_quote(const std::string& path) {
    std::string out = "\"";
    for (char c : path) {
        if (c == '"') out += "\\\"";
        else out += c;
    }
    out += "\"";
    return out;
}

bool run_command_with_input(const std::string& command, const std::string& input, std::string& output) {
    std::string input_path = temp_file_path("dpp");
    std::string output_path = temp_file_path("dpp");
    if (input_path.empty() || output_path.empty()) return false;

    {
        std::ofstream input_file(input_path, std::ios::binary);
        if (!input_file.is_open()) return false;
        input_file.write(input.data(), static_cast<std::streamsize>(input.size()));
    }

    std::string full_command = command + " < " + shell_quote(input_path) + " > " + shell_quote(output_path);
    if (!full_command.empty() && full_command.front() == '"') {
        full_command = "\"" + full_command + "\"";
    }
    int code = std::system(full_command.c_str());
    output = read_text_file(output_path);

    std::remove(input_path.c_str());
    std::remove(output_path.c_str());
    return code == 0 && !output.empty();
}

std::string resolve_worker_path(const std::string& relative_path) {
    std::string parent_path = "../HelperWorkers/" + relative_path;
    if (file_exists(parent_path)) return parent_path;

    std::string root_path = "HelperWorkers/" + relative_path;
    if (file_exists(root_path)) return root_path;
    return "";
}

bool command_available(const char* command) {
    char resolved[MAX_PATH + 1];
    return SearchPathA(NULL, command, ".exe", MAX_PATH, resolved, NULL) > 0;
}

std::string resolve_toolchain_setup_path() {
    const char* candidates[] = {
        "DEX_Language_Manager.exe",
        "../HelperServer/DEX_Language_Manager.exe",
        "HelperServer/DEX_Language_Manager.exe"
    };
    for (const char* candidate : candidates) {
        if (file_exists(candidate)) return candidate;
    }
    return "";
}

std::string toolchain_status() {
    bool python = command_available("python") || command_available("py");
    bool cargo = command_available("cargo");
    bool compiler = command_available("g++");
    bool winget = command_available("winget");
    bool rust_binary = !resolve_worker_path("rust_source_analyzer/target/release/rust_source_analyzer.exe").empty();
    bool setup = !resolve_toolchain_setup_path().empty();

    std::stringstream json;
    json << "{\"ok\":true,\"runtimeReady\":true,\"tools\":{";
    json << "\"python\":{\"available\":" << (python ? "true" : "false") << ",\"purpose\":\"Deep source analysis and Luau bundle builds\"},";
    json << "\"cargo\":{\"available\":" << (cargo ? "true" : "false") << ",\"purpose\":\"Build and update the Rust fast analyzer\"},";
    json << "\"gpp\":{\"available\":" << (compiler ? "true" : "false") << ",\"purpose\":\"Rebuild DEX_Helper.exe and setup utilities\"},";
    json << "\"winget\":{\"available\":" << (winget ? "true" : "false") << ",\"purpose\":\"Install or upgrade supported toolchains\"},";
    json << "\"rustWorker\":{\"available\":" << (rust_binary ? "true" : "false") << ",\"purpose\":\"Fast analysis for large source payloads\"}";
    json << "},\"setupAvailable\":" << (setup ? "true" : "false")
         << ",\"note\":\"The prebuilt C++ helper runs without build toolchains.\"}";
    return json.str();
}

std::string open_toolchain_setup() {
    std::string setup_path = resolve_toolchain_setup_path();
    if (setup_path.empty()) {
        return "{\"ok\":false,\"error\":\"DEX_Language_Manager.exe was not found\"}";
    }

    HINSTANCE result = ShellExecuteA(NULL, "open", setup_path.c_str(), NULL, NULL, SW_SHOWNORMAL);
    if (reinterpret_cast<INT_PTR>(result) <= 32) {
        return "{\"ok\":false,\"error\":\"Windows could not launch the toolchain setup\"}";
    }
    return "{\"ok\":true}";
}

bool run_python_analyzer(const std::string& source, std::string& output) {
    std::string worker_path = resolve_worker_path("python/deep_source_analyzer.py");
    if (worker_path.empty()) return false;

    std::string command = "python " + shell_quote(worker_path);
    if (run_command_with_input(command, source, output)) return true;

    command = "py -3 " + shell_quote(worker_path);
    return run_command_with_input(command, source, output);
}

bool run_rust_analyzer(const std::string& source, std::string& output) {
    std::string worker_path = resolve_worker_path("rust_source_analyzer/target/release/rust_source_analyzer.exe");
    if (worker_path.empty()) return false;
    return run_command_with_input(shell_quote(worker_path), source, output);
}

std::string worker_status() {
    bool python_source = !resolve_worker_path("python/deep_source_analyzer.py").empty();
    bool python_runtime = command_available("python") || command_available("py");
    bool python_worker = python_source && python_runtime;
    bool rust_source = !resolve_worker_path("rust_source_analyzer/Cargo.toml").empty();
    bool rust_binary = !resolve_worker_path("rust_source_analyzer/target/release/rust_source_analyzer.exe").empty();

    std::stringstream json;
    json << "{\"ok\":true,\"autoThresholdBytes\":262144,\"roles\":[";
    json << "{\"id\":\"cxx_core\",\"language\":\"C++\",\"ready\":true,\"priority\":3,\"role\":\"HTTP routing, cache, source index, dashboard, decompiler proxy, final fallback\"},";
    json << "{\"id\":\"python_deep_analysis\",\"language\":\"Python\",\"ready\":" << (python_worker ? "true" : "false") << ",\"sourceAvailable\":" << (python_source ? "true" : "false") << ",\"runtimeAvailable\":" << (python_runtime ? "true" : "false") << ",\"priority\":1,\"role\":\"Deep summaries, beginner-facing hints, recommendations, JSON shaping\"},";
    json << "{\"id\":\"rust_source_analyzer\",\"language\":\"Rust\",\"ready\":" << (rust_binary ? "true" : "false") << ",\"sourceAvailable\":" << (rust_source ? "true" : "false") << ",\"priority\":2,\"role\":\"High-throughput lexical analysis for large source payloads\"}";
    json << "],\"routes\":{\"fast\":\"Rust -> C++\",\"deep\":\"Python -> Rust -> C++\",\"auto\":\"Python below 256 KB; Rust at or above 256 KB; C++ fallback\"}}";
    return json.str();
}

std::string analyze_source_fast(const std::string& source) {
    std::string output;
    if (run_rust_analyzer(source, output)) return output;
    return analyze_source(source);
}

std::string analyze_source_deep(const std::string& source) {
    std::string output;
    if (run_python_analyzer(source, output)) return output;
    if (run_rust_analyzer(source, output)) return output;
    return analyze_source(source);
}

std::string analyze_source_auto(const std::string& source) {
    constexpr size_t RUST_AUTO_THRESHOLD = 256 * 1024;
    std::string output;

    if (source.size() >= RUST_AUTO_THRESHOLD) {
        if (run_rust_analyzer(source, output)) return output;
        if (run_python_analyzer(source, output)) return output;
    } else {
        if (run_python_analyzer(source, output)) return output;
        if (run_rust_analyzer(source, output)) return output;
    }
    return analyze_source(source);
}

std::string get_tool_state_response() {
    std::lock_guard<std::mutex> lock(g_tool_state_mutex);
    return g_tool_state_json;
}

std::string script_status_response() {
    const char* local_path = "DEX++_compiled.luau";
    const char* parent_path = "../DEX++_compiled.luau";
    size_t size = file_size_or_zero(local_path);
    std::string resolved = local_path;
    if (size == 0) {
        size = file_size_or_zero(parent_path);
        resolved = parent_path;
    }
    std::stringstream json;
    json << "{\"ok\":" << (size > 0 ? "true" : "false")
         << ",\"file\":\"" << escape_json(resolved) << "\""
         << ",\"bytes\":" << size
         << ",\"url\":\"/script\"}";
    return json.str();
}

std::string set_tool_state_response(const std::string& body) {
    std::string trimmed = trim_copy(body);
    if (trimmed.empty()) {
        return "{\"ok\":false,\"error\":\"empty tool state\"}";
    }
    if (trimmed.size() > 262144) {
        return "{\"ok\":false,\"error\":\"tool state too large\"}";
    }
    if (trimmed.front() != '{') {
        return "{\"ok\":false,\"error\":\"tool state must be json object\"}";
    }
    {
        std::lock_guard<std::mutex> lock(g_tool_state_mutex);
        g_tool_state_json = trimmed;
    }
    return "{\"ok\":true}";
}

void rotate_log_if_needed(const char* path) {
    if (file_size_or_zero(path) < MAX_LOG_FILE_SIZE) return;
    std::string old_path = std::string(path) + ".old";
    std::remove(old_path.c_str());
    std::rename(path, old_path.c_str());
}

std::string detect_running_ides_json() {
    std::vector<std::string> ides = {
        "RobloxStudio.exe", "Code.exe", "Cursor.exe", "Windsurf.exe",
        "vscodium.exe", "sublime_text.exe", "notepad++.exe", "clion64.exe", "idea64.exe", "Codex.exe",
        "Antigravity IDE.exe", "RobloxPlayerBeta.exe", "pycharm64.exe", "webstorm64.exe", "rider64.exe",
        "devenv.exe", "eclipse.exe", "nvim-qt.exe"
    };
    std::vector<std::string> found;
    
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32W pe32;
        pe32.dwSize = sizeof(PROCESSENTRY32W);
        if (Process32FirstW(hSnapshot, &pe32)) {
            do {
                std::string procName = to_string(pe32.szExeFile);
                for (auto& c : procName) c = tolower(c);
                
                for (const auto& ide : ides) {
                    std::string lowerIde = ide;
                    for (auto& c : lowerIde) c = tolower(c);
                    
                    if (procName == lowerIde) {
                        std::string cleanName = ide;
                        if (cleanName.size() > 4) {
                            cleanName = cleanName.substr(0, cleanName.size() - 4);
                        }
                        if (cleanName == "Code") cleanName = "VS Code";
                        else if (cleanName == "RobloxStudio") cleanName = "Roblox Studio";
                        else if (cleanName == "clion64") cleanName = "CLion";
                        else if (cleanName == "idea64") cleanName = "IntelliJ IDEA";
                        else if (cleanName == "sublime_text") cleanName = "Sublime Text";
                        else if (cleanName == "RobloxPlayerBeta") cleanName = "Roblox Player";
                        else if (cleanName == "pycharm64") cleanName = "PyCharm";
                        else if (cleanName == "webstorm64") cleanName = "WebStorm";
                        else if (cleanName == "rider64") cleanName = "Rider";
                        else if (cleanName == "devenv") cleanName = "Visual Studio";
                        else if (cleanName == "nvim-qt") cleanName = "Neovim";
                        
                        if (!cleanName.empty()) {
                            cleanName[0] = toupper(cleanName[0]);
                        }
                        
                        if (std::find(found.begin(), found.end(), cleanName) == found.end()) {
                            found.push_back(cleanName);
                        }
                    }
                }
            } while (Process32NextW(hSnapshot, &pe32));
        }
        CloseHandle(hSnapshot);
    }
    
    std::stringstream json;
    json << "[";
    for (size_t i = 0; i < found.size(); ++i) {
        json << "\"" << escape_json(found[i]) << "\"";
        if (i + 1 < found.size()) json << ",";
    }
    json << "]";
    return json.str();
}


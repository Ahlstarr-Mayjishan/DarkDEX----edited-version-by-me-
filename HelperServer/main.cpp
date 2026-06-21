#include "Common.h"
#include "Dashboard.h"
#include "Auth.h"
#include "Index.h"
#include "Win32App.h"
#include "Toolchain.h"
#include "Decompiler.h"

// Link with ws2_32.lib
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "wininet.lib")

std::atomic<int> g_active_clients{0};
ULONGLONG g_last_mcp_time = 0;

// Lightweight SHA-1 implementation
namespace sha1 {
    inline unsigned int rol(unsigned int value, unsigned int bits) {
        return (value << bits) | (value >> (32 - bits));
    }
    inline void block(unsigned int* state, const unsigned char* block) {
        unsigned int w[80];
        for (int i = 0; i < 16; i++) {
            w[i] = (block[i * 4] << 24) | (block[i * 4 + 1] << 16) | (block[i * 4 + 2] << 8) | (block[i * 4 + 3]);
        }
        for (int i = 16; i < 80; i++) {
            w[i] = rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
        }
        unsigned int a = state[0], b = state[1], c = state[2], d = state[3], e = state[4];
        for (int i = 0; i < 80; i++) {
            unsigned int f, k;
            if (i < 20) {
                f = (b & c) | ((~b) & d);
                k = 0x5A827999;
            } else if (i < 40) {
                f = b ^ c ^ d;
                k = 0x6ED9EBA1;
            } else if (i < 60) {
                f = (b & c) | (b & d) | (c & d);
                k = 0x8F1BBCDC;
            } else {
                f = b ^ c ^ d;
                k = 0xCA62C1D6;
            }
            unsigned int temp = rol(a, 5) + f + e + k + w[i];
            e = d;
            d = c;
            c = rol(b, 30);
            b = a;
            a = temp;
        }
        state[0] += a; state[1] += b; state[2] += c; state[3] += d; state[4] += e;
    }
    inline std::string hash(const std::string& input) {
        unsigned int state[5] = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0};
        unsigned long long bit_len = input.size() * 8;
        std::vector<unsigned char> data(input.begin(), input.end());
        data.push_back(0x80);
        while ((data.size() + 8) % 64 != 0) {
            data.push_back(0x00);
        }
        for (int i = 7; i >= 0; i--) {
            data.push_back(static_cast<unsigned char>((bit_len >> (i * 8)) & 0xFF));
        }
        for (size_t i = 0; i < data.size(); i += 64) {
            block(state, &data[i]);
        }
        std::string result;
        result.resize(20);
        for (int i = 0; i < 5; i++) {
            result[i * 4] = static_cast<char>((state[i] >> 24) & 0xFF);
            result[i * 4 + 1] = static_cast<char>((state[i] >> 16) & 0xFF);
            result[i * 4 + 2] = static_cast<char>((state[i] >> 8) & 0xFF);
            result[i * 4 + 3] = static_cast<char>(state[i] & 0xFF);
        }
        return result;
    }
}

// Lightweight Base64 implementation
namespace base64 {
    inline std::string encode(const std::string& input) {
        static const char alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        std::string result;
        result.reserve((input.size() + 2) / 3 * 4);
        int val = 0, valb = -6;
        for (unsigned char c : input) {
            val = (val << 8) + c;
            valb += 8;
            while (valb >= 0) {
                result.push_back(alphabet[(val >> valb) & 0x3F]);
                valb -= 6;
            }
        }
        if (valb > -6) {
            result.push_back(alphabet[((val << 8) >> (valb + 8)) & 0x3F]);
        }
        while (result.size() % 4 != 0) {
            result.push_back('=');
        }
        return result;
    }
}

// Send unmasked WebSocket text frame
inline bool send_ws_text_frame(SOCKET client_socket, const std::string& payload) {
    std::vector<char> frame;
    frame.push_back(static_cast<char>(0x81)); // FIN + Text frame opcode
    
    size_t len = payload.size();
    if (len <= 125) {
        frame.push_back(static_cast<char>(len));
    } else if (len <= 65535) {
        frame.push_back(static_cast<char>(126));
        frame.push_back(static_cast<char>((len >> 8) & 0xFF));
        frame.push_back(static_cast<char>(len & 0xFF));
    } else {
        frame.push_back(static_cast<char>(127));
        for (int i = 7; i >= 0; i--) {
            frame.push_back(static_cast<char>((len >> (i * 8)) & 0xFF));
        }
    }
    
    frame.insert(frame.end(), payload.begin(), payload.end());
    
    size_t total_sent = 0;
    while (total_sent < frame.size()) {
        int sent = send(client_socket, frame.data() + total_sent, static_cast<int>(frame.size() - total_sent), 0);
        if (sent == SOCKET_ERROR || sent == 0) {
            return false;
        }
        total_sent += sent;
    }
    return true;
}

// Send HTTP response helper
void send_response(SOCKET client_socket, int status_code, const std::string& status_text, const std::string& body, const std::string& content_type = "text/plain") {
    std::stringstream response;
    response << "HTTP/1.1 " << status_code << " " << status_text << "\r\n"
             << "Content-Type: " << content_type << "\r\n"
             << "Content-Length: " << body.length() << "\r\n"
             << "Access-Control-Allow-Origin: *\r\n"
             << "Access-Control-Allow-Headers: *\r\n"
             << "Connection: close\r\n\r\n"
             << body;

    std::string response_str = response.str();
    send(client_socket, response_str.c_str(), static_cast<int>(response_str.length()), 0);
}

void close_client(SOCKET client_socket) {
    shutdown(client_socket, SD_SEND);
    closesocket(client_socket);
}

// Handle WebSocket client upgrades and updates
inline void handle_ws_client(SOCKET ClientSocket, const std::string& request_headers) {
    size_t key_pos = request_headers.find("Sec-WebSocket-Key:");
    if (key_pos == std::string::npos) {
        send_response(ClientSocket, 400, "Bad Request", "Missing Sec-WebSocket-Key");
        close_client(ClientSocket);
        return;
    }
    size_t value_start = key_pos + 18;
    while (value_start < request_headers.size() && std::isspace(static_cast<unsigned char>(request_headers[value_start]))) {
        value_start++;
    }
    size_t value_end = request_headers.find("\r\n", value_start);
    if (value_end == std::string::npos) value_end = request_headers.size();
    std::string ws_key = request_headers.substr(value_start, value_end - value_start);
    while (!ws_key.empty() && std::isspace(static_cast<unsigned char>(ws_key.back()))) {
        ws_key.pop_back();
    }
    
    std::string concat = ws_key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    std::string sha1_hash = sha1::hash(concat);
    std::string accept_key = base64::encode(sha1_hash);
    
    std::stringstream response;
    response << "HTTP/1.1 101 Switching Protocols\r\n"
             << "Upgrade: websocket\r\n"
             << "Connection: Upgrade\r\n"
             << "Sec-WebSocket-Accept: " << accept_key << "\r\n\r\n";
    std::string hand_str = response.str();
    send(ClientSocket, hand_str.data(), static_cast<int>(hand_str.size()), 0);
    
    unsigned long long client_time = 0;
    FILETIME current_ft;
    GetSystemTimeAsFileTime(&current_ft);
    ULARGE_INTEGER current_ui;
    current_ui.LowPart = current_ft.dwLowDateTime;
    current_ui.HighPart = current_ft.dwHighDateTime;
    client_time = current_ui.QuadPart;
    
    while (!g_shutdown_requested.load()) {
        fd_set read_fds;
        FD_ZERO(&read_fds);
        FD_SET(ClientSocket, &read_fds);
        
        timeval timeout;
        timeout.tv_sec = 0;
        timeout.tv_usec = 500000; // 500ms
        
        int sel = select(0, &read_fds, NULL, NULL, &timeout);
        if (sel == SOCKET_ERROR) {
            break;
        }
        
        if (sel > 0) {
            char peek_buf[2];
            int rec = recv(ClientSocket, peek_buf, 2, MSG_PEEK);
            if (rec <= 0) {
                break;
            }
            
            unsigned char first_byte = peek_buf[0];
            unsigned char opcode = first_byte & 0x0F;
            if (opcode == 0x08) {
                break;
            }
            
            char discard_buf[1024];
            int bytes_discarded = recv(ClientSocket, discard_buf, sizeof(discard_buf), 0);
            if (bytes_discarded <= 0) {
                break;
            }
        }
        
        CreateDirectoryW(L"workspace_sync", NULL);
        std::vector<FileInfo> files;
        scan_directory_recursive(L"workspace_sync", L"", files);
        
        bool has_changes = false;
        unsigned long long latest_time = client_time;
        for (const auto& file : files) {
            if (file.last_write_time > client_time) {
                has_changes = true;
                if (file.last_write_time > latest_time) {
                    latest_time = file.last_write_time;
                }
            }
        }
        
        if (has_changes) {
            std::stringstream json;
            json << "{\"ok\":true,\"files\":[";
            bool first_file = true;
            for (const auto& file : files) {
                if (file.last_write_time > client_time) {
                    std::wstring full_w = L"workspace_sync\\" + to_wstring(file.relative_path);
                    std::ifstream in(full_w.c_str(), std::ios::binary);
                    std::string src = "";
                    if (in.is_open()) {
                        std::stringstream buffer;
                        buffer << in.rdbuf();
                        src = buffer.str();
                        in.close();
                    }
                    
                    std::string script_path = "";
                    std::string rel = file.relative_path;
                    if (rel.size() > 5 && rel.substr(rel.size() - 5) == ".luau") {
                        rel = rel.substr(0, rel.size() - 5);
                    }
                    for (char c : rel) {
                        if (c == '\\') {
                            script_path += '.';
                        } else {
                            script_path += c;
                        }
                    }
                    
                    if (!first_file) json << ",";
                    first_file = false;
                    
                    json << "{\"path\":\"" << escape_json(script_path) << "\","
                         << "\"source\":\"" << escape_json(src) << "\","
                         << "\"timestamp\":" << file.last_write_time << "}";
                }
            }
            
            FILETIME ft;
            GetSystemTimeAsFileTime(&ft);
            ULARGE_INTEGER ui;
            ui.LowPart = ft.dwLowDateTime;
            ui.HighPart = ft.dwHighDateTime;
            latest_time = std::max(latest_time, ui.QuadPart);
            
            json << "],\"timestamp\":" << latest_time << "}";
            
            if (!send_ws_text_frame(ClientSocket, json.str())) {
                break;
            }
            client_time = latest_time;
        }
    }
    
    close_client(ClientSocket);
}

size_t find_header_case_insensitive(const std::string& request, const std::string& header_name) {
    std::string lower_request = lower_copy(request);
    std::string lower_header = lower_copy(header_name);
    return lower_request.find(lower_header);
}

bool parse_content_length(const std::string& request, size_t& content_length, std::string& error) {
    content_length = 0;
    size_t cl_pos = find_header_case_insensitive(request, "Content-Length:");
    if (cl_pos == std::string::npos) return true;

    size_t cl_end = request.find("\r\n", cl_pos);
    if (cl_end == std::string::npos) cl_end = request.size();

    std::string cl_str = trim_copy(request.substr(cl_pos + 15, cl_end - (cl_pos + 15)));
    if (cl_str.empty()) {
        error = "empty Content-Length header";
        return false;
    }

    try {
        size_t parsed_chars = 0;
        unsigned long long parsed = std::stoull(cl_str, &parsed_chars, 10);
        if (parsed_chars != cl_str.size()) {
            error = "invalid Content-Length value";
            return false;
        }
        if (parsed > MAX_BODY_SIZE) {
            error = "request body too large";
            return false;
        }
        content_length = static_cast<size_t>(parsed);
        return true;
    } catch (...) {
        error = "invalid Content-Length value";
        return false;
    }
}

void handle_client(SOCKET ClientSocket) {
    std::vector<char> recvbuf(BUFFER_SIZE);
    std::string request_data = "";
    int bytes_received = recv(ClientSocket, recvbuf.data(), BUFFER_SIZE - 1, 0);

    if (bytes_received > 0) {
        recvbuf[bytes_received] = '\0';
        request_data.append(recvbuf.data(), bytes_received);

        size_t header_end = request_data.find("\r\n\r\n");
        while (header_end == std::string::npos && request_data.size() < MAX_HEADER_SIZE) {
            int extra = recv(ClientSocket, recvbuf.data(), BUFFER_SIZE - 1, 0);
            if (extra <= 0) break;
            recvbuf[extra] = '\0';
            request_data.append(recvbuf.data(), extra);
            header_end = request_data.find("\r\n\r\n");
        }

        if (header_end == std::string::npos) {
            send_response(ClientSocket, 400, "Bad Request", "Malformed HTTP request headers.");
            close_client(ClientSocket);
            return;
        }
        if (header_end > MAX_HEADER_SIZE) {
            send_response(ClientSocket, 413, "Payload Too Large", "HTTP headers are too large.");
            close_client(ClientSocket);
            return;
        }

        if (request_data.find("X-MCP-Client:") != std::string::npos) {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_last_mcp_time = GetTickCount64();
        }

        std::stringstream ss(request_data.substr(0, header_end));
        std::string method, path, protocol;
        ss >> method >> path >> protocol;

        std::string body = request_data.substr(header_end + 4);
        size_t content_len = 0;
        std::string content_error;
        if (!parse_content_length(request_data.substr(0, header_end), content_len, content_error)) {
            send_response(ClientSocket, 400, "Bad Request", content_error);
            close_client(ClientSocket);
            return;
        }
        if (body.size() > MAX_BODY_SIZE) {
            send_response(ClientSocket, 413, "Payload Too Large", "Request body is too large.");
            close_client(ClientSocket);
            return;
        }
        while (body.size() < content_len) {
            int extra = recv(ClientSocket, recvbuf.data(), BUFFER_SIZE - 1, 0);
            if (extra <= 0) break;
            recvbuf[extra] = '\0';
            body.append(recvbuf.data(), extra);
        }
        if (body.size() < content_len) {
            send_response(ClientSocket, 400, "Bad Request", "Incomplete request body.");
            close_client(ClientSocket);
            return;
        }

        if (method == "OPTIONS") {
            send_response(ClientSocket, 204, "No Content", "");
        } else if (path == "/sync-ws" && method == "GET") {
            handle_ws_client(ClientSocket, request_data);
            return;
        } else if ((path == "/" || path == "/app") && method == "GET") {
            send_response(ClientSocket, 200, "OK", helper_dashboard_html(), "text/html; charset=utf-8");
        } else if (path == "/status" && method == "GET") {
            send_response(ClientSocket, 200, "OK", "DEX++ C++ Helper Server Active");
        } else if (path == "/worker-status" && method == "GET") {
            send_response(ClientSocket, 200, "OK", worker_status(), "application/json");
        } else if (path == "/toolchain-status" && method == "GET") {
            send_response(ClientSocket, 200, "OK", toolchain_status(), "application/json");
        } else if (path == "/open-toolchain-setup" && method == "POST") {
            send_response(ClientSocket, 200, "OK", open_toolchain_setup(), "application/json");
        } else if (path == "/script-status" && method == "GET") {
            send_response(ClientSocket, 200, "OK", script_status_response(), "application/json");
        } else if (path == "/script" && method == "GET") {
            std::ifstream script_file("DEX++_compiled.luau");
            if (!script_file.is_open()) {
                script_file.open("../DEX++_compiled.luau");
            }
            if (script_file.is_open()) {
                std::stringstream buffer;
                buffer << script_file.rdbuf();
                script_file.close();
                send_response(ClientSocket, 200, "OK", buffer.str());
            } else {
                send_response(ClientSocket, 404, "Not Found", "-- Error: DEX++_compiled.luau not found on server.");
            }
        } else if (path == "/log" && method == "POST") {
            if (body.size() > MAX_LOG_BODY_SIZE) {
                send_response(ClientSocket, 413, "Payload Too Large", "Log entry is too large.");
                close_client(ClientSocket);
                return;
            }
            std::lock_guard<std::mutex> lock(g_log_mutex);
            rotate_log_if_needed("dex_server_logs.txt");
            std::ofstream log_file("dex_server_logs.txt", std::ios::app);
            if (log_file.is_open()) {
                log_file << body << std::endl;
                log_file.close();
            }
            send_response(ClientSocket, 200, "OK", "Logged");
        } else if ((path == "/normalize-source" || path == "/deobfuscate") && method == "POST") {
            send_response(ClientSocket, 200, "OK", normalize_source(body));
        } else if (path == "/analyze-source" && method == "POST") {
            send_response(ClientSocket, 200, "OK", analyze_source(body), "application/json");
        } else if (path == "/analyze-source-fast" && method == "POST") {
            send_response(ClientSocket, 200, "OK", analyze_source_fast(body), "application/json");
        } else if (path == "/analyze-source-deep" && method == "POST") {
            send_response(ClientSocket, 200, "OK", analyze_source_deep(body), "application/json");
        } else if (path == "/analyze-source-auto" && method == "POST") {
            send_response(ClientSocket, 200, "OK", analyze_source_auto(body), "application/json");
        } else if (path == "/analyze-remotes" && method == "POST") {
            send_response(ClientSocket, 200, "OK", analyze_remote_logs(body), "application/json");
        } else if (path == "/index-source" && method == "POST") {
            send_response(ClientSocket, 200, "OK", index_source_payload(body));
        } else if (path == "/search-source" && method == "POST") {
            send_response(ClientSocket, 200, "OK", search_index(body));
        } else if (path == "/index-entry" && method == "POST") {
            send_response(ClientSocket, 200, "OK", index_entry(body), "application/json");
        } else if (path == "/index-status" && method == "GET") {
            send_response(ClientSocket, 200, "OK", index_status());
        } else if (path == "/tool-state" && method == "GET") {
            send_response(ClientSocket, 200, "OK", get_tool_state_response(), "application/json");
        } else if (path == "/tool-state" && method == "POST") {
            send_response(ClientSocket, 200, "OK", set_tool_state_response(body), "application/json");
        } else if (path == "/index-save" && method == "POST") {
            send_response(ClientSocket, 200, "OK", save_index_response());
        } else if (path == "/index-load" && method == "POST") {
            send_response(ClientSocket, 200, "OK", load_index_response());
        } else if (path == "/index-clear" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_script_index_mutex);
            g_script_index.clear();
            bool saved = save_index_locked();
            send_response(ClientSocket, 200, "OK", saved ? "{\"ok\":true,\"total\":0,\"persisted\":true}" : "{\"ok\":true,\"total\":0,\"persisted\":false}");
        } else if (path == "/api/roblox/login" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string res = get_roblox_profile_response(body);
            if (res.find("\"ok\":true") != std::string::npos) {
                g_roblox_cookie = body;
                save_auth_credentials();
            }
            send_response(ClientSocket, 200, "OK", res, "application/json");
        } else if (path == "/api/roblox/logout" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_roblox_cookie = "";
            save_auth_credentials();
            send_response(ClientSocket, 200, "OK", "{\"ok\":true}", "application/json");
        } else if (path == "/api/roblox/profile" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            send_response(ClientSocket, 200, "OK", get_roblox_profile_response(g_roblox_cookie), "application/json");
        } else if (path == "/api/github/login" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string res = get_github_profile_response(body);
            if (res.find("\"ok\":true") != std::string::npos) {
                g_github_token = body;
                g_github_oauth_token = "";
                save_auth_credentials();
            }
            send_response(ClientSocket, 200, "OK", res, "application/json");
        } else if (path == "/api/github/logout" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_github_token = "";
            g_github_oauth_token = "";
            save_auth_credentials();
            send_response(ClientSocket, 200, "OK", "{\"ok\":true}", "application/json");
        } else if (path == "/api/github/profile" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            if (!g_github_oauth_token.empty()) {
                send_response(ClientSocket, 200, "OK", get_github_profile_response(g_github_oauth_token), "application/json");
            } else {
                send_response(ClientSocket, 200, "OK", get_github_profile_response(g_github_token), "application/json");
            }
        } else if (path == "/api/google/login" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string res = verify_gemini_api_key(body);
            if (res.find("\"ok\":true") != std::string::npos) {
                g_google_api_key = body;
                g_google_oauth_token = "";
                save_auth_credentials();
            }
            send_response(ClientSocket, 200, "OK", res, "application/json");
        } else if (path == "/api/google/logout" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_google_api_key = "";
            g_google_oauth_token = "";
            save_auth_credentials();
            send_response(ClientSocket, 200, "OK", "{\"ok\":true}", "application/json");
        } else if (path == "/api/google/profile" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            if (!g_google_oauth_token.empty()) {
                send_response(ClientSocket, 200, "OK", get_google_profile_response(g_google_oauth_token), "application/json");
            } else {
                send_response(ClientSocket, 200, "OK", verify_gemini_api_key(g_google_api_key), "application/json");
            }
        } else if (path == "/api/openai/login" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string res = get_openai_profile_response(body);
            if (res.find("\"ok\":true") != std::string::npos) {
                g_openai_api_key = body;
                save_auth_credentials();
            }
            send_response(ClientSocket, 200, "OK", res, "application/json");
        } else if (path == "/api/openai/logout" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_openai_api_key = "";
            save_auth_credentials();
            send_response(ClientSocket, 200, "OK", "{\"ok\":true}", "application/json");
        } else if (path == "/api/openai/profile" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            send_response(ClientSocket, 200, "OK", get_openai_profile_response(g_openai_api_key), "application/json");
        } else if (path == "/api/accounts" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            send_response(ClientSocket, 200, "OK", g_accounts_json, "application/json");
            return;
        } else if (path == "/api/detect-ides" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            bool mcp_active = (g_last_mcp_time > 0 && (GetTickCount64() - g_last_mcp_time) < 30000);
            std::stringstream json;
            json << "{\"ok\":true,\"ides\":" << detect_running_ides_json() << ",\"mcpActive\":" << (mcp_active ? "true" : "false") << "}";
            send_response(ClientSocket, 200, "OK", json.str(), "application/json");
            return;
        } else if (path == "/api/accounts" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_accounts_json = body;
            save_auth_credentials();
            send_response(ClientSocket, 200, "OK", "{\"ok\":true}", "application/json");
            return;
        } else if (path == "/api/auth/active-token" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string provider = extract_json_field(body, "provider");
            std::string token = extract_json_field(body, "token");
            std::string type = extract_json_field(body, "type");
            
            if (provider == "roblox") {
                g_roblox_cookie = token;
            } else if (provider == "github") {
                if (type == "oauth") {
                    g_github_oauth_token = token;
                    g_github_token = "";
                } else {
                    g_github_token = token;
                    g_github_oauth_token = "";
                }
            } else if (provider == "google") {
                if (type == "oauth") {
                    g_google_oauth_token = token;
                    g_google_api_key = "";
                } else {
                    g_google_api_key = token;
                    g_google_oauth_token = "";
                }
            } else if (provider == "openai") {
                g_openai_api_key = token;
            }
            save_auth_credentials();
            send_response(ClientSocket, 200, "OK", "{\"ok\":true}", "application/json");
            return;
        } else if (path == "/api/auth/oauth-config" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_google_client_id = extract_json_field(body, "googleClientId");
            g_google_client_secret = extract_json_field(body, "googleClientSecret");
            g_github_client_id = extract_json_field(body, "githubClientId");
            g_github_client_secret = extract_json_field(body, "githubClientSecret");
            save_auth_credentials();
            send_response(ClientSocket, 200, "OK", "{\"ok\":true}", "application/json");
        } else if (path == "/api/auth/oauth-config" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::stringstream json;
            json << "{\"googleClientId\":\"" << escape_json(g_google_client_id) << "\","
                 << "\"googleClientSecret\":\"" << escape_json(g_google_client_secret) << "\","
                 << "\"githubClientId\":\"" << escape_json(g_github_client_id) << "\","
                 << "\"githubClientSecret\":\"" << escape_json(g_github_client_secret) << "\"}";
            send_response(ClientSocket, 200, "OK", json.str(), "application/json");
        } else if (path == "/api/auth/google/login" && method == "GET") {
            if (g_google_client_id.empty()) {
                send_response(ClientSocket, 400, "Bad Request", "{\"ok\":false,\"error\":\"Google OAuth is not configured in Developer settings.\"}");
                return;
            }
            std::stringstream redirect;
            redirect << "https://accounts.google.com/o/oauth2/v2/auth?"
                     << "client_id=" << g_google_client_id
                     << "&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fapi%2Fauth%2Fgoogle%2Fcallback"
                     << "&response_type=code"
                     << "&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgenerative-language%20email%20profile"
                     << "&access_type=offline"
                     << "&prompt=consent";
            
            std::stringstream response;
            response << "HTTP/1.1 302 Found\r\n"
                     << "Location: " << redirect.str() << "\r\n"
                     << "Content-Length: 0\r\n\r\n";
            send(ClientSocket, response.str().data(), static_cast<int>(response.str().size()), 0);
            return;
        } else if (path == "/api/auth/google/callback" && method == "GET") {
            size_t code_pos = request_data.find("code=");
            if (code_pos == std::string::npos) {
                send_response(ClientSocket, 400, "Bad Request", "Authentication failed: no code returned.");
                return;
            }
            size_t amp_pos = request_data.find("&", code_pos);
            size_t space_pos = request_data.find(" ", code_pos);
            size_t end_pos = (amp_pos != std::string::npos && amp_pos < space_pos) ? amp_pos : space_pos;
            std::string auth_code = request_data.substr(code_pos + 5, end_pos - (code_pos + 5));
            
            std::string body = "code=" + auth_code +
                               "&client_id=" + g_google_client_id +
                               "&client_secret=" + g_google_client_secret +
                               "&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fapi%2Fauth%2Fgoogle%2Fcallback" +
                               "&grant_type=authorization_code";
                               
            std::string res = http_post_https("oauth2.googleapis.com", "/token", "Content-Type: application/x-www-form-urlencoded\r\n", body);
            std::string access_token = extract_json_field(res, "access_token");
            if (access_token.empty()) {
                send_response(ClientSocket, 400, "Bad Request", "Exchange failed: " + res);
                return;
            }
            
            {
                std::lock_guard<std::mutex> lock(g_auth_mutex);
                g_google_oauth_token = access_token;
                g_google_api_key = "";
                save_auth_credentials();
            }
            
            std::string success_html = "<html><head><title>Success</title><style>body{background:#0b0e14;color:#cbd5e1;font-family:sans-serif;text-align:center;padding:50px}h1{color:#52b69a}</style></head><body><h1>Login Successful!</h1><p>Google Account successfully connected to DEX++. You can close this tab now.</p><script>window.close()</script></body></html>";
            send_response(ClientSocket, 200, "OK", success_html, "text/html");
            return;
        } else if (path == "/api/auth/github/login" && method == "GET") {
            if (g_github_client_id.empty()) {
                send_response(ClientSocket, 400, "Bad Request", "{\"ok\":false,\"error\":\"GitHub OAuth is not configured.\"}");
                return;
            }
            std::stringstream redirect;
            redirect << "https://github.com/login/oauth/authorize?"
                     << "client_id=" << g_github_client_id
                     << "&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fapi%2Fauth%2Fgithub%2Fcallback"
                     << "&scope=repo";
            
            std::stringstream response;
            response << "HTTP/1.1 302 Found\r\n"
                     << "Location: " << redirect.str() << "\r\n"
                     << "Content-Length: 0\r\n\r\n";
            send(ClientSocket, response.str().data(), static_cast<int>(response.str().size()), 0);
            return;
        } else if (path == "/api/auth/github/callback" && method == "GET") {
            size_t code_pos = request_data.find("code=");
            if (code_pos == std::string::npos) {
                send_response(ClientSocket, 400, "Bad Request", "Authentication failed: no code returned.");
                return;
            }
            size_t amp_pos = request_data.find("&", code_pos);
            size_t space_pos = request_data.find(" ", code_pos);
            size_t end_pos = (amp_pos != std::string::npos && amp_pos < space_pos) ? amp_pos : space_pos;
            std::string auth_code = request_data.substr(code_pos + 5, end_pos - (code_pos + 5));
            
            std::string body = "client_id=" + g_github_client_id +
                               "&client_secret=" + g_github_client_secret +
                               "&code=" + auth_code +
                               "&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fapi%2Fauth%2Fgithub%2Fcallback";
                               
            std::string res = http_post_https("github.com", "/login/oauth/access_token", "Content-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\n", body);
            std::string access_token = extract_json_field(res, "access_token");
            if (access_token.empty()) {
                send_response(ClientSocket, 400, "Bad Request", "Exchange failed: " + res);
                return;
            }
            
            {
                std::lock_guard<std::mutex> lock(g_auth_mutex);
                g_github_oauth_token = access_token;
                g_github_token = "";
                save_auth_credentials();
            }
            
            std::string success_html = "<html><head><title>Success</title><style>body{background:#0b0e14;color:#cbd5e1;font-family:sans-serif;text-align:center;padding:50px}h1{color:#52b69a}</style></head><body><h1>Login Successful!</h1><p>GitHub Account successfully connected to DEX++. You can close this tab now.</p><script>window.close()</script></body></html>";
            send_response(ClientSocket, 200, "OK", success_html, "text/html");
            return;
        } else if (path == "/api/auth/tokens" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::stringstream json;
            json << "{\"ok\":true,"
                 << "\"googleToken\":\"" << escape_json(!g_google_oauth_token.empty() ? g_google_oauth_token : g_google_api_key) << "\","
                 << "\"googleMethod\":\"" << (!g_google_oauth_token.empty() ? "oauth" : "apikey") << "\","
                 << "\"githubToken\":\"" << escape_json(!g_github_oauth_token.empty() ? g_github_oauth_token : g_github_token) << "\","
                 << "\"githubMethod\":\"" << (!g_github_oauth_token.empty() ? "oauth" : "apikey") << "\","
                 << "\"openaiToken\":\"" << escape_json(g_openai_api_key) << "\","
                 << "\"openaiMethod\":\"apikey\","
                 << "\"robloxCookie\":\"" << escape_json(g_roblox_cookie) << "\"}";
            send_response(ClientSocket, 200, "OK", json.str(), "application/json");
            return;
        } else if (path == "/stop-local-services" && method == "POST") {
            send_response(ClientSocket, 200, "OK", "{\"ok\":true,\"stopping\":[\"DEX_Helper.exe\",\"Decompiler.exe\"]}", "application/json");
            schedule_local_shutdown(false);
        } else if (path == "/clean-local" && method == "POST") {
            send_response(ClientSocket, 200, "OK", "{\"ok\":true,\"cleaning\":[\"dex_helper_index.dat\",\"dex_server_logs.txt\"],\"stopping\":[\"DEX_Helper.exe\",\"Decompiler.exe\"]}", "application/json");
            schedule_local_shutdown(true);
        } else if (path == "/assign-role" && method == "POST") {
            send_response(ClientSocket, 200, "OK", assign_role(body));
        } else if (path == "/decompile" && method == "POST") {
            send_response(ClientSocket, 200, "OK", decompile_bytecode(body));
        } else if (path == "/sync-to-disk" && method == "POST") {
            auto parts = split_header_payload(body, 1);
            if (parts.size() != 2 || parts[0].empty()) {
                send_response(ClientSocket, 400, "Bad Request", "{\"ok\":false,\"error\":\"invalid payload\"}", "application/json");
                close_client(ClientSocket);
                return;
            }
            
            std::string script_path = parts[0];
            std::string source_code = parts[1];
            
            std::string local_rel = "workspace_sync\\";
            for (char c : script_path) {
                if (c == '.') {
                    local_rel += '\\';
                } else {
                    local_rel += c;
                }
            }
            local_rel += ".luau";
            
            std::wstring w_path = to_wstring(local_rel);
            create_directories_for_file(w_path);
            
            std::ofstream out(w_path.c_str(), std::ios::binary | std::ios::trunc);
            if (out.is_open()) {
                out.write(source_code.data(), source_code.size());
                out.close();
                send_response(ClientSocket, 200, "OK", "{\"ok\":true}", "application/json");
            } else {
                send_response(ClientSocket, 500, "Internal Error", "{\"ok\":false,\"error\":\"could not open file for writing\"}", "application/json");
            }
        } else if (path == "/sync-poll" && method == "POST") {
            unsigned long long client_time = 0;
            try {
                client_time = std::stoull(body);
            } catch (...) {
                client_time = 0;
            }
            
            CreateDirectoryW(L"workspace_sync", NULL);
            std::vector<FileInfo> files;
            scan_directory_recursive(L"workspace_sync", L"", files);
            
            std::stringstream json;
            json << "{\"ok\":true,\"files\":[";
            bool first_file = true;
            for (const auto& file : files) {
                if (file.last_write_time > client_time) {
                    std::wstring full_w = L"workspace_sync\\" + to_wstring(file.relative_path);
                    std::ifstream in(full_w.c_str(), std::ios::binary);
                    std::string src = "";
                    if (in.is_open()) {
                        std::stringstream buffer;
                        buffer << in.rdbuf();
                        src = buffer.str();
                        in.close();
                    }
                    
                    std::string script_path = "";
                    std::string rel = file.relative_path;
                    if (rel.size() > 5 && rel.substr(rel.size() - 5) == ".luau") {
                        rel = rel.substr(0, rel.size() - 5);
                    }
                    for (char c : rel) {
                        if (c == '\\') {
                            script_path += '.';
                        } else {
                            script_path += c;
                        }
                    }
                    
                    if (!first_file) json << ",";
                    first_file = false;
                    
                    json << "{\"path\":\"" << escape_json(script_path) << "\","
                         << "\"source\":\"" << escape_json(src) << "\","
                         << "\"timestamp\":" << file.last_write_time << "}";
                }
            }
            
            FILETIME current_ft;
            GetSystemTimeAsFileTime(&current_ft);
            ULARGE_INTEGER current_ui;
            current_ui.LowPart = current_ft.dwLowDateTime;
            current_ui.HighPart = current_ft.dwHighDateTime;
            
            json << "],\"timestamp\":" << current_ui.QuadPart << "}";
            send_response(ClientSocket, 200, "OK", json.str(), "application/json");
        } else {
            send_response(ClientSocket, 404, "Not Found", "404 Route Not Found");
        }
    }

    close_client(ClientSocket);
}

int main() {
    SetConsoleTitleW(L"DEX++ Local Helper");

    HANDLE instance_mutex = CreateMutexW(NULL, FALSE, INSTANCE_MUTEX_NAME);
    if (instance_mutex == NULL) {
        show_startup_notice(L"DEX++ Helper could not create its single-instance lock.", false);
        return 1;
    }
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        show_startup_notice(
            L"DEX++ Helper is already running on port 8080.\n\n"
            L"The existing dashboard will be opened instead of starting a duplicate server.",
            true
        );
        CloseHandle(instance_mutex);
        return 0;
    }
    SetConsoleCtrlHandler(helper_console_control, TRUE);

    WSADATA wsaData;
    int iResult;

    SOCKET ListenSocket = INVALID_SOCKET;
    SOCKET ClientSocket = INVALID_SOCKET;

    struct addrinfo* result = NULL;
    struct addrinfo hints;

    // Initialize Winsock
    iResult = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (iResult != 0) {
        std::cerr << "WSAStartup failed with error: " << iResult << std::endl;
        show_startup_notice(L"DEX++ Helper could not initialize Windows networking.", false);
        CloseHandle(instance_mutex);
        return 1;
    }

    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = AI_PASSIVE;

    // Resolve the server address and port
    iResult = getaddrinfo(NULL, DEFAULT_PORT, &hints, &result);
    if (iResult != 0) {
        std::cerr << "getaddrinfo failed with error: " << iResult << std::endl;
        WSACleanup();
        show_startup_notice(L"DEX++ Helper could not resolve its local listening address.", false);
        CloseHandle(instance_mutex);
        return 1;
    }

    // Create a SOCKET for the server to listen for client connections
    ListenSocket = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
    if (ListenSocket == INVALID_SOCKET) {
        std::cerr << "socket failed with error: " << WSAGetLastError() << std::endl;
        freeaddrinfo(result);
        WSACleanup();
        show_startup_notice(L"DEX++ Helper could not create its local server socket.", false);
        CloseHandle(instance_mutex);
        return 1;
    }

    // Setup the TCP listening socket
    iResult = bind(ListenSocket, result->ai_addr, static_cast<int>(result->ai_addrlen));
    if (iResult == SOCKET_ERROR) {
        int bind_error = WSAGetLastError();
        std::cerr << "bind failed with error: " << bind_error << std::endl;
        freeaddrinfo(result);
        closesocket(ListenSocket);
        WSACleanup();
        if (bind_error == WSAEADDRINUSE) {
            show_startup_notice(
                L"DEX++ Helper could not start because port 8080 is already in use.\n\n"
                L"Close the application using port 8080, then start the helper again.",
                false
            );
        } else {
            show_startup_notice(L"DEX++ Helper could not bind to localhost port 8080.", false);
        }
        CloseHandle(instance_mutex);
        return 1;
    }

    freeaddrinfo(result);

    iResult = listen(ListenSocket, SOMAXCONN);
    if (iResult == SOCKET_ERROR) {
        std::cerr << "listen failed with error: " << WSAGetLastError() << std::endl;
        closesocket(ListenSocket);
        WSACleanup();
        show_startup_notice(L"DEX++ Helper created its socket but could not begin listening.", false);
        CloseHandle(instance_mutex);
        return 1;
    }

    std::string load_result = load_index_response();
    load_auth_credentials();
    std::cout << "DEX++ C++ Local Helper Server listening on port " << DEFAULT_PORT << "..." << std::endl;
    std::cout << "Index load: " << load_result << std::endl;
    std::cout << "Dashboard: http://localhost:" << DEFAULT_PORT << "/" << std::endl;
    open_dashboard();

    while (true) {
        // Accept a client socket
        ClientSocket = accept(ListenSocket, NULL, NULL);
        if (ClientSocket == INVALID_SOCKET) {
            std::cerr << "accept failed with error: " << WSAGetLastError() << std::endl;
            continue;
        }

        if (g_active_clients.load() >= MAX_CLIENT_THREADS) {
            send_response(ClientSocket, 503, "Service Unavailable", "DEX++ Helper is busy. Try again shortly.");
            close_client(ClientSocket);
            continue;
        }

        g_active_clients.fetch_add(1);
        std::thread([ClientSocket]() {
            try {
                handle_client(ClientSocket);
            } catch (...) {
                close_client(ClientSocket);
            }
            g_active_clients.fetch_sub(1);
        }).detach();
    }

    closesocket(ListenSocket);
    WSACleanup();
    return 0;
}

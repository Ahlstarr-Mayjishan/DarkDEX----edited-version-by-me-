#ifndef UNICODE
#define UNICODE
#endif

#define WIN32_LEAN_AND_MEAN

#include <winsock2.h>
#include <ws2tcpip.h>
#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <fstream>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <cctype>
#include <ctime>
#include <cstdio>
#include <mutex>
#include <thread>
#include <atomic>

// Link with ws2_32.lib
#pragma comment(lib, "ws2_32.lib")

#define DEFAULT_PORT "8080"
#define BUFFER_SIZE 8192
#define MAX_HEADER_SIZE 32768
#define MAX_BODY_SIZE 5242880
#define MAX_LOG_BODY_SIZE 65536
#define MAX_LOG_FILE_SIZE 5242880
#define MAX_CLIENT_THREADS 16

const char* INDEX_FILE_PATH = "dex_helper_index.dat";
const char* INDEX_MAGIC = "DEXPP_INDEX_V1";

struct IndexedScript {
    std::string key;
    std::string path;
    std::string name;
    std::string class_name;
    std::string source;
    std::string lower_source;
    std::string lower_path;
    std::string analysis;
    std::vector<std::string> top_identifiers;
    std::time_t updated_at;
};

std::unordered_map<std::string, IndexedScript> g_script_index;
std::mutex g_script_index_mutex;
std::mutex g_log_mutex;
std::atomic<int> g_active_clients{0};

// Fast C++ linear-time variable normalizer. This is a source cleanup pass, not a full deobfuscator.
std::string normalize_source(const std::string& source) {
    std::unordered_map<std::string, std::string> var_map;
    int var_counter = 0;

    auto is_obfuscated = [](const std::string& name) {
        // Skip keywords
        static const std::unordered_set<std::string> reserved = {
            "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
            "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
            "until", "while", "self", "game", "workspace", "script"
        };
        if (reserved.count(name)) return false;

        // Match l__u__\d+ or u_\d+
        if (name.rfind("l__u__", 0) == 0 || name.rfind("u_", 0) == 0) return true;

        // Match _0x...
        if (name.rfind("_0x", 0) == 0 || name.rfind("0x", 0) == 0) return true;

        // Match barcode (composed only of I, l, 1 and length >= 4)
        if (name.length() >= 4) {
            bool barcode = true;
            for (char c : name) {
                if (c != 'I' && c != 'l' && c != '1') {
                    barcode = false;
                    break;
                }
            }
            if (barcode) return true;
        }
        return false;
    };

    // First pass: identify all obfuscated variable tokens
    std::string current_word = "";
    for (char c : source) {
        if (isalnum(static_cast<unsigned char>(c)) || c == '_') {
            current_word += c;
        } else {
            if (!current_word.empty()) {
                if (is_obfuscated(current_word) && var_map.count(current_word) == 0) {
                    var_map[current_word] = "var_" + std::to_string(++var_counter);
                }
                current_word = "";
            }
        }
    }
    if (!current_word.empty() && is_obfuscated(current_word) && var_map.count(current_word) == 0) {
        var_map[current_word] = "var_" + std::to_string(++var_counter);
    }

    // Second pass: reconstruct string with normalized variables
    std::string result = "";
    current_word = "";
    for (char c : source) {
        if (isalnum(static_cast<unsigned char>(c)) || c == '_') {
            current_word += c;
        } else {
            if (!current_word.empty()) {
                if (var_map.count(current_word)) {
                    result += var_map[current_word];
                } else {
                    result += current_word;
                }
                current_word = "";
            }
            result += c;
        }
    }
    if (!current_word.empty()) {
        if (var_map.count(current_word)) {
            result += var_map[current_word];
        } else {
            result += current_word;
        }
    }

    return result;
}

std::string escape_json(const std::string& value) {
    std::string out;
    out.reserve(value.size() + 16);
    for (char c : value) {
        switch (c) {
        case '\\': out += "\\\\"; break;
        case '"': out += "\\\""; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        default:
            if (static_cast<unsigned char>(c) < 32) {
                out += " ";
            } else {
                out += c;
            }
            break;
        }
    }
    return out;
}

int count_token(const std::string& source, const std::string& token) {
    int count = 0;
    size_t pos = 0;
    while ((pos = source.find(token, pos)) != std::string::npos) {
        ++count;
        pos += token.size();
    }
    return count;
}

std::string lower_copy(const std::string& value) {
    std::string out = value;
    std::transform(out.begin(), out.end(), out.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return out;
}

std::string make_snippet(const std::string& source, size_t pos) {
    if (source.empty()) return "";
    size_t start = pos > 70 ? pos - 70 : 0;
    size_t end = std::min(source.size(), pos + 150);
    std::string snippet = source.substr(start, end - start);
    for (char& c : snippet) {
        if (c == '\r' || c == '\n' || c == '\t') c = ' ';
    }
    return snippet;
}

std::vector<std::string> split_header_payload(const std::string& body, int header_lines) {
    std::vector<std::string> parts;
    size_t start = 0;
    for (int i = 0; i < header_lines; ++i) {
        size_t pos = body.find('\n', start);
        if (pos == std::string::npos) return {};
        std::string line = body.substr(start, pos - start);
        if (!line.empty() && line.back() == '\r') line.pop_back();
        parts.push_back(line);
        start = pos + 1;
    }
    parts.push_back(body.substr(start));
    return parts;
}

std::vector<std::string> top_identifiers(const std::string& source, int limit) {
    static const std::unordered_set<std::string> reserved = {
        "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
        "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
        "until", "while", "self", "game", "workspace", "script", "local", "return"
    };
    std::unordered_map<std::string, int> counts;
    std::string word;
    for (char c : source) {
        if (std::isalnum(static_cast<unsigned char>(c)) || c == '_') {
            word += c;
        } else if (!word.empty()) {
            if (word.size() >= 3 && !reserved.count(word)) counts[word]++;
            word.clear();
        }
    }
    if (!word.empty() && word.size() >= 3 && !reserved.count(word)) counts[word]++;

    std::vector<std::pair<std::string, int>> rows(counts.begin(), counts.end());
    std::sort(rows.begin(), rows.end(), [](const auto& a, const auto& b) {
        if (a.second == b.second) return a.first < b.first;
        return a.second > b.second;
    });

    std::vector<std::string> out;
    for (int i = 0; i < static_cast<int>(rows.size()) && i < limit; ++i) {
        out.push_back(rows[i].first + ":" + std::to_string(rows[i].second));
    }
    return out;
}

std::string identifier_name(const std::string& identifier_count) {
    size_t split = identifier_count.find(':');
    if (split == std::string::npos) return identifier_count;
    return identifier_count.substr(0, split);
}

double confidence_for_match(const std::string& match_type, int score) {
    double confidence = 0.60;
    if (match_type == "name") confidence = 0.98;
    else if (match_type == "identifier") confidence = 0.88;
    else if (match_type == "path") confidence = 0.82;
    else if (match_type == "source") confidence = 0.72;
    confidence += std::min(0.08, static_cast<double>(score) / 250.0);
    return std::min(0.99, confidence);
}

std::string analyze_source(const std::string& source) {
    int lines = source.empty() ? 0 : 1;
    for (char c : source) if (c == '\n') ++lines;

    std::vector<std::pair<std::string, int>> signals = {
        {"HttpGet", count_token(source, "HttpGet")},
        {"HttpPost", count_token(source, "HttpPost")},
        {"loadstring", count_token(source, "loadstring")},
        {"require", count_token(source, "require")},
        {"FireServer", count_token(source, "FireServer")},
        {"InvokeServer", count_token(source, "InvokeServer")},
        {"OnClientEvent", count_token(source, "OnClientEvent")},
        {"OnClientInvoke", count_token(source, "OnClientInvoke")},
        {"getgenv", count_token(source, "getgenv")},
        {"getgc", count_token(source, "getgc")},
        {"hookfunction", count_token(source, "hookfunction")},
        {"hookmetamethod", count_token(source, "hookmetamethod")},
    };

    int risky = 0;
    for (const auto& item : signals) {
        if (item.first == "HttpGet" || item.first == "HttpPost" || item.first == "loadstring" ||
            item.first == "getgenv" || item.first == "getgc" || item.first == "hookfunction" ||
            item.first == "hookmetamethod") {
            risky += item.second;
        }
    }

    std::stringstream json;
    json << "{";
    json << "\"bytes\":" << source.size() << ",";
    json << "\"lines\":" << lines << ",";
    json << "\"functions\":" << count_token(source, "function") << ",";
    json << "\"locals\":" << count_token(source, "local ") << ",";
    json << "\"requires\":" << count_token(source, "require") << ",";
    json << "\"remoteCalls\":" << (count_token(source, "FireServer") + count_token(source, "InvokeServer")) << ",";
    json << "\"riskySignals\":" << risky << ",";
    json << "\"signals\":[";
    bool first = true;
    for (const auto& item : signals) {
        if (item.second <= 0) continue;
        if (!first) json << ",";
        first = false;
        json << "{\"name\":\"" << escape_json(item.first) << "\",\"count\":" << item.second << "}";
    }
    json << "],";
    json << "\"topIdentifiers\":[";
    auto ids = top_identifiers(source, 12);
    for (size_t i = 0; i < ids.size(); ++i) {
        if (i > 0) json << ",";
        json << "\"" << escape_json(ids[i]) << "\"";
    }
    json << "]";
    json << "}";
    return json.str();
}

struct RoleProfile {
    std::string id;
    std::string label;
    std::string language;
    std::string module;
    std::string summary;
    std::vector<std::pair<std::string, int>> keywords;
};

struct ScoredRole {
    const RoleProfile* profile;
    int score;
    std::vector<std::string> matched;
};

ScoredRole score_role(const std::string& text, const RoleProfile& profile) {
    ScoredRole result{&profile, 0, {}};
    for (const auto& term : profile.keywords) {
        int hits = count_token(text, term.first);
        if (hits <= 0) continue;
        result.score += hits * term.second;
        if (result.matched.size() < 6) {
            result.matched.push_back(term.first);
        }
    }
    return result;
}

std::string assign_role(const std::string& task) {
    std::string text = lower_copy(task);
    std::vector<RoleProfile> profiles = {
        {
            "cxx_helper_core",
            "C++ Helper Core",
            "C++",
            "HelperServer",
            "Fast indexing, source analysis, cache maintenance, search, and structured export.",
            {
                {"index", 7}, {"search", 7}, {"cache", 7}, {"analysis", 6}, {"analyze", 6},
                {"parse", 5}, {"json", 6}, {"deobfuscate", 8}, {"source", 4}, {"snippet", 4},
                {"timeline", 4}, {"graph", 4}, {"dependency", 4}, {"report", 4}, {"export", 4},
                {"log", 3}, {"token", 4}, {"score", 3}, {"pack", 4}
            }
        },
        {
            "luau_ui",
            "Luau UI / Explorer",
            "Luau",
            "Explorer",
            "Immediate UI work, tree rendering, selection handling, buttons, tabs, and menus.",
            {
                {"ui", 6}, {"window", 6}, {"button", 7}, {"tab", 7}, {"menu", 7},
                {"tree", 8}, {"selection", 8}, {"explorer", 7}, {"panel", 5}, {"label", 4},
                {"textbox", 6}, {"render", 6}, {"layout", 6}, {"context", 5}, {"click", 5},
                {"select", 6}, {"copy", 4}, {"view", 4}
            }
        },
        {
            "luau_runtime",
            "Luau Runtime Monitor",
            "Luau",
            "RuntimeInspector",
            "Live object capture, remotes, property tracking, timeline, and lightweight client state.",
            {
                {"runtime", 8}, {"live", 6}, {"remote", 8}, {"remotes", 8}, {"property", 7},
                {"tracker", 6}, {"timeline", 8}, {"snapshot", 6}, {"capture", 6}, {"monitor", 7},
                {"buffer", 5}, {"record", 5}, {"event", 5}, {"inspector", 7}, {"state", 4}
            }
        },
        {
            "ai_context",
            "AI Context Packager",
            "Mixed",
            "CopyToAI",
            "Prompt building, summary packing, object context, and beginner-friendly explanation.",
            {
                {"ai", 8}, {"prompt", 8}, {"context", 8}, {"copy", 6}, {"summar", 7},
                {"beginner", 5}, {"explain", 5}, {"pack", 5}, {"export", 5}, {"guide", 4}
            }
        }
    };

    std::vector<ScoredRole> scored;
    scored.reserve(profiles.size());
    for (const auto& profile : profiles) {
        scored.push_back(score_role(text, profile));
    }

    std::sort(scored.begin(), scored.end(), [](const ScoredRole& a, const ScoredRole& b) {
        if (a.score == b.score) return a.profile->id < b.profile->id;
        return a.score > b.score;
    });

    const ScoredRole* primary = scored.empty() ? nullptr : &scored[0];
    const ScoredRole* secondary = scored.size() > 1 ? &scored[1] : nullptr;

    auto confidence_for = [](int score) {
        if (score <= 0) return 35;
        return std::min(98, 40 + score * 4);
    };

    std::stringstream json;
    json << "{";
    json << "\"ok\":true,";
    json << "\"taskBytes\":" << task.size() << ",";
    json << "\"primary\":{";
    if (primary) {
        json << "\"role\":\"" << escape_json(primary->profile->id) << "\",";
        json << "\"label\":\"" << escape_json(primary->profile->label) << "\",";
        json << "\"language\":\"" << escape_json(primary->profile->language) << "\",";
        json << "\"module\":\"" << escape_json(primary->profile->module) << "\",";
        json << "\"confidence\":" << confidence_for(primary->score) << ",";
        json << "\"score\":" << primary->score << ",";
        json << "\"summary\":\"" << escape_json(primary->profile->summary) << "\",";
        json << "\"signals\":[";
        for (size_t i = 0; i < primary->matched.size(); ++i) {
            if (i > 0) json << ",";
            json << "\"" << escape_json(primary->matched[i]) << "\"";
        }
        json << "]";
    } else {
        json << "\"role\":\"unknown\",\"label\":\"Unknown\",\"language\":\"Unknown\",\"module\":\"Unknown\",\"confidence\":35,\"score\":0,\"summary\":\"No match\",\"signals\":[]";
    }
    json << "},";
    json << "\"secondary\":{";
    if (secondary) {
        json << "\"role\":\"" << escape_json(secondary->profile->id) << "\",";
        json << "\"label\":\"" << escape_json(secondary->profile->label) << "\",";
        json << "\"language\":\"" << escape_json(secondary->profile->language) << "\",";
        json << "\"module\":\"" << escape_json(secondary->profile->module) << "\",";
        json << "\"confidence\":" << confidence_for(secondary->score) << ",";
        json << "\"score\":" << secondary->score << ",";
        json << "\"summary\":\"" << escape_json(secondary->profile->summary) << "\",";
        json << "\"signals\":[";
        for (size_t i = 0; i < secondary->matched.size(); ++i) {
            if (i > 0) json << ",";
            json << "\"" << escape_json(secondary->matched[i]) << "\"";
        }
        json << "]";
    } else {
        json << "\"role\":\"unknown\",\"label\":\"Unknown\",\"language\":\"Unknown\",\"module\":\"Unknown\",\"confidence\":35,\"score\":0,\"summary\":\"No fallback\",\"signals\":[]";
    }
    json << "},";
    json << "\"workflow\":[";
    if (primary) {
        std::vector<std::string> workflow = {
            "Send heavy, repeated, or cached work to " + primary->profile->module + ".",
            "Keep UI, selection, and click handling in Luau.",
            "Use cache-first flows; only fall back when the helper is offline."
        };
        for (size_t i = 0; i < workflow.size(); ++i) {
            if (i > 0) json << ",";
            json << "\"" << escape_json(workflow[i]) << "\"";
        }
    }
    json << "]";
    json << "}";
    return json.str();
}

bool save_index_locked();

std::string index_source_payload(const std::string& body) {
    auto parts = split_header_payload(body, 4);
    if (parts.size() != 5 || parts[0].empty()) {
        return "{\"ok\":false,\"error\":\"invalid index payload\"}";
    }

    IndexedScript entry;
    entry.key = parts[0];
    entry.path = parts[1];
    entry.name = parts[2];
    entry.class_name = parts[3];
    entry.source = parts[4];
    entry.lower_source = lower_copy(entry.source);
    entry.lower_path = lower_copy(entry.path);
    entry.analysis = analyze_source(entry.source);
    entry.top_identifiers = top_identifiers(entry.source, 12);
    entry.updated_at = std::time(nullptr);
    std::time_t updated_at = entry.updated_at;

    std::lock_guard<std::mutex> lock(g_script_index_mutex);
    g_script_index[entry.key] = std::move(entry);

    size_t bytes = 0;
    for (const auto& item : g_script_index) bytes += item.second.source.size();
    bool saved = save_index_locked();

    std::stringstream json;
    json << "{\"ok\":true,\"total\":" << g_script_index.size()
         << ",\"bytes\":" << bytes
         << ",\"updatedAt\":" << static_cast<long long>(updated_at)
         << ",\"persisted\":" << (saved ? "true" : "false")
         << "}";
    return json.str();
}

std::string index_status() {
    std::lock_guard<std::mutex> lock(g_script_index_mutex);
    size_t bytes = 0;
    std::time_t newest = 0;
    std::time_t oldest = 0;
    bool seen = false;
    for (const auto& item : g_script_index) bytes += item.second.source.size();
    for (const auto& item : g_script_index) {
        std::time_t updated = item.second.updated_at;
        if (!seen) {
            newest = oldest = updated;
            seen = true;
        } else {
            newest = std::max(newest, updated);
            oldest = std::min(oldest, updated);
        }
    }

    std::stringstream json;
    json << "{\"ok\":true,\"scripts\":" << g_script_index.size()
         << ",\"bytes\":" << bytes
         << ",\"oldestUpdatedAt\":" << static_cast<long long>(seen ? oldest : 0)
         << ",\"newestUpdatedAt\":" << static_cast<long long>(seen ? newest : 0)
         << "}";
    return json.str();
}

std::string search_index(const std::string& body) {
    auto parts = split_header_payload(body, 1);
    if (parts.size() != 2) {
        return "{\"ok\":false,\"error\":\"invalid search payload\",\"results\":[]}";
    }

    int limit = 80;
    try {
        limit = std::max(1, std::min(200, std::stoi(parts[0])));
    } catch (...) {
        limit = 80;
    }

    std::string query = lower_copy(parts[1]);
    std::lock_guard<std::mutex> lock(g_script_index_mutex);
    if (query.empty()) {
        return "{\"ok\":true,\"indexed\":" + std::to_string(g_script_index.size()) + ",\"total\":0,\"results\":[]}";
    }

    struct Hit {
        const IndexedScript* entry;
        int score;
        size_t pos;
        std::string match_type;
        std::string matched_token;
        double confidence;
    };
    std::vector<Hit> hits;
    hits.reserve(std::min<size_t>(g_script_index.size(), static_cast<size_t>(limit)));

    for (const auto& item : g_script_index) {
        const IndexedScript& entry = item.second;
        size_t path_pos = entry.lower_path.find(query);
        size_t source_pos = entry.lower_source.find(query);
        std::string lower_name = lower_copy(entry.name);
        size_t name_pos = lower_name.find(query);
        std::string matched_identifier;
        size_t identifier_pos = std::string::npos;
        for (const auto& identifier : entry.top_identifiers) {
            std::string lower_identifier = lower_copy(identifier_name(identifier));
            if (lower_identifier.find(query) != std::string::npos || query.find(lower_identifier) != std::string::npos) {
                identifier_pos = entry.lower_source.find(lower_identifier);
                matched_identifier = identifier;
                break;
            }
        }
        if (path_pos == std::string::npos && source_pos == std::string::npos && name_pos == std::string::npos && identifier_pos == std::string::npos) continue;

        int score = 10;
        if (path_pos != std::string::npos) score += 30;
        if (source_pos != std::string::npos) score += 15;
        if (name_pos == 0 && lower_name == query) score += 40;
        else if (name_pos != std::string::npos) score += 20;
        if (identifier_pos != std::string::npos) score += 25;

        std::string match_type = "source";
        size_t pos = source_pos != std::string::npos ? source_pos : 0;
        std::string matched_token = query;
        if (path_pos != std::string::npos) {
            match_type = "path";
            pos = source_pos != std::string::npos ? source_pos : 0;
        }
        if (identifier_pos != std::string::npos) {
            match_type = "identifier";
            matched_token = matched_identifier;
            if (source_pos != std::string::npos) pos = source_pos;
        }
        if (name_pos != std::string::npos) {
            match_type = "name";
            matched_token = entry.name;
            if (source_pos != std::string::npos) pos = source_pos;
        }

        hits.push_back({&entry, score, pos, match_type, matched_token, confidence_for_match(match_type, score)});
    }

    std::sort(hits.begin(), hits.end(), [](const Hit& a, const Hit& b) {
        if (a.score == b.score) return a.entry->path < b.entry->path;
        return a.score > b.score;
    });

    std::stringstream json;
    json << "{\"ok\":true,\"indexed\":" << g_script_index.size()
         << ",\"total\":" << hits.size() << ",\"results\":[";
    for (int i = 0; i < static_cast<int>(hits.size()) && i < limit; ++i) {
        const IndexedScript& entry = *hits[i].entry;
        if (i > 0) json << ",";
        json << "{\"key\":\"" << escape_json(entry.key) << "\",";
        json << "\"path\":\"" << escape_json(entry.path) << "\",";
        json << "\"name\":\"" << escape_json(entry.name) << "\",";
        json << "\"className\":\"" << escape_json(entry.class_name) << "\",";
        json << "\"score\":" << hits[i].score << ",";
        json << "\"matchType\":\"" << escape_json(hits[i].match_type) << "\",";
        json << "\"matchedToken\":\"" << escape_json(hits[i].matched_token) << "\",";
        json << "\"confidence\":" << hits[i].confidence << ",";
        json << "\"updatedAt\":" << static_cast<long long>(entry.updated_at) << ",";
        json << "\"snippet\":\"" << escape_json(make_snippet(entry.source, hits[i].pos)) << "\",";
        json << "\"analysis\":" << entry.analysis << "}";
    }
    json << "]}";
    return json.str();
}

void write_field(std::ostream& out, const std::string& value) {
    out << value.size() << "\n";
    out.write(value.data(), static_cast<std::streamsize>(value.size()));
    out << "\n";
}

bool read_field(std::istream& in, std::string& value) {
    std::string length_line;
    if (!std::getline(in, length_line)) return false;
    if (!length_line.empty() && length_line.back() == '\r') length_line.pop_back();

    size_t length = 0;
    try {
        length = static_cast<size_t>(std::stoull(length_line));
    } catch (...) {
        return false;
    }

    value.assign(length, '\0');
    if (length > 0) {
        in.read(&value[0], static_cast<std::streamsize>(length));
        if (static_cast<size_t>(in.gcount()) != length) return false;
    }

    char newline = '\0';
    in.get(newline);
    return newline == '\n';
}

bool save_index_locked() {
    std::ofstream out(INDEX_FILE_PATH, std::ios::binary | std::ios::trunc);
    if (!out.is_open()) return false;

    out << INDEX_MAGIC << "\n";
    out << g_script_index.size() << "\n";
    for (const auto& item : g_script_index) {
        const IndexedScript& entry = item.second;
        write_field(out, entry.key);
        write_field(out, entry.path);
        write_field(out, entry.name);
        write_field(out, entry.class_name);
        write_field(out, entry.source);
        out << static_cast<long long>(entry.updated_at) << "\n";
    }
    return out.good();
}

std::string save_index_response() {
    std::lock_guard<std::mutex> lock(g_script_index_mutex);
    bool ok = save_index_locked();
    std::stringstream json;
    json << "{\"ok\":" << (ok ? "true" : "false")
         << ",\"scripts\":" << g_script_index.size()
         << ",\"file\":\"" << escape_json(INDEX_FILE_PATH) << "\"}";
    return json.str();
}

std::string load_index_response() {
    std::ifstream in(INDEX_FILE_PATH, std::ios::binary);
    if (!in.is_open()) {
        return "{\"ok\":false,\"error\":\"index file not found\",\"scripts\":0}";
    }

    std::string magic;
    if (!std::getline(in, magic) || magic != INDEX_MAGIC) {
        return "{\"ok\":false,\"error\":\"invalid index file\",\"scripts\":0}";
    }

    std::string count_line;
    if (!std::getline(in, count_line)) {
        return "{\"ok\":false,\"error\":\"missing index count\",\"scripts\":0}";
    }

    size_t count = 0;
    try {
        count = static_cast<size_t>(std::stoull(count_line));
    } catch (...) {
        return "{\"ok\":false,\"error\":\"invalid index count\",\"scripts\":0}";
    }

    std::unordered_map<std::string, IndexedScript> loaded;
    for (size_t i = 0; i < count; ++i) {
        IndexedScript entry;
        if (!read_field(in, entry.key) ||
            !read_field(in, entry.path) ||
            !read_field(in, entry.name) ||
            !read_field(in, entry.class_name) ||
            !read_field(in, entry.source)) {
            return "{\"ok\":false,\"error\":\"truncated index entry\",\"scripts\":0}";
        }

        std::string updated_line;
        if (!std::getline(in, updated_line)) {
            return "{\"ok\":false,\"error\":\"missing index timestamp\",\"scripts\":0}";
        }
        try {
            entry.updated_at = static_cast<std::time_t>(std::stoll(updated_line));
        } catch (...) {
            entry.updated_at = std::time(nullptr);
        }

        entry.lower_source = lower_copy(entry.source);
        entry.lower_path = lower_copy(entry.path);
        entry.analysis = analyze_source(entry.source);
        entry.top_identifiers = top_identifiers(entry.source, 12);
        if (!entry.key.empty()) {
            loaded[entry.key] = std::move(entry);
        }
    }

    {
        std::lock_guard<std::mutex> lock(g_script_index_mutex);
        g_script_index = std::move(loaded);
    }

    std::stringstream json;
    json << "{\"ok\":true,\"scripts\":" << count
         << ",\"file\":\"" << escape_json(INDEX_FILE_PATH) << "\"}";
    return json.str();
}

std::string trim_copy(const std::string& value) {
    size_t first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return "";
    size_t last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
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

size_t file_size_or_zero(const char* path) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) return 0;
    std::streampos size = file.tellg();
    if (size <= 0) return 0;
    return static_cast<size_t>(size);
}

void rotate_log_if_needed(const char* path) {
    if (file_size_or_zero(path) < MAX_LOG_FILE_SIZE) return;
    std::string old_path = std::string(path) + ".old";
    std::remove(old_path.c_str());
    std::rename(path, old_path.c_str());
}

// Send HTTP response helper
void send_response(SOCKET client_socket, int status_code, const std::string& status_text, const std::string& body) {
    std::stringstream response;
    response << "HTTP/1.1 " << status_code << " " << status_text << "\r\n"
             << "Content-Type: text/plain\r\n"
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
        } else if (path == "/status" && method == "GET") {
            send_response(ClientSocket, 200, "OK", "DEX++ C++ Helper Server Active");
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
            send_response(ClientSocket, 200, "OK", analyze_source(body));
        } else if (path == "/index-source" && method == "POST") {
            send_response(ClientSocket, 200, "OK", index_source_payload(body));
        } else if (path == "/search-source" && method == "POST") {
            send_response(ClientSocket, 200, "OK", search_index(body));
        } else if (path == "/index-status" && method == "GET") {
            send_response(ClientSocket, 200, "OK", index_status());
        } else if (path == "/index-save" && method == "POST") {
            send_response(ClientSocket, 200, "OK", save_index_response());
        } else if (path == "/index-load" && method == "POST") {
            send_response(ClientSocket, 200, "OK", load_index_response());
        } else if (path == "/index-clear" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_script_index_mutex);
            g_script_index.clear();
            bool saved = save_index_locked();
            send_response(ClientSocket, 200, "OK", saved ? "{\"ok\":true,\"total\":0,\"persisted\":true}" : "{\"ok\":true,\"total\":0,\"persisted\":false}");
        } else if (path == "/assign-role" && method == "POST") {
            send_response(ClientSocket, 200, "OK", assign_role(body));
        } else if (path == "/decompile" && method == "POST") {
            send_response(
                ClientSocket,
                501,
                "Not Implemented",
                "DEX++ Helper does not include a bytecode decompiler. It serves local script delivery, log, source normalization, source analysis, and persistent source index/search."
            );
        } else {
            send_response(ClientSocket, 404, "Not Found", "404 Route Not Found");
        }
    }

    close_client(ClientSocket);
}

int main() {
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
        return 1;
    }

    // Create a SOCKET for the server to listen for client connections
    ListenSocket = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
    if (ListenSocket == INVALID_SOCKET) {
        std::cerr << "socket failed with error: " << WSAGetLastError() << std::endl;
        freeaddrinfo(result);
        WSACleanup();
        return 1;
    }

    // Setup the TCP listening socket
    iResult = bind(ListenSocket, result->ai_addr, static_cast<int>(result->ai_addrlen));
    if (iResult == SOCKET_ERROR) {
        std::cerr << "bind failed with error: " << WSAGetLastError() << std::endl;
        freeaddrinfo(result);
        closesocket(ListenSocket);
        WSACleanup();
        return 1;
    }

    freeaddrinfo(result);

    iResult = listen(ListenSocket, SOMAXCONN);
    if (iResult == SOCKET_ERROR) {
        std::cerr << "listen failed with error: " << WSAGetLastError() << std::endl;
        closesocket(ListenSocket);
        WSACleanup();
        return 1;
    }

    std::string load_result = load_index_response();
    std::cout << "DEX++ C++ Local Helper Server listening on port " << DEFAULT_PORT << "..." << std::endl;
    std::cout << "Index load: " << load_result << std::endl;

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

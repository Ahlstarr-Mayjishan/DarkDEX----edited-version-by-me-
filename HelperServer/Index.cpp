#include "Index.h"

const char* INDEX_FILE_PATH = "dex_helper_index.dat";
const char* INDEX_MAGIC = "DEXPP_INDEX_V1";

std::unordered_map<std::string, IndexedScript> g_script_index;
std::mutex g_script_index_mutex;

std::wstring to_wstring(const std::string& str) {
    return std::wstring(str.begin(), str.end());
}

std::string to_string(const std::wstring& wstr) {
    return std::string(wstr.begin(), wstr.end());
}

void create_directories_for_file(const std::wstring& file_path) {
    size_t pos = 0;
    while ((pos = file_path.find(L'\\', pos)) != std::wstring::npos) {
        if (pos > 0) {
            std::wstring dir = file_path.substr(0, pos);
            CreateDirectoryW(dir.c_str(), NULL);
        }
        pos += 1;
    }
}

void scan_directory_recursive(const std::wstring& base_dir, const std::wstring& current_subdir, std::vector<FileInfo>& files) {
    std::wstring search_path = base_dir + L"\\" + (current_subdir.empty() ? L"" : current_subdir + L"\\") + L"*";
    WIN32_FIND_DATAW find_data;
    HANDLE find_handle = FindFirstFileW(search_path.c_str(), &find_data);
    if (find_handle == INVALID_HANDLE_VALUE) return;
    
    do {
        std::wstring file_name = find_data.cFileName;
        if (file_name == L"." || file_name == L"..") continue;
        
        std::wstring relative_file = current_subdir.empty() ? file_name : current_subdir + L"\\" + file_name;
        
        if (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            scan_directory_recursive(base_dir, relative_file, files);
        } else {
            ULARGE_INTEGER ft;
            ft.LowPart = find_data.ftLastWriteTime.dwLowDateTime;
            ft.HighPart = find_data.ftLastWriteTime.dwHighDateTime;
            
            std::string rel_str(relative_file.begin(), relative_file.end());
            files.push_back({rel_str, ft.QuadPart});
        }
    } while (FindNextFileW(find_handle, &find_data));
    
    FindClose(find_handle);
}

std::string normalize_source(const std::string& source) {
    std::unordered_map<std::string, std::string> var_map;
    int var_counter = 0;

    auto is_obfuscated = [](const std::string& name) {
        if (name.empty()) return false;
        if (std::isdigit(static_cast<unsigned char>(name[0]))) return false;

        static const std::unordered_set<std::string> reserved = {
            "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
            "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
            "until", "while", "self", "game", "workspace", "script"
        };
        if (reserved.count(name)) return false;

        if (name.rfind("l__u__", 0) == 0 || name.rfind("u_", 0) == 0) return true;
        if (name.rfind("_0x", 0) == 0 || name.rfind("0x", 0) == 0) return true;

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

std::string trim_copy(const std::string& value) {
    size_t first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return "";
    size_t last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
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
    json << "\"ok\":true,";
    json << "\"worker\":\"cxx_core\",";
    json << "\"language\":\"C++\",";
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

struct RemoteSummary {
    std::string path;
    int calls = 0;
    int outgoing = 0;
    int incoming = 0;
    std::unordered_map<std::string, int> methods;
    std::vector<std::string> samples;
    int risk = 0;
    std::vector<std::string> flags;
};

void add_remote_flag(RemoteSummary& summary, const std::string& flag, int score) {
    if (std::find(summary.flags.begin(), summary.flags.end(), flag) == summary.flags.end()) {
        summary.flags.push_back(flag);
        summary.risk += score;
    }
}

std::string compact_copy(const std::string& value, size_t limit) {
    std::string out = value;
    std::replace(out.begin(), out.end(), '\r', ' ');
    std::replace(out.begin(), out.end(), '\n', ' ');
    if (out.size() > limit) out = out.substr(0, limit) + "...";
    return out;
}

std::string analyze_remote_logs(const std::string& logs) {
    std::unordered_map<std::string, RemoteSummary> summaries;
    std::unordered_map<std::string, int> method_counts;
    int total = 0;
    int parsed = 0;

    std::stringstream input(logs);
    std::string line;
    while (std::getline(input, line)) {
        line = trim_copy(line);
        if (line.empty()) continue;
        ++total;

        std::string direction = "unknown";
        if (line.find(" outgoing ") != std::string::npos || line.find("] out ") != std::string::npos || line.find("[outgoing]") != std::string::npos) {
            direction = "out";
        } else if (line.find(" incoming ") != std::string::npos || line.find("] in ") != std::string::npos || line.find("[incoming]") != std::string::npos) {
            direction = "in";
        }

        size_t method_pos = line.find(":FireServer()");
        std::string method = "unknown";
        if (method_pos != std::string::npos) {
            method = "FireServer";
        } else {
            method_pos = line.find(":InvokeServer()");
            if (method_pos != std::string::npos) method = "InvokeServer";
        }
        if (method_pos == std::string::npos) {
            method_pos = line.find(":Fire()");
            if (method_pos != std::string::npos) method = "Fire";
        }
        if (method_pos == std::string::npos) {
            method_pos = line.find(":Invoke()");
            if (method_pos != std::string::npos) method = "Invoke";
        }
        if (method_pos == std::string::npos) {
            method_pos = line.find(":OnClientEvent()");
            if (method_pos != std::string::npos) method = "OnClientEvent";
        }
        if (method_pos == std::string::npos) {
            method_pos = line.find(":Event()");
            if (method_pos != std::string::npos) method = "Event";
        }
        if (method_pos == std::string::npos) continue;

        size_t path_start = line.rfind(' ', method_pos);
        if (path_start == std::string::npos) path_start = line.rfind(']', method_pos);
        path_start = (path_start == std::string::npos) ? 0 : path_start + 1;
        std::string path = trim_copy(line.substr(path_start, method_pos - path_start));
        if (path.empty()) continue;

        std::string args;
        size_t args_pos = line.find('|', method_pos);
        if (args_pos != std::string::npos) args = trim_copy(line.substr(args_pos + 1));

        RemoteSummary& summary = summaries[path];
        if (summary.path.empty()) summary.path = path;
        summary.calls += 1;
        if (direction == "out") summary.outgoing += 1;
        if (direction == "in") summary.incoming += 1;
        summary.methods[method] += 1;
        method_counts[method] += 1;
        if (!args.empty() && summary.samples.size() < 3) summary.samples.push_back(compact_copy(args, 180));
        ++parsed;

        std::string lower = lower_copy(path + " " + args);
        if (lower.find("admin") != std::string::npos || lower.find("ban") != std::string::npos || lower.find("kick") != std::string::npos) {
            add_remote_flag(summary, "admin/control wording", 4);
        }
        if (lower.find("cash") != std::string::npos || lower.find("coin") != std::string::npos || lower.find("money") != std::string::npos || lower.find("gem") != std::string::npos) {
            add_remote_flag(summary, "currency wording", 3);
        }
        if (lower.find("buy") != std::string::npos || lower.find("purchase") != std::string::npos || lower.find("reward") != std::string::npos) {
            add_remote_flag(summary, "transaction/reward wording", 3);
        }
        if (lower.find("teleport") != std::string::npos || lower.find("position") != std::string::npos || lower.find("cframe") != std::string::npos) {
            add_remote_flag(summary, "movement/position wording", 2);
        }
        if (method == "InvokeServer") add_remote_flag(summary, "blocking remote function", 1);
        if (summary.calls >= 30) add_remote_flag(summary, "high frequency", 2);
    }

    std::vector<RemoteSummary*> rows;
    rows.reserve(summaries.size());
    for (auto& item : summaries) rows.push_back(&item.second);
    std::sort(rows.begin(), rows.end(), [](const RemoteSummary* a, const RemoteSummary* b) {
        if (a->risk != b->risk) return a->risk > b->risk;
        return a->calls > b->calls;
    });

    std::stringstream json;
    json << "{\"ok\":true,\"lines\":" << total
         << ",\"parsed\":" << parsed
         << ",\"remotes\":" << rows.size()
         << ",\"methodCounts\":{";
    bool first = true;
    for (const auto& item : method_counts) {
        if (!first) json << ",";
        first = false;
        json << "\"" << escape_json(item.first) << "\":" << item.second;
    }
    json << "},\"results\":[";
    size_t limit = std::min<size_t>(rows.size(), 80);
    for (size_t i = 0; i < limit; ++i) {
        const RemoteSummary& row = *rows[i];
        if (i) json << ",";
        json << "{\"path\":\"" << escape_json(row.path) << "\","
             << "\"calls\":" << row.calls << ","
             << "\"outgoing\":" << row.outgoing << ","
             << "\"incoming\":" << row.incoming << ","
             << "\"risk\":" << row.risk << ",\"methods\":{";
        bool first_method = true;
        for (const auto& method_item : row.methods) {
            if (!first_method) json << ",";
            first_method = false;
            json << "\"" << escape_json(method_item.first) << "\":" << method_item.second;
        }
        json << "},\"flags\":[";
        for (size_t j = 0; j < row.flags.size(); ++j) {
            if (j) json << ",";
            json << "\"" << escape_json(row.flags[j]) << "\"";
        }
        json << "],\"samples\":[";
        for (size_t j = 0; j < row.samples.size(); ++j) {
            if (j) json << ",";
            json << "\"" << escape_json(row.samples[j]) << "\"";
        }
        json << "]}";
    }
    json << "]}";
    return json.str();
}


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

    std::stringstream json;
    json << "{\"ok\":true,\"total\":" << g_script_index.size()
         << ",\"bytes\":" << bytes
         << ",\"updatedAt\":" << static_cast<long long>(updated_at)
         << ",\"persisted\":false"
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

std::string index_entry(const std::string& key) {
    std::lock_guard<std::mutex> lock(g_script_index_mutex);
    auto found = g_script_index.find(trim_copy(key));
    if (found == g_script_index.end()) {
        return "{\"ok\":false,\"error\":\"script not found\"}";
    }

    const IndexedScript& entry = found->second;
    std::stringstream json;
    json << "{\"ok\":true,"
         << "\"key\":\"" << escape_json(entry.key) << "\","
         << "\"path\":\"" << escape_json(entry.path) << "\","
         << "\"name\":\"" << escape_json(entry.name) << "\","
         << "\"className\":\"" << escape_json(entry.class_name) << "\","
         << "\"updatedAt\":" << static_cast<long long>(entry.updated_at) << ","
         << "\"source\":\"" << escape_json(entry.source) << "\","
         << "\"analysis\":" << entry.analysis
         << "}";
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

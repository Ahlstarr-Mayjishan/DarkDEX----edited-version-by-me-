#pragma once
#include "Common.h"

extern const char* INDEX_FILE_PATH;
extern const char* INDEX_MAGIC;

struct FileInfo {
    std::string relative_path;
    unsigned long long last_write_time = 0;
};

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


extern std::unordered_map<std::string, IndexedScript> g_script_index;
extern std::mutex g_script_index_mutex;

std::wstring to_wstring(const std::string& str);
std::string to_string(const std::wstring& wstr);
void create_directories_for_file(const std::wstring& file_path);
void scan_directory_recursive(const std::wstring& base_dir, const std::wstring& current_subdir, std::vector<FileInfo>& files);
std::string normalize_source(const std::string& source);
std::string escape_json(const std::string& value);
int count_token(const std::string& source, const std::string& token);
std::string lower_copy(const std::string& value);
std::string trim_copy(const std::string& value);
std::string make_snippet(const std::string& source, size_t pos);
std::vector<std::string> split_header_payload(const std::string& body, int header_lines);
std::vector<std::string> top_identifiers(const std::string& source, int limit);
std::string identifier_name(const std::string& identifier_count);
double confidence_for_match(const std::string& match_type, int score);
std::string analyze_source(const std::string& source);
std::string analyze_remote_logs(const std::string& logs);
std::string assign_role(const std::string& task);
std::string index_source_payload(const std::string& body);
std::string index_status();
std::string search_index(const std::string& body);
std::string index_entry(const std::string& key);
void write_field(std::ostream& out, const std::string& value);
bool read_field(std::istream& in, std::string& value);
bool save_index_locked();
std::string save_index_response();
std::string load_index_response();

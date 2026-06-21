#pragma once
#include "Common.h"

extern std::string g_roblox_cookie;
extern std::string g_github_token;
extern std::string g_google_api_key;
extern std::string g_openai_api_key;
extern std::string g_google_client_id;
extern std::string g_google_client_secret;
extern std::string g_github_client_id;
extern std::string g_github_client_secret;
extern std::string g_google_oauth_token;
extern std::string g_github_oauth_token;
extern std::string g_accounts_json;
extern std::mutex g_auth_mutex;

void load_auth_credentials();
void save_auth_credentials();
std::string http_get_https(const std::string& host, const std::string& path, const std::string& headers);
std::string http_post_https(const std::string& host, const std::string& path, const std::string& headers, const std::string& body);
std::string extract_json_field(const std::string& json, const std::string& field);
std::string get_roblox_avatar(const std::string& user_id);
std::string get_roblox_profile_response(const std::string& cookie);
std::string get_github_profile_response(const std::string& token);
std::string get_google_profile_response(const std::string& token);
std::string verify_gemini_api_key(const std::string& api_key);
std::string get_openai_profile_response(const std::string& token);

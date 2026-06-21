#pragma once
#include "Common.h"

extern std::atomic<bool> g_shutdown_requested;
extern std::atomic<bool> g_dashboard_started;
extern std::atomic<bool> g_dashboard_ready;
extern HWND g_dashboard_host;
extern HWND g_dashboard_view;
extern HANDLE g_dashboard_browser_process;
extern HANDLE g_dashboard_browser_job;
extern DWORD g_dashboard_browser_pid;
extern const int DASHBOARD_TITLE_HEIGHT;
extern const wchar_t* INSTANCE_MUTEX_NAME;
extern const wchar_t* DASHBOARD_URL;

bool startup_dialogs_enabled();
bool env_flag_enabled(const char* name);
std::wstring expand_path(const wchar_t* path);
std::wstring find_app_browser();
bool launch_dashboard_app();
void show_startup_notice(const wchar_t* message, bool open_dashboard);
void open_dashboard();
bool terminate_process_by_name(const wchar_t* process_name);
BOOL WINAPI helper_console_control(DWORD control_type);
void schedule_local_shutdown(bool clean_data);
BOOL CALLBACK find_browser_window(HWND window, LPARAM data);
void resize_dashboard_view(HWND host);
LRESULT CALLBACK dashboard_window_proc(HWND window, UINT message, WPARAM w_param, LPARAM l_param);
bool start_embedded_browser(HWND host);
bool launch_native_dashboard();

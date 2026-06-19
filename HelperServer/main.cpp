#ifndef UNICODE
#define UNICODE
#endif

#define WIN32_LEAN_AND_MEAN

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>
#include <tlhelp32.h>
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
#include <chrono>
#include <cstdlib>
#include <climits>

// Link with ws2_32.lib
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "shell32.lib")

#define DEFAULT_PORT "8080"
#define BUFFER_SIZE 8192
#define MAX_HEADER_SIZE 32768
#define MAX_BODY_SIZE 5242880
#define MAX_LOG_BODY_SIZE 65536
#define MAX_LOG_FILE_SIZE 5242880
#define MAX_CLIENT_THREADS 16

const char* INDEX_FILE_PATH = "dex_helper_index.dat";
const char* INDEX_MAGIC = "DEXPP_INDEX_V1";
const wchar_t* INSTANCE_MUTEX_NAME = L"Local\\DEXPlusPlusHelperServer_8080";
const wchar_t* DASHBOARD_URL = L"http://localhost:8080/";

bool launch_native_dashboard();

bool startup_dialogs_enabled() {
    char value[8];
    return GetEnvironmentVariableA("DEX_HELPER_NO_DIALOG", value, sizeof(value)) == 0;
}

bool env_flag_enabled(const char* name) {
    char value[8] = {};
    DWORD length = GetEnvironmentVariableA(name, value, sizeof(value));
    if (length == 0 || length >= sizeof(value)) return false;
    std::string normalized = value;
    std::transform(normalized.begin(), normalized.end(), normalized.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return normalized == "1" || normalized == "true" || normalized == "yes";
}

std::wstring expand_path(const wchar_t* path) {
    wchar_t expanded[MAX_PATH] = {};
    DWORD length = ExpandEnvironmentStringsW(path, expanded, MAX_PATH);
    if (length == 0 || length > MAX_PATH) return L"";
    return expanded;
}

std::wstring find_app_browser() {
    const wchar_t* candidates[] = {
        L"%ProgramFiles(x86)%\\Microsoft\\Edge\\Application\\msedge.exe",
        L"%ProgramFiles%\\Microsoft\\Edge\\Application\\msedge.exe",
        L"%LocalAppData%\\Microsoft\\Edge\\Application\\msedge.exe",
        L"%ProgramFiles%\\Google\\Chrome\\Application\\chrome.exe",
        L"%ProgramFiles(x86)%\\Google\\Chrome\\Application\\chrome.exe",
        L"%LocalAppData%\\Google\\Chrome\\Application\\chrome.exe",
    };
    for (const wchar_t* candidate : candidates) {
        std::wstring path = expand_path(candidate);
        if (!path.empty() && GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES) {
            return path;
        }
    }
    return L"";
}

bool launch_dashboard_app() {
    std::wstring browser = find_app_browser();
    std::wstring local_app_data = expand_path(L"%LocalAppData%");
    if (browser.empty() || local_app_data.empty()) return false;

    std::wstring profile = local_app_data + L"\\DEXPlusPlus\\HelperApp";
    CreateDirectoryW((local_app_data + L"\\DEXPlusPlus").c_str(), NULL);
    CreateDirectoryW(profile.c_str(), NULL);

    RECT work{};
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
    int work_width = std::max(800L, work.right - work.left);
    int work_height = std::max(600L, work.bottom - work.top);
    int app_width = std::max(760, std::min(1100, work_width - 96));
    int app_height = std::max(560, std::min(720, work_height - 72));
    int app_x = work.left + std::max(0, (work_width - app_width) / 2);
    int app_y = work.top + std::max(0, (work_height - app_height) / 2);

    std::wstring parameters =
        L"--app=http://localhost:8080/"
        L" --user-data-dir=\"" + profile + L"\""
        L" --no-first-run --disable-sync"
        L" --window-size=" + std::to_wstring(app_width) + L"," + std::to_wstring(app_height)
        + L" --window-position=" + std::to_wstring(app_x) + L"," + std::to_wstring(app_y);

    SHELLEXECUTEINFOW launch{};
    launch.cbSize = sizeof(launch);
    launch.fMask = SEE_MASK_NOCLOSEPROCESS;
    launch.lpVerb = L"open";
    launch.lpFile = browser.c_str();
    launch.lpParameters = parameters.c_str();
    launch.nShow = SW_SHOWNORMAL;
    if (!ShellExecuteExW(&launch)) return false;
    if (launch.hProcess) CloseHandle(launch.hProcess);
    return true;
}

void show_startup_notice(const wchar_t* message, bool open_dashboard) {
    std::wcerr << message << std::endl;
    if (!startup_dialogs_enabled()) return;

    if (open_dashboard) {
        if (!launch_dashboard_app()) {
            ShellExecuteW(NULL, L"open", DASHBOARD_URL, NULL, NULL, SW_SHOWNORMAL);
        }
    }
    MessageBoxW(NULL, message, L"DEX++ Helper", MB_OK | MB_ICONINFORMATION | MB_SETFOREGROUND);
}

void open_dashboard() {
    if (!startup_dialogs_enabled()) return;
    if (!env_flag_enabled("DEX_HELPER_WEB_MODE") && launch_dashboard_app()) {
        if (!env_flag_enabled("DEX_HELPER_KEEP_CONSOLE")) {
            HWND console = GetConsoleWindow();
            if (console) ShowWindow(console, SW_HIDE);
        }
        return;
    }
    HINSTANCE result = ShellExecuteW(NULL, L"open", DASHBOARD_URL, NULL, NULL, SW_SHOWNORMAL);
    if (reinterpret_cast<INT_PTR>(result) <= 32) {
        std::cerr << "Could not open the helper dashboard automatically." << std::endl;
    }
}

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
std::mutex g_tool_state_mutex;
std::string g_tool_state_json = "{\"ok\":true,\"tools\":{},\"updatedAt\":0}";
std::atomic<int> g_active_clients{0};
std::atomic<bool> g_shutdown_requested{false};
std::atomic<bool> g_dashboard_started{false};
std::atomic<bool> g_dashboard_ready{false};
HWND g_dashboard_host = NULL;
HWND g_dashboard_view = NULL;
HANDLE g_dashboard_browser_process = NULL;
HANDLE g_dashboard_browser_job = NULL;
DWORD g_dashboard_browser_pid = 0;
const int DASHBOARD_TITLE_HEIGHT = 44;

bool terminate_process_by_name(const wchar_t* process_name) {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return false;

    bool terminated = false;
    PROCESSENTRY32W entry{};
    entry.dwSize = sizeof(entry);
    if (Process32FirstW(snapshot, &entry)) {
        do {
            if (_wcsicmp(entry.szExeFile, process_name) == 0 && entry.th32ProcessID != GetCurrentProcessId()) {
                HANDLE process = OpenProcess(PROCESS_TERMINATE, FALSE, entry.th32ProcessID);
                if (process) {
                    if (TerminateProcess(process, 0)) terminated = true;
                    CloseHandle(process);
                }
            }
        } while (Process32NextW(snapshot, &entry));
    }
    CloseHandle(snapshot);
    return terminated;
}

BOOL WINAPI helper_console_control(DWORD control_type) {
    if (control_type == CTRL_CLOSE_EVENT
        || control_type == CTRL_C_EVENT
        || control_type == CTRL_BREAK_EVENT
        || control_type == CTRL_LOGOFF_EVENT
        || control_type == CTRL_SHUTDOWN_EVENT) {
        terminate_process_by_name(L"Decompiler.exe");
        return FALSE;
    }
    return FALSE;
}

void schedule_local_shutdown(bool clean_data) {
    if (g_shutdown_requested.exchange(true)) return;

    std::thread([clean_data]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(350));
        terminate_process_by_name(L"Decompiler.exe");

        if (clean_data) {
            {
                std::lock_guard<std::mutex> lock(g_script_index_mutex);
                g_script_index.clear();
            }
            {
                std::lock_guard<std::mutex> lock(g_tool_state_mutex);
                g_tool_state_json = "{\"ok\":true,\"tools\":{},\"updatedAt\":0}";
            }
            std::remove(INDEX_FILE_PATH);
            std::remove("dex_server_logs.txt");
            std::remove("dex_server_logs.txt.old");
        }
        ExitProcess(0);
    }).detach();
}

BOOL CALLBACK find_browser_window(HWND window, LPARAM data) {
    DWORD process_id = 0;
    GetWindowThreadProcessId(window, &process_id);
    if (process_id == g_dashboard_browser_pid && GetWindow(window, GW_OWNER) == NULL) {
        *reinterpret_cast<HWND*>(data) = window;
        return FALSE;
    }
    return TRUE;
}

void resize_dashboard_view(HWND host) {
    if (!g_dashboard_view) return;
    RECT client{};
    GetClientRect(host, &client);
    SetWindowPos(
        g_dashboard_view,
        NULL,
        0,
        DASHBOARD_TITLE_HEIGHT,
        client.right,
        std::max<LONG>(1, client.bottom - DASHBOARD_TITLE_HEIGHT),
        SWP_NOZORDER | SWP_NOACTIVATE
    );
}

LRESULT CALLBACK dashboard_window_proc(HWND window, UINT message, WPARAM w_param, LPARAM l_param) {
    switch (message) {
        case WM_NCCALCSIZE:
            if (w_param) return 0;
            break;
        case WM_NCHITTEST: {
            POINT cursor{GET_X_LPARAM(l_param), GET_Y_LPARAM(l_param)};
            RECT rect{};
            GetWindowRect(window, &rect);
            int x = cursor.x - rect.left;
            int y = cursor.y - rect.top;
            const int border = 7;
            if (y < border) {
                if (x < border) return HTTOPLEFT;
                if (x >= rect.right - rect.left - border) return HTTOPRIGHT;
                return HTTOP;
            }
            if (y >= rect.bottom - rect.top - border) {
                if (x < border) return HTBOTTOMLEFT;
                if (x >= rect.right - rect.left - border) return HTBOTTOMRIGHT;
                return HTBOTTOM;
            }
            if (x < border) return HTLEFT;
            if (x >= rect.right - rect.left - border) return HTRIGHT;
            if (y < DASHBOARD_TITLE_HEIGHT && x < rect.right - rect.left - 144) return HTCAPTION;
            return HTCLIENT;
        }
        case WM_LBUTTONUP: {
            int x = GET_X_LPARAM(l_param);
            int y = GET_Y_LPARAM(l_param);
            RECT client{};
            GetClientRect(window, &client);
            if (y >= 0 && y < DASHBOARD_TITLE_HEIGHT) {
                if (x >= client.right - 48) {
                    PostMessageW(window, WM_CLOSE, 0, 0);
                } else if (x >= client.right - 96) {
                    ShowWindow(window, IsZoomed(window) ? SW_RESTORE : SW_MAXIMIZE);
                } else if (x >= client.right - 144) {
                    ShowWindow(window, SW_MINIMIZE);
                }
            }
            return 0;
        }
        case WM_LBUTTONDBLCLK: {
            int x = GET_X_LPARAM(l_param);
            int y = GET_Y_LPARAM(l_param);
            RECT client{};
            GetClientRect(window, &client);
            if (y < DASHBOARD_TITLE_HEIGHT && x < client.right - 144) {
                ShowWindow(window, IsZoomed(window) ? SW_RESTORE : SW_MAXIMIZE);
            }
            return 0;
        }
        case WM_SIZE:
            resize_dashboard_view(window);
            InvalidateRect(window, NULL, FALSE);
            return 0;
        case WM_GETMINMAXINFO: {
            auto* info = reinterpret_cast<MINMAXINFO*>(l_param);
            info->ptMinTrackSize.x = 760;
            info->ptMinTrackSize.y = 560;
            return 0;
        }
        case WM_ERASEBKGND:
            return 1;
        case WM_PAINT: {
            PAINTSTRUCT paint{};
            HDC dc = BeginPaint(window, &paint);
            RECT client{};
            GetClientRect(window, &client);
            RECT title{0, 0, client.right, DASHBOARD_TITLE_HEIGHT};
            HBRUSH background = CreateSolidBrush(RGB(12, 16, 21));
            FillRect(dc, &title, background);
            DeleteObject(background);

            SetBkMode(dc, TRANSPARENT);
            SetTextColor(dc, RGB(235, 240, 245));
            HFONT font = CreateFontW(
                -17, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI"
            );
            HFONT old_font = static_cast<HFONT>(SelectObject(dc, font));
            RECT brand{18, 0, client.right - 150, DASHBOARD_TITLE_HEIGHT};
            DrawTextW(dc, L"DEX++  /  HELPER", -1, &brand, DT_LEFT | DT_VCENTER | DT_SINGLELINE);

            SetTextColor(dc, RGB(151, 165, 180));
            RECT minimize{client.right - 144, 0, client.right - 96, DASHBOARD_TITLE_HEIGHT};
            RECT maximize{client.right - 96, 0, client.right - 48, DASHBOARD_TITLE_HEIGHT};
            RECT close{client.right - 48, 0, client.right, DASHBOARD_TITLE_HEIGHT};
            DrawTextW(dc, L"\x2212", -1, &minimize, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
            DrawTextW(dc, IsZoomed(window) ? L"\x2750" : L"\x25A1", -1, &maximize, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
            DrawTextW(dc, L"\x00D7", -1, &close, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

            SelectObject(dc, old_font);
            DeleteObject(font);
            EndPaint(window, &paint);
            return 0;
        }
        case WM_CLOSE:
            DestroyWindow(window);
            return 0;
        case WM_DESTROY:
            if (g_dashboard_view) {
                PostMessageW(g_dashboard_view, WM_CLOSE, 0, 0);
                g_dashboard_view = NULL;
            }
            if (g_dashboard_browser_process) {
                CloseHandle(g_dashboard_browser_process);
                g_dashboard_browser_process = NULL;
            }
            if (g_dashboard_browser_job) {
                CloseHandle(g_dashboard_browser_job);
                g_dashboard_browser_job = NULL;
            }
            g_dashboard_host = NULL;
            PostQuitMessage(0);
            if (g_dashboard_ready.exchange(false) && !g_shutdown_requested.load()) {
                schedule_local_shutdown(false);
            }
            return 0;
    }
    return DefWindowProcW(window, message, w_param, l_param);
}

bool start_embedded_browser(HWND host) {
    std::wstring browser = find_app_browser();
    std::wstring local_app_data = expand_path(L"%LocalAppData%");
    if (browser.empty() || local_app_data.empty()) return false;

    std::wstring profile = local_app_data + L"\\DEXPlusPlus\\NativeHost_"
        + std::to_wstring(GetCurrentProcessId());
    CreateDirectoryW((local_app_data + L"\\DEXPlusPlus").c_str(), NULL);
    CreateDirectoryW(profile.c_str(), NULL);
    std::wstring parameters =
        L"--app=http://localhost:8080/"
        L" --user-data-dir=\"" + profile + L"\""
        L" --no-first-run --disable-sync --disable-gpu"
        L" --disable-features=msEdgeSidebarV2"
        L" --window-position=120,80 --window-size=900,640";

    SHELLEXECUTEINFOW launch{};
    launch.cbSize = sizeof(launch);
    launch.fMask = SEE_MASK_NOCLOSEPROCESS;
    launch.lpVerb = L"open";
    launch.lpFile = browser.c_str();
    launch.lpParameters = parameters.c_str();
    launch.nShow = SW_SHOWNORMAL;
    if (!ShellExecuteExW(&launch) || !launch.hProcess) return false;

    g_dashboard_browser_process = launch.hProcess;
    g_dashboard_browser_pid = GetProcessId(launch.hProcess);
    g_dashboard_browser_job = CreateJobObjectW(NULL, NULL);
    if (g_dashboard_browser_job) {
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        SetInformationJobObject(
            g_dashboard_browser_job,
            JobObjectExtendedLimitInformation,
            &limits,
            sizeof(limits)
        );
        if (!AssignProcessToJobObject(g_dashboard_browser_job, launch.hProcess)) {
            CloseHandle(g_dashboard_browser_job);
            g_dashboard_browser_job = NULL;
        }
    }
    for (int attempt = 0; attempt < 80 && !g_dashboard_view; ++attempt) {
        EnumWindows(find_browser_window, reinterpret_cast<LPARAM>(&g_dashboard_view));
        if (!g_dashboard_view) std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    if (!g_dashboard_view) return false;

    ShowWindow(g_dashboard_view, SW_RESTORE);
    LONG_PTR style = GetWindowLongPtrW(g_dashboard_view, GWL_STYLE);
    style &= ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
    style |= WS_CHILD | WS_VISIBLE;
    SetWindowLongPtrW(g_dashboard_view, GWL_STYLE, style);
    LONG_PTR ex_style = GetWindowLongPtrW(g_dashboard_view, GWL_EXSTYLE);
    ex_style &= ~(WS_EX_APPWINDOW | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE);
    SetWindowLongPtrW(g_dashboard_view, GWL_EXSTYLE, ex_style);
    SetParent(g_dashboard_view, host);
    resize_dashboard_view(host);
    SetWindowPos(g_dashboard_view, NULL, 0, DASHBOARD_TITLE_HEIGHT, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    ShowWindow(g_dashboard_view, SW_SHOW);
    SendMessageW(g_dashboard_view, WM_SIZE, 0, 0);
    RedrawWindow(g_dashboard_view, NULL, NULL, RDW_INVALIDATE | RDW_ALLCHILDREN | RDW_UPDATENOW);
    return true;
}

bool launch_native_dashboard() {
    if (g_dashboard_started.exchange(true)) {
        if (g_dashboard_host) {
            ShowWindow(g_dashboard_host, SW_RESTORE);
            SetForegroundWindow(g_dashboard_host);
        }
        return true;
    }

    std::thread([]() {
        HINSTANCE instance = GetModuleHandleW(NULL);
        WNDCLASSEXW window_class{};
        window_class.cbSize = sizeof(window_class);
        window_class.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
        window_class.lpfnWndProc = dashboard_window_proc;
        window_class.hInstance = instance;
        window_class.hCursor = LoadCursorW(NULL, IDC_ARROW);
        window_class.hbrBackground = CreateSolidBrush(RGB(12, 16, 21));
        window_class.lpszClassName = L"DEXPlusPlusNativeDashboard";
        RegisterClassExW(&window_class);

        RECT work{};
        SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
        int work_width = work.right - work.left;
        int work_height = work.bottom - work.top;
        int width = std::max(760, std::min(1100, work_width - 96));
        int height = std::max(560, std::min(720, work_height - 72));
        int x = work.left + std::max(0, (work_width - width) / 2);
        int y = work.top + std::max(0, (work_height - height) / 2);

        g_dashboard_host = CreateWindowExW(
            0,
            window_class.lpszClassName,
            L"DEX++ Helper",
            WS_POPUP | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU,
            x, y, width, height,
            NULL, NULL, instance, NULL
        );
        if (g_dashboard_host) {
            ShowWindow(g_dashboard_host, SW_SHOW);
            UpdateWindow(g_dashboard_host);
        }
        if (!g_dashboard_host || !start_embedded_browser(g_dashboard_host)) {
            g_dashboard_started.store(false);
            if (g_dashboard_host) DestroyWindow(g_dashboard_host);
            ShellExecuteW(NULL, L"open", DASHBOARD_URL, NULL, NULL, SW_SHOWNORMAL);
            return;
        }

        g_dashboard_ready.store(true);
        UpdateWindow(g_dashboard_host);
        SetForegroundWindow(g_dashboard_host);

        MSG message{};
        while (GetMessageW(&message, NULL, 0, 0) > 0) {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
    }).detach();
    return true;
}

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

struct FileInfo {
    std::string relative_path;
    unsigned long long last_write_time = 0;
};

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
            
            // Convert relative path to std::string
            std::string rel_str(relative_file.begin(), relative_file.end());
            files.push_back({rel_str, ft.QuadPart});
        }
    } while (FindNextFileW(find_handle, &find_data));
    
    FindClose(find_handle);
}


// Fast C++ linear-time variable normalizer. This is a source cleanup pass, not a full deobfuscator.
std::string normalize_source(const std::string& source) {
    std::unordered_map<std::string, std::string> var_map;
    int var_counter = 0;

    auto is_obfuscated = [](const std::string& name) {
        if (name.empty()) return false;
        // Skip numbers/constants (identifiers cannot start with a digit)
        if (std::isdigit(static_cast<unsigned char>(name[0]))) return false;

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

std::string trim_copy(const std::string& value);

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

std::string helper_dashboard_html() {
    return R"DEXAPP(<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DEX++ Helper</title>
<style>
:root{color-scheme:dark;--bg:#0b0f14;--sidebar:#10151b;--panel:#151b22;--panel2:#1a222b;--panel3:#202a34;--line:#2a3743;--line-soft:#202a34;--text:#f2f5f7;--muted:#8fa0b1;--accent:#52b69a;--accent2:#68c7a9;--warn:#d7ad56;--bad:#e66a73}
*{box-sizing:border-box;scrollbar-width:thin;scrollbar-color:#53606c transparent}*::-webkit-scrollbar{width:8px;height:8px}*::-webkit-scrollbar-track{background:transparent}*::-webkit-scrollbar-thumb{background:#4a5662;border:2px solid transparent;background-clip:padding-box;border-radius:8px}*::-webkit-scrollbar-thumb:hover{background:#65727e;border:2px solid transparent;background-clip:padding-box}*::-webkit-scrollbar-button{display:none;width:0;height:0}
html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.48 "Segoe UI Variable","Segoe UI",Arial,sans-serif;letter-spacing:0}
header{height:48px;display:flex;align-items:center;gap:9px;padding:0 16px;border-bottom:1px solid var(--line-soft);background:#0d1217;position:sticky;top:0;z-index:2}
h1{display:none}.pill{font:11px Consolas,monospace;color:var(--muted);background:#141b22;border:1px solid var(--line);border-radius:4px;padding:4px 8px}
main{display:grid;grid-template-columns:306px 1fr;height:calc(100vh - 48px);min-height:560px;overflow:hidden}
aside{overflow:auto;border-right:1px solid var(--line-soft);background:var(--sidebar);padding:12px 12px 20px;display:flex;flex-direction:column;gap:2px}
section{padding:14px 16px 16px;display:grid;grid-template-rows:auto auto minmax(0,1fr);gap:10px;min-width:0;min-height:0;overflow:hidden}
.card{background:transparent;border:0;border-bottom:1px solid var(--line-soft);border-radius:0;padding:15px 8px 17px}.card:last-child{border-bottom:0}.title{font-size:12px;font-weight:650;color:#cbd5de;margin-bottom:10px;text-transform:uppercase}
.metrics{display:grid;grid-template-columns:1fr 1fr;gap:7px}.metric{background:var(--panel);border:1px solid var(--line-soft);border-radius:6px;padding:10px 11px}.metric b{display:block;font-size:20px;font-weight:650;font-variant-numeric:tabular-nums}.metric span{color:var(--muted);font-size:11px}
.stateRows{display:flex;flex-direction:column;gap:6px}.stateRow{background:var(--panel);border:1px solid var(--line-soft);border-radius:6px;padding:9px 10px}.stateRow b{display:block;font-size:13px;font-weight:600}.stateRow span{display:block;color:var(--muted);font:11px/1.45 Consolas,monospace;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bar{height:4px;background:#0b1015;border-radius:4px;overflow:hidden;margin-top:7px}.bar i{display:block;height:100%;width:0;background:var(--accent2)}
button,input,textarea{font:inherit;letter-spacing:0}button{background:var(--panel2);border:1px solid var(--line);color:#dce4ea;border-radius:5px;height:31px;padding:0 11px;cursor:pointer;transition:border-color .16s,background .16s,color .16s,transform .16s}button:hover{border-color:#465767;background:var(--panel3);color:white}button:active{transform:translateY(1px)}button:focus-visible,input:focus-visible,textarea:focus-visible{outline:2px solid rgba(82,182,154,.45);outline-offset:1px}button.primary{background:var(--accent);border-color:var(--accent);color:#07130f;font-weight:650}button.primary:hover{background:var(--accent2);border-color:var(--accent2)}.row{display:flex;gap:7px;align-items:center;flex-wrap:wrap}.row>*{min-width:0}
input,textarea{width:100%;background:#0d1217;border:1px solid var(--line);color:var(--text);border-radius:5px;padding:8px 10px;outline:none}input:focus,textarea:focus{border-color:var(--accent)}textarea{min-height:150px;resize:vertical;font-family:Consolas,monospace}
.toolbar{display:grid;grid-template-columns:1fr auto auto;gap:8px}.tabs{display:flex;gap:2px;border-bottom:1px solid var(--line-soft)}.tab{height:34px;border:0;border-bottom:2px solid transparent;border-radius:0;background:transparent;color:var(--muted)}.tab:hover{background:transparent;color:var(--text);border-color:#43515e}.tab.active{border-color:var(--accent);color:white;background:transparent}
.results{min-height:0;overflow:auto;border:1px solid var(--line-soft);border-radius:6px;background:#0d1217}.hit{padding:11px 13px;border-bottom:1px solid var(--line-soft)}.hit:last-child{border-bottom:0}.hit h3{font-size:14px;margin:0 0 4px}.hit .meta{color:var(--muted);font:11px Consolas,monospace;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.hit pre{margin:8px 0 0;white-space:pre-wrap;color:#cbd5e1;font:12px Consolas,monospace}
.searchWorkspace{display:grid;grid-template-columns:minmax(280px,40%) minmax(320px,1fr);min-height:0;overflow:hidden;border:1px solid var(--line-soft);border-radius:6px;background:#0d1217}.resultList{min-height:0;overflow:auto;border-right:1px solid var(--line-soft)}.resultSummary{position:sticky;top:0;z-index:1;padding:9px 12px;background:#131920;border-bottom:1px solid var(--line-soft);color:var(--muted);font:11px Consolas,monospace}.resultItem{display:block;width:100%;height:auto;padding:11px 12px;text-align:left;border:0;border-bottom:1px solid var(--line-soft);border-radius:0;background:transparent}.resultItem:hover{background:#151d24}.resultItem.active{background:#182822;box-shadow:inset 2px 0 var(--accent)}.resultItem h3{font-size:14px;margin:0 0 4px;color:var(--text)}.resultItem .meta{color:var(--muted);font:11px Consolas,monospace;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.resultInspector{min-width:0;min-height:0;display:grid;grid-template-rows:auto auto minmax(0,1fr);overflow:hidden}.inspectorHead{padding:12px 14px;border-bottom:1px solid var(--line-soft)}.inspectorHead h2{font-size:15px;margin:0 0 4px}.inspectorActions{display:flex;gap:7px;flex-wrap:wrap;padding:9px 12px;border-bottom:1px solid var(--line-soft);background:#11171d}.sourcePreview{margin:0;padding:14px;overflow:auto;white-space:pre;tab-size:4;color:#cbd5e1;font:12px/1.55 Consolas,monospace}.emptyInspector{display:grid;place-items:center;padding:28px;color:var(--muted);text-align:center}.actionStatus{margin-left:auto;align-self:center;color:var(--muted);font:11px Consolas,monospace}
.hero{display:grid;grid-template-columns:1.15fr .85fr;gap:12px}.statusGrid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.dot{display:inline-block;width:7px;height:7px;border-radius:50%;background:var(--muted);margin-right:6px}.dot.ok{background:var(--accent2);box-shadow:0 0 10px rgba(104,199,169,.4)}.dot.warn{background:var(--warn)}.dot.bad{background:var(--bad)}.codebox{font:11px Consolas,monospace;background:#0d1217;border:1px solid var(--line-soft);border-radius:5px;padding:8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.steps{display:grid;gap:9px}.step{display:grid;grid-template-columns:24px 1fr;gap:9px;align-items:start}.step b{display:grid;place-items:center;width:22px;height:22px;border-radius:4px;background:var(--panel2);border:1px solid var(--line);font:11px Consolas,monospace}
.muted{color:var(--muted)}.ok{color:var(--accent2)}.warn{color:var(--warn)}.bad{color:var(--bad)}.hidden{display:none!important}
@media(max-width:980px){main{grid-template-columns:1fr;height:auto;min-height:calc(100vh - 48px);overflow:visible}.hero{grid-template-columns:1fr}aside{border-right:0;border-bottom:1px solid var(--line);max-height:46vh}section{height:70vh}.searchWorkspace{grid-template-columns:minmax(240px,38%) 1fr}}
@media(max-width:700px){.searchWorkspace{grid-template-columns:1fr}.resultList{border-right:0}.resultInspector{display:none}}
</style>
</head>
<body>
<header><h1>DEX++ Helper</h1><span class="pill" id="statusPill">checking</span><span class="pill" id="scriptPill">script unknown</span><span class="pill" id="dexPill">Roblox waiting</span></header>
<main>
<aside>
  <div class="card">
    <div class="title"><span class="dot warn" id="scriptDot"></span>Script delivery</div>
    <div class="muted" id="scriptStatus">Checking DEX++_compiled.luau...</div>
    <div class="codebox" id="loadstringBox" style="margin-top:8px">loadstring(game:HttpGet("http://localhost:8080/script"))()</div>
    <div class="row" style="margin-top:8px"><button id="copyLoadstring" class="primary">Copy loadstring</button><button id="openScript">Open script</button></div>
  </div>
  <div class="card">
    <div class="title"><span class="dot warn" id="dexDot"></span>Current Roblox session</div>
    <div class="stateRows">
      <div class="stateRow"><b id="gameName">Waiting for DEX</b><span id="gameMeta">Run the loadstring in Roblox to connect this dashboard.</span></div>
      <div class="stateRow"><b id="indexTarget">No active index</b><span id="indexMeta">Code Search > Index Scripts will show progress here.</span></div>
    </div>
  </div>
  <div class="card">
    <div class="title">Worker roles</div>
    <div id="workerRoles" class="stateRows">
      <div class="stateRow"><b>Detecting workers</b><span>C++, Python, Rust role map will appear here.</span></div>
    </div>
  </div>
  <div class="card">
    <div class="title">Toolchain setup</div>
    <div id="toolchainStatus" class="stateRows">
      <div class="stateRow"><b>Checking build tools</b><span>Python, Cargo, g++, and winget.</span></div>
    </div>
    <button id="openToolchainSetup" style="margin-top:8px;width:100%">Open setup utility</button>
  </div>
  <div class="card">
    <div class="title">Index</div>
    <div class="metrics">
      <div class="metric"><b id="scripts">0</b><span>scripts</span></div>
      <div class="metric"><b id="bytes">0</b><span>bytes</span></div>
    </div>
    <div class="row" style="margin-top:10px"><button id="refresh">Refresh</button><button id="load">Load</button><button id="save">Save</button><button id="clear">Clear</button></div>
  </div>
  <div class="card">
    <div class="title">Live DEX</div>
    <div id="liveDex" class="stateRows">
      <div class="stateRow"><b>Waiting for Roblox</b><span>Enable Use Local Helper and run an index/control tool.</span></div>
    </div>
  </div>
  <div class="card">
    <div class="title">Roblox Smooth Mode</div>
    <div class="muted">Keep heavy search and analysis here. In DEX, leave Helper logging off while playing. Index scripts only when you are not in a demanding fight/session.</div>
  </div>
  <div class="card">
    <div class="title">Local services</div>
    <div class="muted">Stops only DEX++ Helper on port 8080 and Potassium Decompiler on port 56535. Potassium itself stays open.</div>
    <div class="row" style="margin-top:8px">
      <button id="stopLocal">Stop services</button>
      <button id="cleanLocal" class="bad">Clean + stop</button>
    </div>
  </div>
  <div class="card">
    <div class="title">Analyze Source</div>
    <textarea id="sourceBox" placeholder="Paste cached/source text here"></textarea>
    <div class="row" style="margin-top:8px"><button id="analyze" class="primary">Analyze</button><button id="normalize">Normalize</button></div>
  </div>
  <div class="card">
    <div class="title">Remote Contract Analyzer</div>
    <textarea id="remoteBox" placeholder="Paste RemoteSpy copied logs here"></textarea>
    <div class="row" style="margin-top:8px"><button id="remoteAnalyze" class="primary">Analyze Remotes</button></div>
  </div>
</aside>
<section>
  <div class="toolbar">
    <input id="query" placeholder="Search helper index: remote name, require, path, identifier">
    <button id="search" class="primary">Search</button>
    <button id="script">Open /script</button>
  </div>
  <div class="tabs">
    <button class="tab active" data-view="resultsView">Results</button>
    <button class="tab" data-view="analysisView">Analysis</button>
    <button class="tab" data-view="remoteView">Remotes</button>
    <button class="tab" data-view="helpView">First run guide</button>
  </div>
  <div id="resultsView" class="searchWorkspace">
    <div id="resultList" class="resultList">
      <div class="resultSummary">Search waits for an index</div>
      <div class="hit"><div class="meta">Run DEX in Roblox, open Search Center, then use Index Scripts.</div></div>
    </div>
    <div id="resultInspector" class="resultInspector">
      <div class="emptyInspector">Select a script to preview its source and use quick actions.</div>
    </div>
  </div>
  <div id="analysisView" class="results hidden"><div class="hit"><h3>No analysis yet</h3><pre id="analysisOut">Paste source and click Analyze or Normalize.</pre></div></div>
  <div id="remoteView" class="results hidden"><div class="hit"><h3>No remote analysis yet</h3><pre>Paste RemoteSpy logs and click Analyze Remotes.</pre></div></div>
  <div id="helpView" class="results hidden">
    <div class="hit"><h3>First run guide</h3>
      <div class="steps">
        <div class="step"><b>1</b><div>Start <code>DEX_Helper.exe</code>. The top-left status should say active and Script delivery should say ready.</div></div>
        <div class="step"><b>2</b><div>Copy the loadstring from the sidebar and run it in Roblox. The Roblox session card should switch from waiting to connected.</div></div>
        <div class="step"><b>3</b><div>Open <code>Search Center</code> in DEX. Keep <code>Low ON</code> for smooth sessions, or use Full only when you can tolerate stutter.</div></div>
        <div class="step"><b>4</b><div>Press <code>Index</code>. This dashboard will show the exact game, progress, cached scripts, failed scripts, and helper index size.</div></div>
        <div class="step"><b>5</b><div>Search here after the index has source. This keeps browsing, ranking, and analysis outside the Roblox UI.</div></div>
      </div>
    </div>
  </div>
</section>
</main>
<script>
const $=id=>document.getElementById(id);
const fmt=n=>Number(n||0).toLocaleString();
function setStatus(text, cls){const p=$('statusPill');p.textContent=text;p.className='pill '+(cls||'')}
async function textFetch(path, opts={}){const r=await fetch(path,opts);const t=await r.text();if(!r.ok)throw new Error(t||r.statusText);return t}
async function refreshStatus(){try{await textFetch('/status');setStatus('active','ok');const raw=await textFetch('/index-status');const j=JSON.parse(raw);$('scripts').textContent=fmt(j.scripts);$('bytes').textContent=fmt(j.bytes)}catch(e){setStatus('offline','bad')}}
async function refreshScriptStatus(){try{const raw=await textFetch('/script-status');const j=JSON.parse(raw);const ok=!!j.ok;$('scriptDot').className='dot '+(ok?'ok':'bad');$('scriptPill').textContent=ok?'script ready':'script missing';$('scriptPill').className='pill '+(ok?'ok':'bad');$('scriptStatus').textContent=ok?`/script is ready (${fmt(j.bytes)} bytes from ${j.file}).`:'DEX++_compiled.luau was not found. Run python .\\build.py first.'}catch(e){$('scriptDot').className='dot bad';$('scriptPill').textContent='script error';$('scriptPill').className='pill bad';$('scriptStatus').textContent=e.message}}
async function refreshWorkers(){try{const raw=await textFetch('/worker-status');const j=JSON.parse(raw);const roles=j.roles||[];$('workerRoles').innerHTML=roles.map(r=>`<div class="stateRow"><b>${esc(r.language)} <span class="${r.ready?'ok':'warn'}" style="display:inline">${r.ready?'ready':'source only'}</span></b><span>${esc(r.role||'')}</span></div>`).join('')||'<div class="stateRow"><b>No workers reported</b><span>Helper did not return role data.</span></div>'}catch(e){$('workerRoles').innerHTML='<div class="stateRow"><b class="bad">Worker status failed</b><span>'+esc(e.message)+'</span></div>'}}
async function refreshToolchain(){try{const raw=await textFetch('/toolchain-status');const j=JSON.parse(raw);const tools=j.tools||{};const labels={python:'Python',cargo:'Cargo / Rust',gpp:'g++',winget:'winget',rustWorker:'Rust worker'};$('toolchainStatus').innerHTML=Object.entries(tools).map(([id,t])=>`<div class="stateRow"><b>${esc(labels[id]||id)} <span class="${t.available?'ok':'warn'}" style="display:inline">${t.available?'available':'missing'}</span></b><span>${esc(t.purpose||'')}</span></div>`).join('');$('openToolchainSetup').disabled=!j.setupAvailable;$('openToolchainSetup').textContent=j.setupAvailable?'Install / update tools':'Setup utility not built'}catch(e){$('toolchainStatus').innerHTML='<div class="stateRow"><b class="bad">Toolchain check failed</b><span>'+esc(e.message)+'</span></div>'}}
function pct(v){const n=Math.max(0,Math.min(1,Number(v||0)));return Math.round(n*100)}
function ago(ts){const n=Number(ts||0);if(!n)return 'never';const d=Math.max(0,Date.now()/1000-n);if(d<3)return 'now';if(d<60)return `${Math.floor(d)}s ago`;if(d<3600)return `${Math.floor(d/60)}m ago`;return `${Math.floor(d/3600)}h ago`}
function toolLine(name,t){const progress=t.Progress!==undefined?pct(t.Progress):null;const cls=t.Load==='high'?'bad':(t.Load==='medium'||t.Load==='variable'?'warn':'ok');let meta=`${t.State||'unknown'} | load ${t.Load||'n/a'} | updated ${ago(t.UpdatedWallAt||0)}`;if(t.Total!==undefined)meta+=` | ${progress}% | ${fmt(t.Cached)} cached | ${fmt(t.Decompiled)} new | ${fmt(t.Skipped)} skipped | ${fmt(t.Failed)} failed`;else if(name==='Remote Spy')meta+=` | ${fmt(t.Remotes)} remotes | ${fmt(t.Logs)} logs | ${fmt(t.Dropped)} dropped`;else if(name==='Property Tracker')meta+=` | ${fmt(t.Tracked)} objects | ${fmt(t.Properties)} props | ${fmt(t.Logs)} logs`;else if(name==='Thread Manager')meta+=` | ${fmt(t.Scripts)} scripts | ${fmt(t.Threads)} threads`;return `<div class="stateRow"><b>${esc(name)} <span class="${cls}" style="display:inline">${esc(t.State||'')}</span></b><span>${esc(meta)}</span>${progress!==null?`<div class="bar"><i style="width:${progress}%"></i></div>`:''}</div>`}
function updateSession(j){const game=j.game||{};const session=j.session||{};const connected=session.state==='connected'||Object.keys(j.tools||{}).length>0;$('dexDot').className='dot '+(connected?'ok':'warn');$('dexPill').textContent=connected?'Roblox connected':'Roblox waiting';$('dexPill').className='pill '+(connected?'ok':'warn');$('gameName').textContent=game.Name||'Waiting for DEX';$('gameMeta').textContent=game.PlaceId?`Place ${game.PlaceId} | Game ${game.GameId||'?'} | Job ${game.JobId||'?'} | ${session.executor||'executor unknown'}`:'Run the loadstring in Roblox to connect this dashboard.';const cs=(j.tools||{})['Code Search'];if(cs&&cs.State){const progress=cs.Progress!==undefined?` ${pct(cs.Progress)}%`:'';$('indexTarget').textContent=`Code Search: ${cs.State}${progress}`;$('indexMeta').textContent=`${fmt(cs.Cached)} cached | ${fmt(cs.Decompiled)} new | ${fmt(cs.Skipped)} skipped | ${fmt(cs.Failed)} failed | helper ${fmt(cs.HelperIndexed)}`}else{$('indexTarget').textContent='No active index';$('indexMeta').textContent='Code Search > Index Scripts will show progress here.'}}
async function refreshToolState(){try{const raw=await textFetch('/tool-state');const j=JSON.parse(raw);updateSession(j);const tools=j.tools||{};const names=Object.keys(tools).sort((a,b)=>Number(tools[b].UpdatedAt||0)-Number(tools[a].UpdatedAt||0));$('liveDex').innerHTML=names.length?names.slice(0,6).map(n=>toolLine(n,tools[n]||{})).join(''):'<div class="stateRow"><b>No live tool state</b><span>DEX has not reported yet.</span></div>'}catch(e){$('liveDex').innerHTML='<div class="stateRow"><b class="bad">Live state unavailable</b><span>'+esc(e.message)+'</span></div>'}}
function show(view){document.querySelectorAll('.tab').forEach(b=>b.classList.toggle('active',b.dataset.view===view));['resultsView','analysisView','remoteView','helpView'].forEach(id=>$(id).classList.toggle('hidden',id!==view))}
let searchResults=[];
let selectedResultKey='';
function resultItemHtml(item){const active=item.key===selectedResultKey?' active':'';return `<button class="resultItem${active}" data-result-key="${esc(item.key||'')}"><h3>${esc(item.name||item.key||'script')} <span class="muted">[${esc(item.className||'')}]</span></h3><div class="meta">${esc(item.path||'')}</div><div class="meta">${esc(item.matchType||'hit')} | score ${esc(item.score||0)} | confidence ${Math.round(Number(item.confidence||0)*100)}%</div></button>`}
function renderResultList(total){$('resultList').innerHTML=`<div class="resultSummary">${fmt(total)} result${Number(total)===1?'':'s'} | ${fmt(searchResults.length)} shown</div>`+(searchResults.map(resultItemHtml).join('')||'<div class="hit"><h3>No results</h3><div class="meta">Try a path, remote name, require target, or identifier.</div></div>');document.querySelectorAll('[data-result-key]').forEach(button=>button.onclick=()=>selectResult(button.dataset.resultKey))}
async function copyText(text,button,label){try{await navigator.clipboard.writeText(text);button.textContent='Copied';setTimeout(()=>button.textContent=label,900)}catch(e){button.textContent='Copy failed';setTimeout(()=>button.textContent=label,900)}}
async function selectResult(key){selectedResultKey=key;renderResultList(searchResults.length);const item=searchResults.find(entry=>entry.key===key);if(!item)return;$('resultInspector').innerHTML=`<div class="inspectorHead"><h2>${esc(item.name||item.key)}</h2><div class="meta">${esc(item.path||'')}</div></div><div class="inspectorActions"><button disabled>Loading source...</button></div><div class="emptyInspector">Reading the indexed script.</div>`;try{const raw=await textFetch('/index-entry',{method:'POST',headers:{'Content-Type':'text/plain'},body:key});const entry=JSON.parse(raw);if(!entry.ok)throw new Error(entry.error||'Script unavailable');$('resultInspector').innerHTML=`<div class="inspectorHead"><h2>${esc(entry.name||entry.key)} <span class="muted">[${esc(entry.className||'')}]</span></h2><div class="meta">${esc(entry.path||'')}</div></div><div class="inspectorActions"><button id="copyResultPath">Copy path</button><button id="copyResultSource" class="primary">Copy source</button><button id="analyzeResult">Analyze</button><span id="resultActionStatus" class="actionStatus">${fmt((entry.source||'').length)} chars</span></div><pre class="sourcePreview">${esc(entry.source||'-- Empty source')}</pre>`;$('copyResultPath').onclick=event=>copyText(entry.path||'',event.currentTarget,'Copy path');$('copyResultSource').onclick=event=>copyText(entry.source||'',event.currentTarget,'Copy source');$('analyzeResult').onclick=()=>{show('analysisView');$('sourceBox').value=entry.source||'';$('analyze').click()}}catch(e){$('resultInspector').innerHTML=`<div class="emptyInspector"><div><b class="bad">Could not load script</b><br>${esc(e.message)}</div></div>`}}
function remoteHtml(item){const methods=Object.entries(item.methods||{}).map(([k,v])=>`${k}:${v}`).join(' ');const flags=(item.flags||[]).join(', ')||'none';const samples=(item.samples||[]).map(s=>`- ${s}`).join('\n');return `<div class="hit"><h3>${esc(item.path)} <span class="${Number(item.risk||0)>0?'warn':'ok'}">risk ${esc(item.risk||0)}</span></h3><div class="meta">calls ${esc(item.calls||0)} | out ${esc(item.outgoing||0)} | in ${esc(item.incoming||0)} | ${esc(methods)}</div><div class="meta">flags: ${esc(flags)}</div><pre>${esc(samples||'no args sample')}</pre></div>`}
function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
$('refresh').onclick=refreshStatus;
$('copyLoadstring').onclick=async()=>{const text=$('loadstringBox').textContent;try{await navigator.clipboard.writeText(text);$('copyLoadstring').textContent='Copied';setTimeout(()=>$('copyLoadstring').textContent='Copy loadstring',900)}catch(e){$('copyLoadstring').textContent='Copy failed';setTimeout(()=>$('copyLoadstring').textContent='Copy loadstring',900)}};
$('openScript').onclick=()=>window.open('/script','_blank');
$('openToolchainSetup').onclick=async()=>{try{const raw=await textFetch('/open-toolchain-setup',{method:'POST'});const j=JSON.parse(raw);if(!j.ok)throw new Error(j.error||'Setup launch failed');$('openToolchainSetup').textContent='Setup opened';setTimeout(refreshToolchain,1200)}catch(e){$('openToolchainSetup').textContent='Open failed';setTimeout(()=>$('openToolchainSetup').textContent='Install / update tools',1200)}};
$('stopLocal').onclick=async()=>{if(!confirm('Stop DEX++ Helper and Potassium Decompiler?'))return;try{await textFetch('/stop-local-services',{method:'POST'});$('stopLocal').textContent='Stopping...';setStatus('stopping','warn')}catch(e){$('stopLocal').textContent='Stop failed'}};
$('cleanLocal').onclick=async()=>{if(!confirm('Delete helper index and logs, then stop local services? DEX source cache inside the executor workspace is not deleted.'))return;try{await textFetch('/clean-local',{method:'POST'});$('cleanLocal').textContent='Cleaning...';setStatus('cleaning','warn')}catch(e){$('cleanLocal').textContent='Clean failed'}};
$('load').onclick=async()=>{await textFetch('/index-load',{method:'POST'});refreshStatus()};
$('save').onclick=async()=>{await textFetch('/index-save',{method:'POST'});refreshStatus()};
$('clear').onclick=async()=>{if(confirm('Clear helper index?')){await textFetch('/index-clear',{method:'POST'});refreshStatus();searchResults=[];selectedResultKey='';renderResultList(0);$('resultInspector').innerHTML='<div class="emptyInspector">Index cleared.</div>'}};
$('search').onclick=async()=>{const q=$('query').value.trim();if(!q)return;show('resultsView');searchResults=[];selectedResultKey='';$('resultList').innerHTML='<div class="resultSummary">Searching...</div>';$('resultInspector').innerHTML='<div class="emptyInspector">Results will open here without moving the guide or page layout.</div>';try{const raw=await textFetch('/search-source',{method:'POST',headers:{'Content-Type':'text/plain'},body:'120\n'+q});const j=JSON.parse(raw);searchResults=j.results||[];renderResultList(j.total||searchResults.length);if(searchResults.length)selectResult(searchResults[0].key);refreshStatus()}catch(e){$('resultList').innerHTML='<div class="hit"><h3 class="bad">Search failed</h3><pre>'+esc(e.message)+'</pre></div>'}};
$('query').addEventListener('keydown',e=>{if(e.key==='Enter')$('search').click()});
$('analyze').onclick=async()=>{show('analysisView');try{$('analysisOut').textContent=await textFetch('/analyze-source-auto',{method:'POST',headers:{'Content-Type':'text/plain'},body:$('sourceBox').value})}catch(e){$('analysisOut').textContent=e.message}};
$('normalize').onclick=async()=>{show('analysisView');try{$('analysisOut').textContent=await textFetch('/normalize-source',{method:'POST',headers:{'Content-Type':'text/plain'},body:$('sourceBox').value})}catch(e){$('analysisOut').textContent=e.message}};
$('remoteAnalyze').onclick=async()=>{show('remoteView');$('remoteView').innerHTML='<div class="hit"><h3>Analyzing remotes...</h3></div>';try{const raw=await textFetch('/analyze-remotes',{method:'POST',headers:{'Content-Type':'text/plain'},body:$('remoteBox').value});const j=JSON.parse(raw);const head=`<div class="hit"><h3>Remote Contract Summary</h3><div class="meta">lines ${esc(j.lines||0)} | parsed ${esc(j.parsed||0)} | remotes ${esc(j.remotes||0)}</div></div>`;$('remoteView').innerHTML=head+((j.results||[]).map(remoteHtml).join('')||'<div class="hit"><h3>No RemoteSpy lines parsed</h3></div>')}catch(e){$('remoteView').innerHTML='<div class="hit"><h3 class="bad">Remote analysis failed</h3><pre>'+esc(e.message)+'</pre></div>'}};
$('script').onclick=()=>window.open('/script','_blank');
document.querySelectorAll('.tab').forEach(b=>b.onclick=()=>show(b.dataset.view));
refreshStatus();
refreshScriptStatus();
refreshWorkers();
refreshToolchain();
refreshToolState();
setInterval(refreshScriptStatus,5000);
setInterval(refreshWorkers,5000);
setInterval(refreshToolchain,10000);
setInterval(refreshToolState,1000);
</script>
</body>
</html>)DEXAPP";
}

// Check and auto-launch Potassium Decompiler if not running
void ensure_decompiler_running() {
    struct addrinfo* result = NULL;
    struct addrinfo hints;
    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    int iResult = getaddrinfo("::1", "56535", &hints, &result);
    if (iResult != 0) {
        iResult = getaddrinfo("127.0.0.1", "56535", &hints, &result);
    }
    if (iResult == 0) {
        SOCKET ConnectSocket = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
        if (ConnectSocket != INVALID_SOCKET) {
            iResult = connect(ConnectSocket, result->ai_addr, (int)result->ai_addrlen);
            if (iResult != SOCKET_ERROR) {
                closesocket(ConnectSocket);
                freeaddrinfo(result);
                return; // Already running!
            }
            closesocket(ConnectSocket);
        }
        freeaddrinfo(result);
    }

    std::cout << "[Decompiler] Potassium Decompiler is offline. Launching Decompiler.exe..." << std::endl;
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    const char* path = "D:\\Exploiter\\Potassium\\bin\\Decompiler.exe";
    const char* dir = "D:\\Exploiter\\Potassium\\bin";

    BOOL success = CreateProcessA(
        path,
        NULL,
        NULL,
        NULL,
        FALSE,
        CREATE_NO_WINDOW,
        NULL,
        dir,
        &si,
        &pi
    );

    if (success) {
        std::cout << "[Decompiler] Successfully launched Decompiler.exe (PID: " << pi.dwProcessId << ")" << std::endl;
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        std::this_thread::sleep_for(std::chrono::milliseconds(1000)); // Wait for server to bind
    } else {
        std::cerr << "[Decompiler] Failed to launch Decompiler.exe. Error code: " << GetLastError() << std::endl;
    }
}

// Proxies decompile request to local Rust luau-lifter server
std::string decompile_bytecode(const std::string& bytecode) {
    if (bytecode.empty()) {
        return "-- Decompile failed: empty bytecode payload.";
    }

    ensure_decompiler_running();

    std::string boundary = "----DarkDexHelperBoundary";
    
    // Construct the multipart body
    std::string body;
    body += "--" + boundary + "\r\n";
    body += "Content-Disposition: form-data; name=\"bytecode\"; filename=\"script.luac\"\r\n";
    body += "Content-Type: application/octet-stream\r\n\r\n";
    body += bytecode;
    body += "\r\n--" + boundary + "--\r\n";

    // Construct the HTTP headers
    std::stringstream request;
    request << "POST /decompile HTTP/1.1\r\n"
            << "Host: [::1]:56535\r\n"
            << "Content-Type: multipart/form-data; boundary=" << boundary << "\r\n"
            << "Content-Length: " << body.length() << "\r\n"
            << "Connection: close\r\n\r\n"
            << body;

    std::string request_str = request.str();

    // Setup connection
    struct addrinfo* result = NULL;
    struct addrinfo hints;
    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    int iResult = getaddrinfo("::1", "56535", &hints, &result);
    if (iResult != 0) {
        iResult = getaddrinfo("127.0.0.1", "56535", &hints, &result);
    }
    if (iResult != 0) {
        return "-- Error: getaddrinfo failed for decompiler server.";
    }

    SOCKET ConnectSocket = INVALID_SOCKET;
    for (struct addrinfo* ptr = result; ptr != NULL; ptr = ptr->ai_next) {
        ConnectSocket = socket(ptr->ai_family, ptr->ai_socktype, ptr->ai_protocol);
        if (ConnectSocket == INVALID_SOCKET) {
            continue;
        }

        iResult = connect(ConnectSocket, ptr->ai_addr, (int)ptr->ai_addrlen);
        if (iResult == SOCKET_ERROR) {
            closesocket(ConnectSocket);
            ConnectSocket = INVALID_SOCKET;
            continue;
        }
        break;
    }

    freeaddrinfo(result);

    if (ConnectSocket == INVALID_SOCKET) {
        return "-- Error: Could not connect to Potassium Decompiler server (port 56535).";
    }

    // Send the request
    size_t total_sent = 0;
    while (total_sent < request_str.size()) {
        int bytes_sent = send(
            ConnectSocket,
            request_str.data() + total_sent,
            static_cast<int>(std::min<size_t>(request_str.size() - total_sent, INT_MAX)),
            0
        );
        if (bytes_sent == SOCKET_ERROR || bytes_sent == 0) {
            closesocket(ConnectSocket);
            return "-- Decompile failed: incomplete request send to Potassium Decompiler.";
        }
        total_sent += static_cast<size_t>(bytes_sent);
    }

    // Read the response
    std::string response;
    char recvbuf[BUFFER_SIZE];
    int bytes_received;
    do {
        bytes_received = recv(ConnectSocket, recvbuf, BUFFER_SIZE, 0);
        if (bytes_received > 0) {
            response.append(recvbuf, bytes_received);
        }
    } while (bytes_received > 0);

    closesocket(ConnectSocket);

    // Parse the HTTP response body
    size_t header_end = response.find("\r\n\r\n");
    if (header_end == std::string::npos) {
        return "-- Error: Invalid HTTP response from Decompiler.";
    }

    // Check status code
    std::string status_line = response.substr(0, response.find("\r\n"));
    if (status_line.find("200") == std::string::npos) {
        return "-- Error: Decompiler server returned non-200 status:\n-- " + status_line;
    }

    std::string response_body = response.substr(header_end + 4);
    if (trim_copy(response_body).empty()) {
        return "-- Decompile failed: Potassium Decompiler returned an empty response.";
    }
    return response_body;
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

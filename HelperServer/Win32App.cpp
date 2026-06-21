#include "Win32App.h"
#include "Index.h"
#include "Toolchain.h"

// Define global application control variables
std::atomic<bool> g_shutdown_requested{false};
std::atomic<bool> g_dashboard_started{false};
std::atomic<bool> g_dashboard_ready{false};
HWND g_dashboard_host = NULL;
HWND g_dashboard_view = NULL;
HANDLE g_dashboard_browser_process = NULL;
HANDLE g_dashboard_browser_job = NULL;
DWORD g_dashboard_browser_pid = 0;
const int DASHBOARD_TITLE_HEIGHT = 44;
const wchar_t* INSTANCE_MUTEX_NAME = L"Local\\DEXPlusPlusHelperServer_8080";
const wchar_t* DASHBOARD_URL = L"http://localhost:8080/";

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

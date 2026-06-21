#pragma once

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
#include <wininet.h>

#define DEFAULT_PORT "8080"
#define BUFFER_SIZE 8192
#define MAX_HEADER_SIZE 32768
#define MAX_BODY_SIZE 5242880
#define MAX_LOG_BODY_SIZE 65536
#define MAX_LOG_FILE_SIZE 5242880
#define MAX_CLIENT_THREADS 16

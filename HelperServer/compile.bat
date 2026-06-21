@echo off
echo Compiling DEX++ Helper Server...
g++ -O3 -std=c++17 main.cpp Auth.cpp Win32App.cpp Index.cpp Toolchain.cpp Decompiler.cpp -o DEX_Helper.exe -lws2_32 -lshell32 -lgdi32 -lwininet
if %ERRORLEVEL% NEQ 0 (
    echo Compilation failed!
    exit /b %ERRORLEVEL%
)
echo Compilation successful: DEX_Helper.exe created.

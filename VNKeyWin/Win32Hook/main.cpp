// main.cpp
// VNKey — Windows low-level keyboard hook
//
// File này chứa entry point của ứng dụng Windows, đăng ký LowLevelKeyboardHook
// để bắt các phím bấm và tương tác với Engine Swift qua DLL.

#include <windows.h>
#include <iostream>
#include <string>
#include <vector>

// Định nghĩa con trỏ hàm đến DLL của Swift
typedef int32_t (*vnkey_process_fn)(const char*, int32_t, int32_t, char**);
typedef void (*vnkey_free_string_fn)(char*);
typedef int32_t (*vnkey_calculate_backspace_fn)(const char*, const char*, char**);

vnkey_process_fn vnkey_process = nullptr;
vnkey_free_string_fn vnkey_free_string = nullptr;
vnkey_calculate_backspace_fn vnkey_calculate_backspace = nullptr;

HHOOK hKeyboardHook = NULL;
std::string rawBuffer = "";
std::string processedBuffer = "";

// Cài đặt mặc định: 0 = Telex, 1 = VNI
int32_t g_method = 0; 
int32_t g_toneStyle = 0; // 0 = Old Style, 1 = New Style

// Load DLL Swift Engine
bool LoadEngineDLL() {
    HMODULE hDll = LoadLibraryA("VNKeyEngine.dll");
    if (!hDll) {
        std::cerr << "Failed to load VNKeyEngine.dll. Error: " << GetLastError() << std::endl;
        return false;
    }
    
    vnkey_process = (vnkey_process_fn)GetProcAddress(hDll, "vnkey_process");
    vnkey_free_string = (vnkey_free_string_fn)GetProcAddress(hDll, "vnkey_free_string");
    vnkey_calculate_backspace = (vnkey_calculate_backspace_fn)GetProcAddress(hDll, "vnkey_calculate_backspace");
    
    return vnkey_process && vnkey_free_string && vnkey_calculate_backspace;
}

// Gửi phím Backspace hoặc ký tự Unicode
void SendKeyEvents(int backspaceCount, const std::string& insertText) {
    std::vector<INPUT> inputs;
    
    // 1. Gửi phím Backspace để xóa ký tự thừa
    for (int i = 0; i < backspaceCount; ++i) {
        INPUT ipDown = { 0 };
        ipDown.type = INPUT_KEYBOARD;
        ipDown.ki.wVk = VK_BACK;
        
        INPUT ipUp = { 0 };
        ipUp.type = INPUT_KEYBOARD;
        ipUp.ki.wVk = VK_BACK;
        ipUp.ki.dwFlags = KEYEVENTF_KEYUP;
        
        inputs.push_back(ipDown);
        inputs.push_back(ipUp);
    }
    
    // 2. Chuyển đổi UTF-8 sang UTF-16 wchar_t để gửi sự kiện Unicode
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &insertText[0], (int)insertText.size(), NULL, 0);
    std::wstring wstr(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, &insertText[0], (int)insertText.size(), &wstr[0], size_needed);
    
    for (wchar_t wc : wstr) {
        INPUT ipDown = { 0 };
        ipDown.type = INPUT_KEYBOARD;
        ipDown.ki.wVk = 0;
        ipDown.ki.wScan = wc;
        ipDown.ki.dwFlags = KEYEVENTF_UNICODE;
        
        INPUT ipUp = { 0 };
        ipUp.type = INPUT_KEYBOARD;
        ipUp.ki.wVk = 0;
        ipUp.ki.wScan = wc;
        ipUp.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
        
        inputs.push_back(ipDown);
        inputs.push_back(ipUp);
    }
    
    if (!inputs.empty()) {
        SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));
    }
}

// Kiểm tra ký tự chữ cái Latin thông thường
bool IsWordCharacter(char c) {
    c = tolower(c);
    return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');
}

// Hook callback xử lý phím bấm
LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode >= 0 && wParam == WM_KEYDOWN) {
        KBDLLHOOKSTRUCT* pKey = (KBDLLHOOKSTRUCT*)lParam;
        DWORD vkCode = pKey->vkCode;
        
        // Nhấn Backspace -> giảm độ dài từ đang gõ
        if (vkCode == VK_BACK) {
            if (!rawBuffer.empty()) {
                rawBuffer.pop_back();
            }
            processedBuffer.clear();
            rawBuffer.clear();
            return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);
        }
        
        // Nhấn phím trắng/xuống dòng/tab/escape -> hoàn tất từ hiện tại
        if (vkCode == VK_SPACE || vkCode == VK_RETURN || vkCode == VK_TAB || vkCode == VK_ESCAPE) {
            rawBuffer.clear();
            processedBuffer.clear();
            return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);
        }
        
        // Lấy ký tự ASCII từ phím vừa bấm
        BYTE keyboardState[256];
        GetKeyboardState(keyboardState);
        WCHAR wch[10];
        int res = ToUnicode(vkCode, pKey->scanCode, keyboardState, wch, 10, 0);
        
        if (res == 1) {
            char c = (char)wch[0];
            if (IsWordCharacter(c)) {
                rawBuffer += c;
                
                char* outProcessed = nullptr;
                int32_t transformed = vnkey_process(rawBuffer.c_str(), g_method, g_toneStyle, &outProcessed);
                
                if (outProcessed) {
                    std::string newProcessed(outProcessed);
                    vnkey_free_string(outProcessed);
                    
                    std::string currentDisplay = processedBuffer + c;
                    
                    char* outInsert = nullptr;
                    int32_t backspaceCount = vnkey_calculate_backspace(currentDisplay.c_str(), newProcessed.c_str(), &outInsert);
                    
                    std::string insertText = "";
                    if (outInsert) {
                        insertText = std::string(outInsert);
                        vnkey_free_string(outInsert);
                    }
                    
                    // Nếu có sự biến đổi ký tự (diacritics/tone) -> thực hiện giả lập phím
                    if (transformed && (backspaceCount > 0 || !insertText.empty())) {
                        SendKeyEvents(backspaceCount, insertText);
                        processedBuffer = newProcessed;
                        return 1; // Block phím thật, sử dụng phím giả lập thay thế
                    }
                    
                    processedBuffer = newProcessed;
                }
            } else {
                rawBuffer.clear();
                processedBuffer.clear();
            }
        }
    }
    return CallNextHookEx(hKeyboardHook, nCode, wParam, lParam);
}

int main() {
    std::cout << "Starting VNKey Windows Hook client..." << std::endl;
    
    if (!LoadEngineDLL()) {
        std::cerr << "Engine DLL load failed! Make sure VNKeyEngine.dll is in the same directory." << std::endl;
        return 1;
    }
    
    std::cout << "Engine DLL loaded successfully." << std::endl;
    
    hKeyboardHook = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandle(NULL), 0);
    if (!hKeyboardHook) {
        std::cerr << "Failed to register keyboard hook!" << std::endl;
        return 1;
    }
    
    std::cout << "Keyboard hook active. Press Ctrl+C to exit." << std::endl;
    
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    
    UnhookWindowsHookEx(hKeyboardHook);
    return 0;
}

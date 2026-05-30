#include "win32_window.h"

#include <flutter_windows.h>

#include <dwmapi.h>
#include <resource.h>

#include <algorithm>
#include <iostream>

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

LRESULT CALLBACK WndProc(HWND const window, UINT const message,
                         WPARAM const wparam,
                         LPARAM const lparam) noexcept {
  auto *window_instance =
      reinterpret_cast<Win32Window *>(::GetWindowLongPtr(window, GWLP_USERDATA));
  if (window_instance) {
    return window_instance->MessageHandler(window, message, wparam, lparam);
  }
  return ::DefWindowProc(window, message, wparam, lparam);
}

}  // namespace

Win32Window::Win32Window()
    : window_handle_(nullptr), child_content_(nullptr), quit_on_close_(false) {}

Win32Window::~Win32Window() { Destroy(); }

bool Win32Window::Create(const std::wstring &title, const Point &origin,
                          const Size &size) {
  Destroy();

  WNDCLASS window_class = {};
  window_class.hCursor = ::LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = kWindowClassName;
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.cbClsExtra = 0;
  window_class.cbWndExtra = 0;
  window_class.hInstance = ::GetModuleHandle(nullptr);
  window_class.hIcon =
      ::LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
  window_class.hbrBackground = 0;
  window_class.lpszMenuName = nullptr;
  window_class.lpfnWndProc = WndProc;

  if (!::RegisterClass(&window_class)) {
    return false;
  }

  DWORD style = WS_OVERLAPPEDWINDOW | WS_VISIBLE;
  DWORD ex_style = WS_EX_APPWINDOW;

  RECT rect = {static_cast<LONG>(origin.x), static_cast<LONG>(origin.y),
               static_cast<LONG>(origin.x + size.width),
               static_cast<LONG>(origin.y + size.height)};

  ::AdjustWindowRectEx(&rect, style, FALSE, ex_style);

  HWND window = ::CreateWindowEx(
      ex_style, kWindowClassName, title.c_str(), style, rect.left, rect.top,
      rect.right - rect.left, rect.bottom - rect.top, nullptr, nullptr,
      window_class.hInstance, this);

  if (window == nullptr) {
    return false;
  }

  ::SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(this));
  window_handle_ = window;

  // Enable dark title bar
  BOOL dark_mode = TRUE;
  DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark_mode,
                        sizeof(dark_mode));

  // Enable rounded corners
  DWM_WINDOW_CORNER_PREFERENCE corner = DWMWCP_ROUND;
  DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE, &corner,
                        sizeof(corner));

  return OnCreate();
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  ::SetParent(content, window_handle_);
  RECT frame = GetClientArea();
  ::SetWindowPos(content, nullptr, 0, 0, frame.right - frame.left,
                 frame.bottom - frame.top, SWP_NOZORDER);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  ::GetClientRect(window_handle_, &frame);
  return frame;
}

void Win32Window::Destroy() {
  OnDestroy();
  if (window_handle_) {
    ::DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  ::UnregisterClass(kWindowClassName, ::GetModuleHandle(nullptr));
}

bool Win32Window::OnCreate() { return true; }

void Win32Window::OnDestroy() {}

LRESULT Win32Window::MessageHandler(HWND hwnd, UINT const message,
                                     WPARAM const wparam,
                                     LPARAM const lparam) noexcept {
  switch (message) {
    case WM_WINDOWPOSCHANGED: {
      auto *window_pos = reinterpret_cast<WINDOWPOS *>(lparam);
      if (child_content_ && window_pos->flags & SWP_SHOWWINDOW) {
        ::SetWindowPos(child_content_, nullptr, 0, 0, window_pos->cx,
                       window_pos->cy, SWP_NOZORDER);
      }
      return 0;
    }
    case WM_SIZE: {
      if (child_content_) {
        RECT frame = GetClientArea();
        ::SetWindowPos(child_content_, nullptr, 0, 0,
                       frame.right - frame.left, frame.bottom - frame.top,
                       SWP_NOZORDER);
      }
      return 0;
    }
    case WM_CLOSE:
      if (quit_on_close_) {
        ::PostQuitMessage(0);
      }
      return 0;
    case WM_DESTROY:
      return 0;
  }
  return ::DefWindowProc(hwnd, message, wparam, lparam);
}

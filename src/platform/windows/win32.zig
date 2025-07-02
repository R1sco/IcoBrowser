const std = @import("std");

// Win32 API binding untuk Zig
// Ini adalah binding minimal untuk fungsi Windows API yang diperlukan

// Basic Windows types
pub const HWND = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HMENU = *opaque {};
pub const HICON = ?*opaque {};
pub const HCURSOR = ?*opaque {};
pub const HBRUSH = *opaque {};
pub const LPARAM = usize;
pub const WPARAM = usize;
pub const LRESULT = isize;
pub const DWORD = u32;
pub const WORD = u16;
pub const LONG = i32;
pub const UINT = c_uint;
pub const BOOL = i32;
pub const LPVOID = ?*anyopaque;
pub const HRESULT = i32;

// UTF-16 null-terminated wide string pointer types for Win32 API
pub const LPCWSTR = [*:0]const u16;
pub const LPWSTR  = [*:0]u16;

pub const TRUE = 1;
pub const FALSE = 0;

// Default value for window position
pub const CW_USEDEFAULT: c_int = -2147483648;

// Window class styles
pub const CS_VREDRAW: u32 = 0x0001;
pub const CS_HREDRAW: u32 = 0x0002;

// Window styles
pub const WS_OVERLAPPED = 0x00000000;
pub const WS_CAPTION = 0x00C00000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
pub const WS_VISIBLE = 0x10000000;

// Window and control styles
pub const WS_CHILD: u32 = 0x40000000;
pub const WS_BORDER: u32 = 0x00800000;
pub const ES_AUTOHSCROLL: u32 = 0x00000080;
pub const BS_PUSHBUTTON: u32 = 0x00000000;

// Common control class names for CreateWindowExW
pub const WC_BUTTONW: LPCWSTR = @ptrFromInt(0x0080);
pub const WC_EDITW:   LPCWSTR = @ptrFromInt(0x0081);

// Window messages
pub const WM_CREATE: u32 = 0x0001;

// PeekMessage constants
pub const PM_NOREMOVE: UINT = 0x0000;
pub const PM_REMOVE: UINT = 0x0001;
pub const PM_NOYIELD: UINT = 0x0002;
pub const WM_DESTROY: u32 = 0x0002;
pub const WM_SIZE: u32 = 0x0005;
pub const WM_CLOSE: u32 = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_COMMAND: u32 = 0x0111;

// COM initialization flags
pub const COINIT_APARTMENTTHREADED: u32 = 0x2;
pub const COINIT_MULTITHREADED: u32 = 0x0;
pub const COINIT_DISABLE_OLE1DDE: u32 = 0x4;
pub const COINIT_SPEED_OVER_MEMORY: u32 = 0x8;

// Window show commands
pub const SW_SHOW = 5;

// System color constants
pub const COLOR_WINDOW = 5;

// Rectangle structure
pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

// Point structure
pub const POINT = extern struct {
    x: LONG,
    y: LONG,
};

// Window class structure
pub const WNDCLASSEXW = extern struct {
    cbSize: UINT,
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int,
    cbWndExtra: c_int,
    hInstance: HINSTANCE,
    hIcon: HICON,
    hCursor: HCURSOR,
    hbrBackground: HBRUSH,
    lpszMenuName: ?LPCWSTR,
    lpszClassName: LPCWSTR,
    hIconSm: HICON,
};

// Window procedure callback type
pub const WNDPROC = *const fn (hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.C) LRESULT;

// Message structure
pub const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

// Win32 API functions
pub extern "user32" fn RegisterClassExW(lpwcx: *const WNDCLASSEXW) callconv(.C) WORD;
pub extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: LPCWSTR,
    lpWindowName: LPCWSTR,
    dwStyle: DWORD,
    X: c_int,
    Y: c_int,
    nWidth: c_int,
    nHeight: c_int,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: HINSTANCE,
    lpParam: LPVOID,
) callconv(.C) ?HWND;
pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: c_int) callconv(.C) BOOL;
pub extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.C) BOOL;
pub extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(.C) BOOL;
pub extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.C) BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.C) BOOL;
pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.C) LRESULT;
pub extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.C) LRESULT;
pub extern "user32" fn PostQuitMessage(nExitCode: c_int) callconv(.C) void;
pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.C) BOOL;
pub extern "user32" fn SetWindowTextW(hWnd: HWND, lpString: LPCWSTR) callconv(.C) BOOL;
pub extern "user32" fn GetWindowTextW(hWnd: HWND, lpString: LPWSTR, nMaxCount: c_int) callconv(.C) c_int;
pub extern "user32" fn DestroyWindow(hwnd: HWND) callconv(.C) BOOL;

pub extern "kernel32" fn GetModuleHandleW(lpModuleName: ?LPCWSTR) callconv(.C) HINSTANCE;
pub extern "kernel32" fn GetLastError() callconv(.C) DWORD;

// Cursor constants
pub const IDC_ARROW = @as(LPCWSTR, @ptrFromInt(32512));

// Cursor functions
pub extern "user32" fn LoadCursorW(hInstance: ?HINSTANCE, lpCursorName: LPCWSTR) callconv(.C) HCURSOR;

// Icon functions and defaults
pub const IDI_APPLICATION: LPCWSTR = @as(LPCWSTR, @ptrFromInt(32512));
pub extern "user32" fn LoadIconW(hInstance: ?HINSTANCE, lpIconName: LPCWSTR) callconv(.C) HICON;

// Helper functions untuk manipulasi WORD dan DWORD
pub inline fn LOWORD(dw: LPARAM) WORD {
    return @truncate(dw & 0xFFFF);
}

pub inline fn HIWORD(dw: LPARAM) WORD {
    return @truncate((dw >> 16) & 0xFFFF);
}

// Helper function untuk konversi string ke UTF-16
pub fn utf8ToUtf16Le(allocator: std.mem.Allocator, str: []const u8) ![:0]u16 {
    return std.unicode.utf8ToUtf16LeAllocZ(allocator, str);
}

// COM API functions
pub extern "ole32" fn CoInitializeEx(pvReserved: ?*anyopaque, dwCoInit: DWORD) callconv(.C) HRESULT;
pub extern "ole32" fn CoUninitialize() callconv(.C) void;

// COM Interface GUIDs and Structures
pub const GUID = extern struct {
    data1: u32,
    data2: u16,
    data3: u16,
    data4: [8]u8,
};

pub const IID_IUnknown = GUID{
    .data1 = 0x00000000,
    .data2 = 0x0000,
    .data3 = 0x0000,
    .data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
};

pub const IUnknownVtbl = extern struct {
    QueryInterface: *const fn (self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) callconv(.C) HRESULT,
    AddRef: *const fn (self: *IUnknown) callconv(.C) u32,
    Release: *const fn (self: *IUnknown) callconv(.C) u32,
};

pub const IUnknown = extern struct {
    vtable: *const IUnknownVtbl,
};

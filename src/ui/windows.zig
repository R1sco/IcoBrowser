const std = @import("std");
const win32 = @import("../platform/windows/win32.zig");
const webview2 = @import("../platform/windows/webview2.zig");
const browser_ui = @import("browser_ui.zig");
const theme = @import("theme.zig");
const security = @import("../security.zig");
const main_zig = @import("../main.zig"); // Untuk callback

var g_h_instance: win32.HINSTANCE = undefined;
var g_main_hwnd: ?win32.HWND = null;
var g_window_class_name: win32.LPCWSTR = undefined;
var g_allocator: std.mem.Allocator = undefined; // Ditambahkan

// Callback untuk event dari WebView2
var g_on_webview_navigation_completed: ?*const fn (success: bool, url: []const u8) void = null;
var g_on_webview_message_received: ?*const fn (message: []const u8) void = null;

// Window handles untuk UI controls
var hwnd_address_bar: ?win32.HWND = null;
var hwnd_go_button: ?win32.HWND = null;
var hwnd_back_button: ?win32.HWND = null;
var hwnd_forward_button: ?win32.HWND = null;
var hwnd_reload_button: ?win32.HWND = null;

// Fungsi untuk menjalankan message loop Windows
pub fn runMainLoop() !void {
    var msg: win32.MSG = undefined;
    
    // Standard Windows message loop
    while (win32.GetMessageW(&msg, null, 0, 0) != 0) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }
}

// Control IDs (integer command IDs)
const ID_ADDRESS_BAR: u16 = 101;
const ID_GO_BUTTON: u16 = 102;
const ID_BACK_BUTTON: u16 = 103;
const ID_FORWARD_BUTTON: u16 = 104;
const ID_RELOAD_BUTTON: u16 = 105;

const CONTROLS_AREA_HEIGHT = 70; // Total tinggi untuk area kontrol

// Constants for window creation
const WINDOW_TITLE = "IcoBrowser";
const WINDOW_WIDTH = 1024;
const WINDOW_HEIGHT = 768;
const WINDOW_CLASS_NAME = "IcoBrowserWindowClass";

// Variabel global allocator sudah ada sebagai g_allocator
// Variabel global main_window sudah ada sebagai g_main_hwnd

// Window procedure function
// This is the main message handling function for the window.
pub fn windowProc(
    hwnd: win32.HWND,
    msg: win32.UINT,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) callconv(.C) win32.LRESULT {




    switch (msg) {
        // TODO: Add message handling for UI controls (WM_COMMAND)
        // TODO: Handle window resizing (WM_SIZE) to resize WebView2
        // TODO: Handle window closing (WM_CLOSE, WM_DESTROY)

        else => {
            return win32.DefWindowProcW(hwnd, msg, wparam, lparam);
        }
    }
}


// Initialize Windows application
pub fn init(alloc_param: std.mem.Allocator) !void {
    // Default values untuk parameter yang tidak disediakan
    const h_instance_param = win32.GetModuleHandleW(null);
    const window_class_name_w = try std.unicode.utf8ToUtf16LeAllocZ(alloc_param, "IcoBrowserMainWindow");
    g_allocator = alloc_param;
    g_h_instance = h_instance_param;
    // Store UTF-16 null-terminated slice for Win32 class name
    g_window_class_name = window_class_name_w;

    // Get instance handle
    const hInstance = g_h_instance;
    if (@intFromPtr(hInstance) == 0) {
        return error.FailedToGetModuleHandle;
    }

    // Register window class
    _ = try registerWindowClass(hInstance);

    // Create window title in UTF-16
    const title_w = try win32.utf8ToUtf16Le(g_allocator, WINDOW_TITLE);
    defer g_allocator.free(title_w);

    // g_window_class_name (yang merupakan [*:0]const u16 akan digunakan untuk CreateWindowExW.
    // Tidak perlu konversi lokal dari WINDOW_CLASS_NAME (const u8 di sini.

    // Create window
    const hwnd = win32.CreateWindowExW(
        0, // Extended style
        g_window_class_name, // Class name
        title_w.ptr, // Window title
        win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE, // Style
        win32.CW_USEDEFAULT, // X position
        win32.CW_USEDEFAULT, // Y position
        WINDOW_WIDTH, // Width
        WINDOW_HEIGHT, // Height
        null, // Parent window
        null, // Menu
        hInstance, // Instance
        null, // Additional data
    );

    if (@intFromPtr(hwnd) == 0) {
        return error.FailedToCreateWindow;
    }

    g_main_hwnd = hwnd;

    // Initialize WebView2
    if (hwnd) |h| {
        try webview2.WebView2.initialize(h, g_allocator);
    } else {
        std.debug.print("Main window handle is null, cannot initialize WebView2\n", .{});
        return error.InvalidHandle;
    }

    // Set navigation completed callback
    webview2.WebView2.setNavigationCompletedCallback(browser_ui.handleNavigationCompleted);

    // Initialize browser UI
    try browser_ui.initialize(g_allocator);

    // Initialize theme
    try theme.initialize(g_allocator);

    // Create address bar and navigation buttons
    browser_ui.createAddressBarAndNavigationButtons(hwnd);

    // Show window
    _ = win32.ShowWindow(hwnd.?, win32.SW_SHOW);
    _ = win32.UpdateWindow(hwnd.?);

    // ...
}

pub fn registerWindowClass(hInstance: win32.HINSTANCE) !win32.WORD {
    var wc = win32.WNDCLASSEXW{
        .cbSize = @sizeOf(win32.WNDCLASSEXW),
        .style = win32.CS_HREDRAW | win32.CS_VREDRAW,
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hInstance,
        .hIcon = @as(win32.HICON, @ptrFromInt(0)),
        .hCursor = win32.LoadCursorW(null, win32.IDC_ARROW),
        .hbrBackground = @ptrFromInt(@as(usize, win32.COLOR_WINDOW + 1)),
        .lpszMenuName = null,
        .lpszClassName = g_window_class_name,
        .hIconSm = @as(win32.HICON, @ptrFromInt(0)),
    };
    const atom = win32.RegisterClassExW(&wc);
    if (atom == 0) return error.FailedToRegisterClass;
    return atom;
}

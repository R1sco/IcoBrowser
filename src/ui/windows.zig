const std = @import("std");
const win32 = @import("../platform/windows/win32.zig");
const webview2 = @import("../platform/windows/webview2.zig");
const browser_ui = @import("browser_ui.zig");
const theme = @import("theme.zig");
const security = @import("../security.zig");
const main_zig = @import("../main.zig"); // Untuk callback

var g_h_instance: win32.HINSTANCE = undefined;
var g_main_hwnd: ?win32.HWND = null;
pub var g_window_class_name: win32.LPCWSTR = undefined;
pub var g_allocator: std.mem.Allocator = undefined; // Ditambahkan

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
    
    std.debug.print("Entering Windows message loop\n", .{});
    
    // Pastikan WebView2 sudah diinisialisasi sebelum menjalankan message loop
    if (webview2.isInitialized()) {
        std.debug.print("WebView2 is initialized before entering message loop\n", .{});
    } else {
        std.debug.print("WARNING: WebView2 is NOT initialized before entering message loop!\n", .{});
    }
    
    // Pastikan window handle valid
    if (g_main_hwnd) |hwnd| {
        std.debug.print("Main window handle is valid: {any}\n", .{hwnd});
        
        // Coba tampilkan window lagi untuk memastikan
        _ = win32.ShowWindow(hwnd, win32.SW_SHOW);
        _ = win32.UpdateWindow(hwnd);
        std.debug.print("ShowWindow and UpdateWindow called again\n", .{});
    } else {
        std.debug.print("ERROR: Main window handle is null before message loop!\n", .{});
        return error.InvalidWindowHandle;
    }
    
    // Standard Windows message loop
    std.debug.print("Starting GetMessageW loop\n", .{});
    while (win32.GetMessageW(&msg, null, 0, 0) != 0) {
        std.debug.print("Message received: {d}\n", .{msg.message});
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }
    
    std.debug.print("Windows message loop exited\n", .{});
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
    std.debug.print("Window message received: {d}\n", .{msg});
    
    switch (msg) {
        // Handle window creation
        win32.WM_CREATE => {
            std.debug.print("Window created - WM_CREATE received\n", .{});
            
            // Pastikan WebView2 diinisialisasi setelah jendela dibuat
            std.debug.print("Initializing WebView2 from WM_CREATE handler\n", .{});
            webview2.initialize(g_allocator, hwnd) catch |err| {
                std.debug.print("ERROR initializing WebView2 from WM_CREATE: {s}\n", .{@errorName(err)});
                // Lanjutkan meskipun gagal, mungkin akan berhasil nanti
            };
            
            // Pastikan jendela ditampilkan
            _ = win32.ShowWindow(hwnd, win32.SW_SHOW);
            _ = win32.UpdateWindow(hwnd);
            std.debug.print("ShowWindow and UpdateWindow called from WM_CREATE\n", .{});
            
            return 0;
        },
        
        // Handle window resizing
        win32.WM_SIZE => {
            const lparam_val = @as(u32, @intCast(lparam));
            const width = @as(i32, @intCast(lparam_val & 0xFFFF));
            const height = @as(i32, @intCast((lparam_val >> 16) & 0xFFFF));
            std.debug.print("Window resized: {d}x{d}\n", .{width, height});
            
            // Resize WebView2 to match window size
            if (webview2.isInitialized()) {
                std.debug.print("Resizing WebView2 to match window size\n", .{});
                const resize_result = webview2.resizeWebView(width, height - CONTROLS_AREA_HEIGHT);
                if (resize_result != 0) {
                    std.debug.print("Failed to resize WebView2: {d}\n", .{resize_result});
                } else {
                    std.debug.print("Successfully resized WebView2\n", .{});
                }
            } else {
                std.debug.print("Cannot resize WebView2: not initialized yet\n", .{});
                
                // Coba inisialisasi WebView2 jika belum diinisialisasi
                std.debug.print("Attempting to initialize WebView2 from WM_SIZE handler\n", .{});
                webview2.initialize(g_allocator, hwnd) catch |err| {
                    std.debug.print("ERROR initializing WebView2 from WM_SIZE: {s}\n", .{@errorName(err)});
                };
            }
            return 0;
        },
        
        // Handle window closing
        win32.WM_CLOSE => {
            std.debug.print("Window closing\n", .{});
            _ = win32.DestroyWindow(hwnd);
            return 0;
        },
        
        // Handle window destruction
        win32.WM_DESTROY => {
            std.debug.print("Window destroyed\n", .{});
            win32.PostQuitMessage(0);
            return 0;
        },
        
        // Handle command messages (from buttons, etc.)
        win32.WM_COMMAND => {
            const control_id = @as(u16, @truncate(wparam & 0xFFFF));
            std.debug.print("Command received from control ID: {d}\n", .{control_id});
            
            switch (control_id) {
                // Handle address bar Go button
                ID_GO_BUTTON => {
                    std.debug.print("Go button clicked\n", .{});
                    browser_ui.navigateToAddressBar() catch |err| {
                        std.debug.print("Failed to navigate: {any}\n", .{err});
                    };
                    return 0;
                },
                
                // Handle back button
                ID_BACK_BUTTON => {
                    std.debug.print("Back button clicked\n", .{});
                    browser_ui.goBack() catch |err| {
                        std.debug.print("Failed to go back: {any}\n", .{err});
                    };
                    return 0;
                },
                
                // Handle forward button
                ID_FORWARD_BUTTON => {
                    std.debug.print("Forward button clicked\n", .{});
                    browser_ui.goForward() catch |err| {
                        std.debug.print("Failed to go forward: {any}\n", .{err});
                    };
                    return 0;
                },
                
                // Handle reload button
                ID_RELOAD_BUTTON => {
                    std.debug.print("Reload button clicked\n", .{});
                    browser_ui.reload() catch |err| {
                        std.debug.print("Failed to reload: {any}\n", .{err});
                    };
                    return 0;
                },
                
                else => {},
            }
        },
        
        else => {},
    }
    
    return win32.DefWindowProcW(hwnd, msg, wparam, lparam);
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
        std.debug.print("Attempting to initialize WebView2 with window handle: {any}\n", .{h});
        try webview2.initialize(g_allocator, h);
        std.debug.print("WebView2 initialization completed successfully\n", .{});
    } else {
        std.debug.print("Main window handle is null, cannot initialize WebView2\n", .{});
        return error.InvalidHandle;
    }

    // Set navigation completed callback
    webview2.setNavigationCompletedCallback(browser_ui.handleNavigationCompleted);

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

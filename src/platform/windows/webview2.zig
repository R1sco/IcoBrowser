const std = @import("std");
const win32 = @import("win32.zig");
const utf8ToUtf16Le = win32.utf8ToUtf16Le;

// Common Windows types
const HWND = win32.HWND;
const BOOL = win32.BOOL;
const RECT = win32.RECT;
const HRESULT = std.os.windows.HRESULT;
const GUID = std.os.windows.GUID;
const ULONG = u32;

// --- COM Interface Definitions ---
const IUnknown = @import("com.zig").IUnknown;
const WebView2Error = error{WebView2EnvironmentCreationFailed};

const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Invoke: *const fn (self: *ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler, result: HRESULT, created_environment: ?*ICoreWebView2Environment) callconv(.C) HRESULT,
    };
};

const ICoreWebView2CreateCoreWebView2ControllerCompletedHandler = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Invoke: *const fn (self: *ICoreWebView2CreateCoreWebView2ControllerCompletedHandler, result: HRESULT, controller: ?*ICoreWebView2Controller) callconv(.C) HRESULT,
    };
};

const ICoreWebView2NavigationCompletedEventArgs = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        get_IsSuccess: *const fn (self: *ICoreWebView2NavigationCompletedEventArgs, is_success: *BOOL) callconv(.C) HRESULT,
        get_WebErrorStatus: *const fn (self: *ICoreWebView2NavigationCompletedEventArgs, web_error_status: *win32.COREWEBVIEW2_WEB_ERROR_STATUS) callconv(.C) HRESULT,
        get_NavigationId: *const fn (self: *ICoreWebView2NavigationCompletedEventArgs, navigation_id: *u64) callconv(.C) HRESULT,
    };
};

const ICoreWebView2NavigationCompletedEventHandler = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        Invoke: *const fn (self: *ICoreWebView2NavigationCompletedEventHandler, sender: *ICoreWebView2, args: *ICoreWebView2NavigationCompletedEventArgs) callconv(.C) HRESULT,
    };
};

const ICoreWebView2Environment = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        CreateCoreWebView2Controller: *const fn (self: *ICoreWebView2Environment, parentWindow: HWND, handler: *ICoreWebView2CreateCoreWebView2ControllerCompletedHandler) callconv(.C) HRESULT,
        GetBrowserVersionString: *const fn(self: *ICoreWebView2Environment, versionInfo: *[*:0]u16) callconv(.C) HRESULT,
    };
};

const ICoreWebView2Controller = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        get_IsVisible: *const fn(self: *ICoreWebView2Controller, isVisible: *BOOL) callconv(.C) HRESULT,
        put_IsVisible: *const fn(self: *ICoreWebView2Controller, isVisible: BOOL) callconv(.C) HRESULT,
        get_Bounds: *const fn(self: *ICoreWebView2Controller, bounds: *RECT) callconv(.C) HRESULT,
        put_Bounds: *const fn(self: *ICoreWebView2Controller, bounds: RECT) callconv(.C) HRESULT,
        get_ZoomFactor: *const fn(self: *ICoreWebView2Controller, zoomFactor: *f64) callconv(.C) HRESULT,
        put_ZoomFactor: *const fn(self: *ICoreWebView2Controller, zoomFactor: f64) callconv(.C) HRESULT,
        add_ZoomFactorChanged: *const fn() callconv(.C) HRESULT, // Simplified
        remove_ZoomFactorChanged: *const fn() callconv(.C) HRESULT, // Simplified
        put_BoundsMode: *const fn() callconv(.C) HRESULT, // Simplified
        get_BoundsMode: *const fn() callconv(.C) HRESULT, // Simplified
        get_CoreWebView2: *const fn(self: *ICoreWebView2Controller, coreWebView2: **?*ICoreWebView2) callconv(.C) HRESULT,
    };
};

const ICoreWebView2 = extern struct {
    vtable: *const VTable,
    pub const VTable = extern struct {
        base: IUnknown.VTable,
        get_Settings: *const fn () callconv(.C) HRESULT, // Simplified
        get_Source: *const fn (self: *ICoreWebView2, uri: *?[*:0]u16) callconv(.C) HRESULT,
        Navigate: *const fn (self: *ICoreWebView2, uri: [*:0]const u16) callconv(.C) HRESULT,
        add_NavigationCompleted: *const fn (self: *ICoreWebView2, eventHandler: *ICoreWebView2NavigationCompletedEventHandler, token: *win32.EventRegistrationToken) callconv(.C) HRESULT,
    };
};

// --- Global State ---
var gpa = std.heap.page_allocator;
var allocator: std.mem.Allocator = undefined;
var parent_window: HWND = undefined;
var webview_environment: ?*ICoreWebView2Environment = null;
var webview_controller: ?*ICoreWebView2Controller = null;
var webview_core: ?*ICoreWebView2 = null;
var on_navigation_completed: ?*const fn (success: bool, url: []const u8) void = null;

// --- COM Handlers ---
const EnvironmentCompletedHandler = struct {
    base: ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler,
    ref_count: u32,
    allocator: std.mem.Allocator,

    const Self = @This();
    const ComHelper = @import("com.zig").ComObject(Self, ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler);

    pub const vtable = ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler.VTable{
        .base = .{
            .QueryInterface = ComHelper.queryInterface,
            .AddRef = ComHelper.addRef,
            .Release = ComHelper.release,
        },
        .Invoke = Invoke,
    };

    fn Invoke(_: *ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler, result: HRESULT, created_environment: ?*ICoreWebView2Environment) callconv(.C) HRESULT {
        if (result != 0) {
            std.debug.print("Failed to create environment: {x}\n", .{result});
            return result;
        }
        webview_environment = created_environment;
        const controller_handler = ControllerCompletedHandler.create(allocator) catch return win32.E_FAIL;
        const hr = webview_environment.?.vtable.CreateCoreWebView2Controller(webview_environment.?, parent_window, &controller_handler.base);
        if (hr != 0) {
            std.debug.print("CreateCoreWebView2Controller failed: {x}\n", .{hr});
        }
        return hr;
    }

    pub fn create(allocator_param: std.mem.Allocator) !*Self {
        const self = try allocator_param.create(Self);
        self.* = .{
            .base = .{ .vtable = &vtable },
            .ref_count = 1,
            .allocator = allocator_param,
        };
        return self;
    }
};

const ControllerCompletedHandler = struct {
    base: ICoreWebView2CreateCoreWebView2ControllerCompletedHandler,
    ref_count: u32,
    allocator: std.mem.Allocator,

    const Self = @This();
    const ComHelper = @import("com.zig").ComObject(Self, ICoreWebView2CreateCoreWebView2ControllerCompletedHandler);

    pub const vtable = ICoreWebView2CreateCoreWebView2ControllerCompletedHandler.VTable{
        .base = .{
            .QueryInterface = ComHelper.queryInterface,
            .AddRef = ComHelper.addRef,
            .Release = ComHelper.release,
        },
        .Invoke = Invoke,
    };

    fn Invoke(_: *ICoreWebView2CreateCoreWebView2ControllerCompletedHandler, result: HRESULT, controller: ?*ICoreWebView2Controller) callconv(.C) HRESULT {
        if (result != 0) {
            std.debug.print("Failed to create controller: {x}\n", .{result});
            return result;
        }
        webview_controller = controller;
        _ = webview_controller.?.vtable.get_CoreWebView2(webview_controller.?, &webview_core);

        if (webview_core) |wv| {
            const nav_handler = NavigationCompletedHandler.create(allocator) catch return win32.E_FAIL;
            var token: win32.EventRegistrationToken = undefined;
            _ = wv.vtable.add_NavigationCompleted(wv, &nav_handler.base, &token);
        }

        resizeWebView(0, 0);
        _ = webview_controller.?.vtable.put_IsVisible(webview_controller.?, 1);
        return navigate("https://www.google.com");
    }

    pub fn create(allocator_param: std.mem.Allocator) !*Self {
        const self = try allocator_param.create(Self);
        self.* = .{
            .base = .{ .vtable = &vtable },
            .ref_count = 1,
            .allocator = allocator_param,
        };
        return self;
    }
};

const NavigationCompletedHandler = struct {
    base: ICoreWebView2NavigationCompletedEventHandler,
    ref_count: u32,
    allocator: std.mem.Allocator,

    const Self = @This();
    const ComHelper = @import("com.zig").ComObject(Self, ICoreWebView2NavigationCompletedEventHandler);

    pub const vtable = ICoreWebView2NavigationCompletedEventHandler.VTable{
        .base = .{
            .QueryInterface = ComHelper.queryInterface,
            .AddRef = ComHelper.addRef,
            .Release = ComHelper.release,
        },
        .Invoke = Invoke,
    };

    fn Invoke(_: *ICoreWebView2NavigationCompletedEventHandler, sender: *ICoreWebView2, args: *ICoreWebView2NavigationCompletedEventArgs) callconv(.C) HRESULT {
        var is_success: BOOL = 0;
        _ = args.vtable.get_IsSuccess(args, &is_success);

        var source_ptr: ?[*:0]u16 = null;
        _ = sender.vtable.get_Source(sender, &source_ptr);
        if (source_ptr) |ptr| {
            defer win32.CoTaskMemFree(ptr);
            const source_slice = std.mem.sliceTo(ptr, 0);
            const url = std.unicode.utf16leToUtf8(allocator, source_slice) catch "<unknown>";
            defer allocator.free(url);

            if (on_navigation_completed) |cb| {
                cb(is_success != 0, url);
            }
        }

        return win32.S_OK;
    }

    pub fn create(allocator_param: std.mem.Allocator) !*Self {
        const self = try allocator_param.create(Self);
        self.* = .{
            .base = .{ .vtable = &vtable },
            .ref_count = 1,
            .allocator = allocator_param,
        };
        return self;
    }
};

// --- Extern Functions ---
extern "WebView2Loader" fn CreateCoreWebView2EnvironmentWithOptions(
    browserExecutableFolder: ?[*:0]const u16,
    userDataFolder: ?[*:0]const u16,
    environmentOptions: ?*anyopaque,
    environmentCreatedHandler: *ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler,
) callconv(.C) HRESULT;

// --- Public API ---
pub fn initialize(a: std.mem.Allocator, hwnd: HWND) WebView2Error!void {
    allocator = a;
    parent_window = hwnd;

    const handler = try EnvironmentCompletedHandler.create(allocator);

    const hr = CreateCoreWebView2EnvironmentWithOptions(null, null, null, &handler.base);
    if (hr != 0) {
        std.debug.print("CreateCoreWebView2EnvironmentWithOptions failed: {x}\n", .{hr});
        return WebView2Error.WebView2EnvironmentCreationFailed;
    }
}

pub fn deinit() void {
    if (webview_core) |wv| _ = wv.vtable.base.Release(&wv.base);
    if (webview_controller) |wvc| _ = wvc.vtable.base.Release(&wvc.base);
    if (webview_environment) |wve| _ = wve.vtable.base.Release(&wve.base);
}

pub fn isInitialized() bool {
    return webview_controller != null and webview_core != null;
}

pub fn navigate(url: []const u8) HRESULT {
    if (webview_core) |wv| {
        const wide_url = utf8ToUtf16Le(allocator, url) catch return -1;
        defer allocator.free(wide_url);
        return wv.vtable.Navigate(wv, wide_url.ptr);
    }
    return -1; // E_FAIL
}

// Inject CSS untuk content blocking dan theming
pub fn injectCSS(css: []const u8) !void {
    if (webview_core == null) return error.WebViewNotInitialized;

    // In a real implementation, we would call the appropriate WebView2 method
    // For now, we'll just print the CSS
    std.debug.print("Injecting CSS: {s}\n", .{css});
}

// Set navigation completed callback
pub fn setNavigationCompletedCallback(callback: *const fn (success: bool, url: []const u8) void) void {
    on_navigation_completed = callback;
}

// Resize WebView2 to fit window
pub fn resizeWebView(width: i32, height: i32) HRESULT {
    if (webview_controller == null) {
        std.debug.print("WebView2 controller is null, cannot resize\n", .{});
        return @as(HRESULT, -1); // E_FAIL
    }

    // Create bounds
    const bounds = RECT{
        .left = 0,
        .top = 0,
        .right = width,
        .bottom = height,
    };

    std.debug.print("Setting WebView2 bounds to: left={d}, top={d}, right={d}, bottom={d}\n", .{bounds.left, bounds.top, bounds.right, bounds.bottom});
    
    // Set bounds
    const hr = webview_controller.?.put_Bounds(bounds);
    if (hr != 0) {
        std.debug.print("Failed to set WebView2 bounds: {d} (0x{x})\n", .{hr, @as(u32, @bitCast(hr))});
    }
    return hr;
}



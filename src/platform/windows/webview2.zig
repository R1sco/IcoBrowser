const std = @import("std");
const win32 = @import("win32.zig");
const utf8ToUtf16Le = win32.utf8ToUtf16Le;

// Handler untuk WebView2 Environment creation
pub const EnvironmentCreatedHandler = struct {
    vtable: *const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVTable,
    ref_count: usize,
};
const windows = std.os.windows;
const Allocator = std.mem.Allocator;

// Gunakan tipe dari win32.zig dan windows untuk konsistensi
const HWND = win32.HWND;
const BOOL = win32.BOOL;
const RECT = win32.RECT;
const HRESULT = windows.HRESULT;
const GUID = windows.GUID;
const ULONG = u32;

// Common COM interface function pointer types
const QueryInterfaceFn = fn (self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) callconv(.C) HRESULT;
const AddRefFn = fn (self: *IUnknown) callconv(.C) ULONG;
const ReleaseFn = fn (self: *IUnknown) callconv(.C) ULONG;
// Common Invoke function pointer types for different handlers
const InvokeEnvironmentCreatedFn = fn (self: *anyopaque, result: HRESULT, created_environment: ?*anyopaque) callconv(.C) HRESULT;
const InvokeControllerCreatedFn = fn (self: *anyopaque, error_code: HRESULT, controller: ?*anyopaque) callconv(.C) HRESULT;
const InvokeNavigationCompletedFn = fn (self: *anyopaque, sender: *anyopaque, args: *anyopaque) callconv(.C) HRESULT;

// Deklarasi VTable untuk WebView2
pub const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVTable = extern struct {
    QueryInterface: *const QueryInterfaceFn,
    AddRef: *const AddRefFn,
    Release: *const ReleaseFn,
    Invoke: *const InvokeEnvironmentCreatedFn,
};

pub const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVTable = extern struct {
    QueryInterface: *const QueryInterfaceFn,
    AddRef: *const AddRefFn,
    Release: *const ReleaseFn,
    Invoke: *const InvokeControllerCreatedFn,
};

pub const ICoreWebView2NavigationCompletedEventHandlerVTable = extern struct {
    QueryInterface: *const QueryInterfaceFn,
    AddRef: *const AddRefFn,
    Release: *const ReleaseFn,
    Invoke: *const InvokeNavigationCompletedFn,
};

// WebView2 binding untuk Zig
// Ini adalah binding minimal untuk WebView2 SDK

// Global WebView2 state
var webview_environment: ?*ICoreWebView2Environment = null;
var webview_controller: ?*ICoreWebView2Controller = null;
var webview_core: ?*ICoreWebView2 = null;
var allocator: std.mem.Allocator = undefined;
var parent_window: HWND = undefined;
var environment_created_handler: ?*EnvironmentCreatedHandler = null;
var controller_created_handler: ?*ControllerCreatedHandler = null;
var navigation_completed_handler: ?*NavigationCompletedHandler = null;

// Callback functions
var on_navigation_completed: ?*const fn (success: bool, url: []const u8) void = null;

// COM interface definitions
pub const IUnknown = extern struct {
    vtable: *const VTable,

    pub const VTable = extern struct {
        QueryInterface: *const fn (self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) callconv(.C) HRESULT,
        AddRef: *const fn (self: *IUnknown) callconv(.C) ULONG,
        Release: *const fn (self: *IUnknown) callconv(.C) ULONG,
    };

    pub fn QueryInterface(self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) HRESULT {
        return self.vtable.QueryInterface(self, riid, ppvObject);
    }

    pub fn AddRef(self: *IUnknown) ULONG {
        return self.vtable.AddRef(self);
    }

    pub fn Release(self: *IUnknown) ULONG {
        return self.vtable.Release(self);
    }
};

// GUID structure sudah dideklarasikan di atas dari windows.GUID

// WebView2 Environment
pub const ICoreWebView2Environment = extern struct {
    vtable: *const ICoreWebView2EnvironmentVTable,

    pub const ICoreWebView2EnvironmentVTable = extern struct {
        unknown: IUnknown.VTable,
        CreateCoreWebView2Controller: *const fn (
            self: *ICoreWebView2Environment,
            parentWindow: HWND,
            handler: *ICoreWebView2CreateCoreWebView2ControllerCompletedHandler,
        ) callconv(.C) HRESULT,
        // Other methods would be added here
    };

    pub fn CreateCoreWebView2Controller(
        self: *ICoreWebView2Environment,
        parentWindow: HWND,
        handler: *ICoreWebView2CreateCoreWebView2ControllerCompletedHandler,
    ) HRESULT {
        return self.vtable.CreateCoreWebView2Controller(self, parentWindow, handler);
    }
};

// WebView2 Controller
pub const ICoreWebView2Controller = extern struct {
    vtable: *const ICoreWebView2ControllerVTable,

    pub const ICoreWebView2ControllerVTable = extern struct {
        unknown: IUnknown.VTable,
        GetCoreWebView2: *const fn (
            self: *ICoreWebView2Controller,
            coreWebView2: **ICoreWebView2,
        ) callconv(.C) HRESULT,
        // Other methods would be added here
    };

    pub fn GetCoreWebView2(self: *ICoreWebView2Controller, coreWebView2: **ICoreWebView2) HRESULT {
        return self.vtable.GetCoreWebView2(self, coreWebView2);
    }
};

// WebView2 Core
pub const ICoreWebView2 = extern struct {
    vtable: *const ICoreWebView2VTable,

    pub const ICoreWebView2VTable = extern struct {
        unknown: IUnknown.VTable,
        Navigate: *const fn (
            self: *ICoreWebView2,
            uri: [*:0]const u16,
        ) callconv(.C) HRESULT,
        // Other methods would be added here
    };

    pub fn Navigate(self: *ICoreWebView2, uri: [*:0]const u16) HRESULT {
        return self.vtable.Navigate(self, uri);
    }
};

// Callback handler for WebView2 creation
pub const ICoreWebView2CreateCoreWebView2ControllerCompletedHandler = extern struct {
    vtable: *const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVTable,

    pub fn Invoke(
        self: *ICoreWebView2CreateCoreWebView2ControllerCompletedHandler,
        result: HRESULT,
        controller: ?*ICoreWebView2Controller,
    ) HRESULT {
        return self.vtable.Invoke(self, result, controller);
    }
};

// WebView2 Environment creation function
pub extern "WebView2Loader" fn CreateCoreWebView2EnvironmentWithOptions(
    browserExecutableFolder: ?[*:0]const u16,
    userDataFolder: ?[*:0]const u16,
    environmentOptions: ?*anyopaque,
    environmentCreatedHandler: *ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler,
) callconv(.C) HRESULT;

// Environment creation handler
pub const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler = extern struct {
    vtable: *const ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVTable,
    ref_count: usize,

    pub fn create() !*EnvironmentCreatedHandler {
        const handler = try allocator.create(EnvironmentCreatedHandler);
        const vtable = try allocator.create(ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVTable);

        vtable.* = .{ .QueryInterface = &queryInterface, .AddRef = &addRef, .Release = &release, .Invoke = &invokeEnvironmentCreated };

        handler.* = .{
            .vtable = vtable,
            .ref_count = 1,
        };

        return handler;
    }

    fn queryInterface(self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) callconv(.C) HRESULT {
        _ = riid;
        ppvObject.* = self;
        _ = self.vtable.AddRef(self);
        return 0; // S_OK
    }

    fn addRef(self: *IUnknown) callconv(.C) ULONG {
        const handler = @as(*EnvironmentCreatedHandler, @ptrFromInt(@intFromPtr(self) - @offsetOf(EnvironmentCreatedHandler, "vtable")));
        handler.ref_count += 1;
        return @intCast(handler.ref_count);
    }

    fn release(self: *IUnknown) callconv(.C) ULONG {
        const handler = @as(*EnvironmentCreatedHandler, @ptrFromInt(@intFromPtr(self) - @offsetOf(EnvironmentCreatedHandler, "vtable")));
        handler.ref_count -= 1;
        const ref_count = handler.ref_count;

        if (ref_count == 0) {
            allocator.destroy(handler.vtable);
            allocator.destroy(handler);
        }

        return @intCast(ref_count);
    }

    fn invokeEnvironmentCreated(self: *anyopaque, result: HRESULT, created_environment: ?*anyopaque) callconv(.C) HRESULT {
        _ = self;
        if (result != 0) { // Not S_OK
            std.debug.print("Failed to create WebView2 environment: {d}\n", .{result});
            return result;
        }

        if (created_environment) |env_any| {
            // Cast raw pointer to environment and assign to optional global
            webview_environment = @ptrCast(@alignCast(env_any));

            // Create controller
            if (controller_created_handler == null) {
                controller_created_handler = ControllerCreatedHandler.create() catch {
                    std.debug.print("Failed to create controller handler\n", .{});
                    return -1; // E_FAIL
                };
            }

            // Initialize controller on environment
            const env: *ICoreWebView2Environment = @ptrCast(@alignCast(env_any));
const hr = env.CreateCoreWebView2Controller(parent_window, @ptrCast(@alignCast(controller_created_handler.?)));


            if (hr != 0) { // Not S_OK
                std.debug.print("Failed to create WebView2 controller: {d}\n", .{hr});
                return hr;
            }
        }

        return 0; // S_OK
    }
};

// Handler untuk WebView2 Controller creation
pub const ControllerCreatedHandler = struct {
    vtable: *const ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVTable,
    ref_count: usize,

    pub fn create() !*ControllerCreatedHandler {
        const handler = try allocator.create(ControllerCreatedHandler);
        const vtable = try allocator.create(ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVTable);

        vtable.* = .{ .QueryInterface = &queryInterface, .AddRef = &addRef, .Release = &release, .Invoke = &invokeControllerCreated };

        handler.* = .{
            .vtable = vtable,
            .ref_count = 1,
        };

        return handler;
    }

    fn queryInterface(self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) callconv(.C) HRESULT {
        _ = riid;
        ppvObject.* = self;
        _ = self.vtable.AddRef(self);
        return 0; // S_OK
    }

    fn addRef(self: *IUnknown) callconv(.C) ULONG {
        const handler = @as(*ControllerCreatedHandler, @ptrFromInt(@intFromPtr(self) - @offsetOf(ControllerCreatedHandler, "vtable")));
        handler.ref_count += 1;
        return @intCast(handler.ref_count);
    }

    fn release(self: *IUnknown) callconv(.C) ULONG {
        const handler = @as(*ControllerCreatedHandler, @ptrFromInt(@intFromPtr(self) - @offsetOf(ControllerCreatedHandler, "vtable")));
        handler.ref_count -= 1;
        const ref_count = handler.ref_count;

        if (ref_count == 0) {
            allocator.destroy(handler.vtable);
            allocator.destroy(handler);
        }

        return @intCast(ref_count);
    }

    fn invokeControllerCreated(self: *anyopaque, error_code: HRESULT, controller: ?*anyopaque) callconv(.C) HRESULT {
        _ = self;
        if (error_code != 0) { // Not S_OK
            std.debug.print("Failed to create WebView2 controller: {d}\n", .{error_code});
            return error_code;
        }

        if (controller) |ctrl_any| {
            // Cast raw pointer to controller and assign to optional global
            webview_controller = @ptrCast(@alignCast(ctrl_any));

            // Get WebView2 core
            var core: *ICoreWebView2 = undefined;
            const ctrl: *ICoreWebView2Controller = @ptrCast(@alignCast(ctrl_any));
const hr = ctrl.GetCoreWebView2(&core);

            if (hr != 0) { // Not S_OK
                std.debug.print("Failed to get WebView2 core: {d}\n", .{hr});
            }

            webview_core = core;

            // Set bounds to match parent window
            var rect: RECT = undefined;
            _ = win32.GetClientRect(parent_window, &rect);
            _ = resizeWebView(rect.right - rect.left, rect.bottom - rect.top);

            // Register navigation completed handler
            // This would be implemented in a more complete version
        }

        return 0; // S_OK
    }
};

// Navigation completed event args
pub const ICoreWebView2NavigationCompletedEventArgs = extern struct {
    vtable: *const ICoreWebView2NavigationCompletedEventArgsVTable,

    pub const ICoreWebView2NavigationCompletedEventArgsVTable = extern struct {
        unknown: IUnknown.VTable,
        IsSuccess: *const fn (
            self: *ICoreWebView2NavigationCompletedEventArgs,
            is_success: *BOOL,
        ) callconv(.C) HRESULT,
        // Other methods would be added here
    };

    pub fn IsSuccess(self: *ICoreWebView2NavigationCompletedEventArgs, is_success: *BOOL) HRESULT {
        return self.vtable.IsSuccess(self, is_success);
    }
};

// Navigation completed event handler
pub const ICoreWebView2NavigationCompletedEventHandler = extern struct {
    vtable: *const ICoreWebView2NavigationCompletedEventHandlerVTable,

    // Menggunakan definisi VTable global

    pub fn Invoke(
        self: *ICoreWebView2NavigationCompletedEventHandler,
        sender: *ICoreWebView2,
        args: *ICoreWebView2NavigationCompletedEventArgs,
    ) HRESULT {
        return self.vtable.Invoke(self, sender, args);
    }
};

// WebView2 wrapper untuk lebih mudah digunakan
pub const WebView2 = struct {
    // Initialize WebView2 environment
    pub fn initialize(hwnd: HWND, alloc: std.mem.Allocator) !void {
        allocator = alloc;
        parent_window = hwnd;

        // Create environment handler
        if (environment_created_handler == null) {
            environment_created_handler = try ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler.create();
        }

        // Create WebView2 environment
        const hr = CreateCoreWebView2EnvironmentWithOptions(null, // Use default Edge installation
            null, // Use default user data folder
            null, // No environment options
            @ptrCast(environment_created_handler.?));

        if (hr != 0) { // Not S_OK
            std.debug.print("Failed to create WebView2 environment: {d}\n", .{hr});
            return error.WebView2EnvironmentCreationFailed;
        }
    }

    // Navigate to a URL
    pub fn navigate(url: []const u8) !void {
        if (webview_core == null) return error.WebViewNotInitialized;

        // Convert URL to UTF-16
        const url_w = try utf8ToUtf16Le(allocator, url);
        defer allocator.free(url_w);

        // Navigate to URL
        const hr = webview_core.?.Navigate(url_w.ptr);

        if (hr != 0) { // Not S_OK
            std.debug.print("Failed to navigate to URL: {d}\n", .{hr});
            return error.WebViewNavigationFailed;
        }
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
};

// Resize WebView untuk match window size
pub fn resizeWebView(width: i32, height: i32) HRESULT {
    if (webview_controller == null) return -1; // E_FAIL;

    const rect = RECT{
        .left = 0,
        .top = 0,
        .right = width,
        .bottom = height,
    };
    _ = rect; // Will be used in future implementation

    // In a real implementation, we would call the appropriate WebView2 method
    // For now, we'll just print the dimensions
    std.debug.print("Resizing WebView to: {d}x{d}\n", .{ width, height });

    return 0; // S_OK
}

// Handler untuk WebView2 Navigation Completed
pub const NavigationCompletedHandler = struct {
    vtable: *const ICoreWebView2NavigationCompletedEventHandlerVTable,
    ref_count: usize,

    pub fn create(callback: *const fn (success: bool, url: []const u8) void) !*NavigationCompletedHandler {
        on_navigation_completed = callback;
        const handler = try allocator.create(NavigationCompletedHandler);
        const vtable = try allocator.create(ICoreWebView2NavigationCompletedEventHandlerVTable);

        vtable.* = .{ .QueryInterface = &queryInterface, .AddRef = &addRef, .Release = &release, .Invoke = &invokeNavigationCompleted };

        handler.* = .{
            .vtable = vtable,
            .ref_count = 1,
        };

        return handler;
    }

    fn queryInterface(self: *IUnknown, riid: *const GUID, ppvObject: *?*anyopaque) callconv(.C) HRESULT {
        _ = riid;
        ppvObject.* = self;
        _ = self.vtable.AddRef(self);
        return 0; // S_OK
    }

    fn addRef(self: *IUnknown) callconv(.C) ULONG {
        const handler = @as(*NavigationCompletedHandler, @ptrFromInt(@intFromPtr(self) - @offsetOf(NavigationCompletedHandler, "vtable")));
        handler.ref_count += 1;
        return @intCast(handler.ref_count);
    }

    fn release(self: *IUnknown) callconv(.C) ULONG {
        const handler = @as(*NavigationCompletedHandler, @ptrFromInt(@intFromPtr(self) - @offsetOf(NavigationCompletedHandler, "vtable")));
        handler.ref_count -= 1;
        const ref_count = handler.ref_count;

        if (ref_count == 0) {
            allocator.destroy(handler.vtable);
            allocator.destroy(handler);
        }

        return @intCast(ref_count);
    }

    fn invokeNavigationCompleted(self: *anyopaque, sender: *anyopaque, args: *anyopaque) callconv(.C) HRESULT {
        _ = self;
        _ = sender;
        _ = args;
        if (on_navigation_completed) |cb| cb(true, "");
        return 0; // S_OK
    }
};

const std = @import("std");
const windows = @import("windows.zig");
const win32 = @import("../platform/windows/win32.zig");
const webview2 = @import("../platform/windows/webview2.zig");
const theme = @import("theme.zig");
const security = @import("../security.zig");

// Browser UI components
// Mengelola UI browser seperti toolbar, address bar, dan tab

// Constants for UI layout
const TOOLBAR_HEIGHT = 40;
const BUTTON_WIDTH = 30;
const BUTTON_HEIGHT = 30;
const BUTTON_MARGIN = 5;
const ADDRESS_BAR_HEIGHT = 30;
const TAB_HEIGHT = 30;
const TAB_MIN_WIDTH = 100;
const TAB_MAX_WIDTH = 200;

// UI state
var address_bar_text: [1024]u8 = undefined;
var address_bar_text_len: usize = 0;
var current_url: [1024]u8 = undefined;
var current_url_len: usize = 0;
var is_loading: bool = false;
var is_secure: bool = false;
var allocator: std.mem.Allocator = undefined;

// Tab structure
pub const Tab = struct {
    id: u32,
    title: [256]u8,
    title_len: usize,
    url: [1024]u8,
    url_len: usize,
    is_active: bool,
    is_loading: bool,
    is_secure: bool,

    pub fn init(id: u32) Tab {
        return Tab{
            .id = id,
            .title = undefined,
            .title_len = 0,
            .url = undefined,
            .url_len = 0,
            .is_active = false,
            .is_loading = false,
            .is_secure = false,
        };
    }

    pub fn setTitle(self: *Tab, title: []const u8) void {
        const len = @min(title.len, self.title.len - 1);
        @memcpy(self.title[0..len], title[0..len]);
        self.title[len] = 0;
        self.title_len = len;
    }

    pub fn setUrl(self: *Tab, url: []const u8) void {
        const len = @min(url.len, self.url.len - 1);
        @memcpy(self.url[0..len], url[0..len]);
        self.url[len] = 0;
        self.url_len = len;
    }
};

// Tab management
var tabs = std.ArrayList(Tab).init(std.heap.page_allocator);
var active_tab_index: usize = 0;

// Get the index of the currently active tab
pub fn getActiveTabIndex() usize {
    return active_tab_index;
}

// Initialize UI
pub fn initialize(alloc: std.mem.Allocator) !void {
    allocator = alloc;

    // Create initial tab
    const tab = Tab.init(1);
    try tabs.append(tab);
    active_tab_index = 0;
    tabs.items[active_tab_index].is_active = true;

    // Set default URL
    setAddressBarText("https://www.example.com");
}

// Set address bar text
pub fn setAddressBarText(text: []const u8) void {
    const len = @min(text.len, address_bar_text.len - 1);
    @memcpy(address_bar_text[0..len], text[0..len]);
    address_bar_text[len] = 0;
    address_bar_text_len = len;
}

// Get address bar text
pub fn getAddressBarText() []const u8 {
    return address_bar_text[0..address_bar_text_len];
}

// Navigate to URL in address bar
pub fn navigateToAddressBar() !void {
    const url = getAddressBarText();

    // Check URL security
    is_secure = try security.SecurityModule.checkUrlSecurity(url);
    if (!is_secure) {
        std.debug.print("Warning: URL is not secure: {s}\n", .{url});
    }

    // Update current URL
    const len = @min(url.len, current_url.len - 1);
    @memcpy(current_url[0..len], url[0..len]);
    current_url[len] = 0;
    current_url_len = len;

    // Update tab URL
    if (tabs.items.len > active_tab_index) {
        tabs.items[active_tab_index].setUrl(url);
    }

    // Start loading
    is_loading = true;

    // Navigate to URL
    try webview2.WebView2.navigate(url);
}

// Create new tab
pub fn createNewTab() !void {
    const tab = Tab.init(@intCast(tabs.items.len + 1));
    try tabs.append(tab);

    // Set new tab as active
    setActiveTab(tabs.items.len - 1);
}

// Close tab
pub fn closeTab(index: usize) !void {
    if (tabs.items.len <= 1) {
        // Don't close the last tab
        return;
    }

    const was_active = tabs.items[index].is_active;

    // Remove tab
    _ = tabs.orderedRemove(index);

    // Update active tab if needed
    if (was_active) {
        if (index >= tabs.items.len) {
            setActiveTab(tabs.items.len - 1);
        } else {
            setActiveTab(index);
        }
    } else if (active_tab_index > index) {
        active_tab_index -= 1;
    }
}

// Set active tab
pub fn setActiveTab(index: usize) void {
    if (index >= tabs.items.len) {
        return;
    }

    // Deactivate current tab
    if (active_tab_index < tabs.items.len) {
        tabs.items[active_tab_index].is_active = false;
    }

    // Activate new tab
    active_tab_index = index;
    tabs.items[active_tab_index].is_active = true;

    // Update address bar
    setAddressBarText(tabs.items[active_tab_index].url[0..tabs.items[active_tab_index].url_len]);

    // Navigate to tab URL
    const url = tabs.items[active_tab_index].url[0..tabs.items[active_tab_index].url_len];
    if (url.len > 0) {
        webview2.WebView2.navigate(url) catch |err| {
            std.debug.print("Failed to navigate to URL: {any}\n", .{err});
        };
    }
}

// Go back in history
pub fn goBack() !void {
    std.debug.print("Going back\n", .{});
    return;
}

// Go forward in history
pub fn goForward() !void {
    std.debug.print("Going forward\n", .{});
    return;
}

// Reload current page
pub fn reload() !void {
    std.debug.print("Reloading\n", .{});
    return;
}

// Stop loading
pub fn stopLoading() void {
    // In a real implementation, we would call the appropriate WebView2 method
    std.debug.print("Stopping loading\n", .{});
    is_loading = false;
}

// Toggle theme
pub fn toggleTheme() !void {
    const core_theme = @import("../core/theming.zig");

    // Toggle between light and dark
    if (core_theme.getCurrentThemeType() == .light) {
        try core_theme.setTheme(.dark);
    } else {
        try core_theme.setTheme(.light);
    }
}

// Draw browser UI
pub fn drawUI(hwnd: win32.HWND) void {
    _ = hwnd; // Parameter ini akan digunakan nanti
    // In a real implementation, we would draw the UI using Windows GDI or Direct2D
    // For now, we'll just print the UI state
    std.debug.print("Drawing browser UI\n", .{});
    std.debug.print("  Address bar: {s}\n", .{getAddressBarText()});
    std.debug.print("  Current URL: {s}\n", .{current_url[0..current_url_len]});
    std.debug.print("  Loading: {}\n", .{is_loading});
    std.debug.print("  Secure: {}\n", .{is_secure});
    std.debug.print("  Tabs: {d}\n", .{tabs.items.len});
    std.debug.print("  Active tab: {d}\n", .{active_tab_index});
}

// Handle navigation completed
pub fn handleNavigationCompleted(success: bool, url: []const u8) void {
    is_loading = false;

    if (success) {
        std.debug.print("Navigation completed successfully: {s}\n", .{url});
    } else {
        std.debug.print("Navigation failed: {s}\n", .{url});
    }

    // Update tab title
    if (tabs.items.len > active_tab_index) {
        tabs.items[active_tab_index].setTitle("Page Title"); // In a real implementation, we would get the page title
    }
}

// Clean up
pub fn deinit() void {
    tabs.deinit();
}

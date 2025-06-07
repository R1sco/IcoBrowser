const std = @import("std");
const ui_theme = @import("../ui/theme.zig");
const webview2 = @import("../platform/windows/webview2.zig");

// Theming system untuk IcoBrowser
// Mengelola tema dan preferensi tampilan

// Tema yang tersedia
pub const ThemeType = enum {
    light,
    dark,
    custom,
};

// Status tema saat ini
var current_theme_type: ThemeType = .light;
var custom_theme_path: ?[]const u8 = null;
var allocator: std.mem.Allocator = undefined;

// Inisialisasi sistem tema
pub fn initialize(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    
    // Default ke tema terang
    try setTheme(.light);
}

// Mengatur tema
pub fn setTheme(theme_type: ThemeType) !void {
    current_theme_type = theme_type;
    
    const theme_name = switch (theme_type) {
        .light => "light",
        .dark => "dark",
        .custom => if (custom_theme_path) |path| path else return error.NoCustomThemePath,
    };
    
    // Muat tema dari UI
    try ui_theme.switchTheme(allocator, theme_name);
    
    // Terapkan tema ke browser
    try applyThemeToBrowser();
}

// Mengatur tema kustom
pub fn setCustomTheme(theme_path: []const u8) !void {
    if (custom_theme_path != null) {
        allocator.free(custom_theme_path.?);
    }
    
    custom_theme_path = try allocator.dupe(u8, theme_path);
    try setTheme(.custom);
}

// Menerapkan tema ke browser
pub fn applyThemeToBrowser() !void {
    // Dapatkan CSS dari tema UI
    const css = try ui_theme.generateCSS(allocator);
    defer allocator.free(css);
    
    // Tambahkan CSS untuk fitur browser khusus
    const browser_css = try std.fmt.allocPrint(
        allocator,
        \\{s}
        \\
        \\/* Browser-specific styling */
        \\.browser-toolbar {{
        \\  height: 40px;
        \\  display: flex;
        \\  align-items: center;
        \\  padding: 0 10px;
        \\  background-color: var(--toolbar-background);
        \\  color: var(--toolbar-text);
        \\}}
        \\
        \\.browser-button {{
        \\  background-color: transparent;
        \\  border: none;
        \\  color: var(--toolbar-text);
        \\  padding: 5px 10px;
        \\  cursor: pointer;
        \\  margin: 0 2px;
        \\}}
        \\
        \\.browser-button:hover {{
        \\  background-color: rgba(255, 255, 255, 0.1);
        \\}}
        \\
        \\.address-bar {{
        \\  flex: 1;
        \\  background-color: rgba(255, 255, 255, 0.1);
        \\  border: 1px solid rgba(255, 255, 255, 0.2);
        \\  border-radius: 4px;
        \\  padding: 5px 10px;
        \\  color: var(--text-color);
        \\  margin: 0 10px;
        \\}}
        ,
        .{css}
    );
    defer allocator.free(browser_css);
    
    // Terapkan CSS ke WebView2
    try webview2.WebView2.injectCSS(browser_css);
}

// Mendapatkan tema saat ini
pub fn getCurrentThemeType() ThemeType {
    return current_theme_type;
}

// Mendapatkan path tema kustom
pub fn getCustomThemePath() ?[]const u8 {
    return custom_theme_path;
}

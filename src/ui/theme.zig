const std = @import("std");
const fs = std.fs;
const json = std.json;

// Theme structure
pub const Theme = struct {
    // Colors
    background_color: []const u8,
    text_color: []const u8,
    accent_color: []const u8,
    link_color: []const u8,
    
    // UI elements
    toolbar_background: []const u8,
    toolbar_text: []const u8,
    sidebar_background: []const u8,
    sidebar_text: []const u8,
    
    // Status indicators
    success_color: []const u8,
    warning_color: []const u8,
    error_color: []const u8,
    
    // Name and metadata
    name: []const u8,
    author: []const u8,
    version: []const u8,
    
    // Allocator for freeing memory
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *Theme) void {
        self.allocator.free(self.background_color);
        self.allocator.free(self.text_color);
        self.allocator.free(self.accent_color);
        self.allocator.free(self.link_color);
        self.allocator.free(self.toolbar_background);
        self.allocator.free(self.toolbar_text);
        self.allocator.free(self.sidebar_background);
        self.allocator.free(self.sidebar_text);
        self.allocator.free(self.success_color);
        self.allocator.free(self.warning_color);
        self.allocator.free(self.error_color);
        self.allocator.free(self.name);
        self.allocator.free(self.author);
        self.allocator.free(self.version);
    }
};

// Current theme
var current_theme: ?Theme = null;

// Load theme from JSON file
pub fn loadTheme(allocator: std.mem.Allocator, theme_name: []const u8) !Theme {
    // Construct path to theme file
    const theme_path = try std.fmt.allocPrint(
        allocator, 
        "assets/themes/{s}.json", 
        .{theme_name}
    );
    defer allocator.free(theme_path);
    
    // Open theme file
    const file = try fs.cwd().openFile(theme_path, .{});
    defer file.close();
    
    // Read file content
    const max_size = 10 * 1024; // 10KB max for theme file
    const content = try file.readToEndAlloc(allocator, max_size);
    defer allocator.free(content);
    
    // Parse JSON
    const theme_value = try json.parseFromSlice(json.Value, allocator, content, .{});
    defer theme_value.deinit();
    
    const theme_obj = theme_value.value.object;
    
    // Helper function to get string field with default
    const getStringField = struct {
        fn get(obj: std.json.ObjectMap, field: []const u8, default_val: []const u8) []const u8 {
            if (obj.get(field)) |val| {
                if (val == .string) {
                    return val.string;
                }
            }
            return default_val;
        }
    }.get;
    
    // Create theme
    return Theme{
        .background_color = try allocator.dupe(u8, getStringField(theme_obj, "background_color", "#ffffff")),
        .text_color = try allocator.dupe(u8, getStringField(theme_obj, "text_color", "#000000")),
        .accent_color = try allocator.dupe(u8, getStringField(theme_obj, "accent_color", "#1a73e8")),
        .link_color = try allocator.dupe(u8, getStringField(theme_obj, "link_color", "#1a73e8")),
        .toolbar_background = try allocator.dupe(u8, getStringField(theme_obj, "toolbar_background", "#f8f9fa")),
        .toolbar_text = try allocator.dupe(u8, getStringField(theme_obj, "toolbar_text", "#202124")),
        .sidebar_background = try allocator.dupe(u8, getStringField(theme_obj, "sidebar_background", "#f1f3f4")),
        .sidebar_text = try allocator.dupe(u8, getStringField(theme_obj, "sidebar_text", "#202124")),
        .success_color = try allocator.dupe(u8, getStringField(theme_obj, "success_color", "#0f9d58")),
        .warning_color = try allocator.dupe(u8, getStringField(theme_obj, "warning_color", "#f4b400")),
        .error_color = try allocator.dupe(u8, getStringField(theme_obj, "error_color", "#db4437")),
        .name = try allocator.dupe(u8, getStringField(theme_obj, "name", "Unnamed Theme")),
        .author = try allocator.dupe(u8, getStringField(theme_obj, "author", "")),
        .version = try allocator.dupe(u8, getStringField(theme_obj, "version", "1.0.0")),
        .allocator = allocator,
    };
}

// Initialize theme system
pub fn initialize(allocator: std.mem.Allocator) !void {
    // Default to light theme
    if (current_theme != null) {
        current_theme.?.deinit();
    }
    
    current_theme = try loadTheme(allocator, "light");
}

// Switch theme
pub fn switchTheme(allocator: std.mem.Allocator, theme_name: []const u8) !void {
    if (current_theme != null) {
        current_theme.?.deinit();
    }
    
    current_theme = try loadTheme(allocator, theme_name);
}

// Get current theme
pub fn getCurrentTheme() ?*Theme {
    if (current_theme != null) {
        return &current_theme.?;
    }
    
    return null;
}

// Generate CSS from current theme
pub fn generateCSS(allocator: std.mem.Allocator) ![]const u8 {
    if (current_theme == null) {
        return error.NoThemeLoaded;
    }
    
    const theme_ptr = &current_theme.?;
    
    return try std.fmt.allocPrint(allocator,
        \\:root {{
        \\  --background-color: {s};
        \\  --text-color: {s};
        \\  --accent-color: {s};
        \\  --link-color: {s};
        \\  --toolbar-background: {s};
        \\  --toolbar-text: {s};
        \\  --sidebar-background: {s};
        \\  --sidebar-text: {s};
        \\  --success-color: {s};
        \\  --warning-color: {s};
        \\  --error-color: {s};
        \\}}
        \\
        \\body {{
        \\  background-color: var(--background-color);
        \\  color: var(--text-color);
        \\}}
        \\
        \\a {{
        \\  color: var(--link-color);
        \\}}
        \\
        \\.toolbar {{
        \\  background-color: var(--toolbar-background);
        \\  color: var(--toolbar-text);
        \\}}
        \\
        \\.sidebar {{
        \\  background-color: var(--sidebar-background);
        \\  color: var(--sidebar-text);
        \\}}
        ,
        .{
            theme_ptr.background_color,
            theme_ptr.text_color,
            theme_ptr.accent_color,
            theme_ptr.link_color,
            theme_ptr.toolbar_background,
            theme_ptr.toolbar_text,
            theme_ptr.sidebar_background,
            theme_ptr.sidebar_text,
            theme_ptr.success_color,
            theme_ptr.warning_color,
            theme_ptr.error_color,
        }
    );
}

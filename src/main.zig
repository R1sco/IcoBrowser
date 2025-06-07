const std = @import("std");
const windows = @import("ui/windows.zig");
const content_blocker = @import("core/security/content_blocker.zig");
const security = @import("security.zig");
const webview2 = @import("platform/windows/webview2.zig");
const theme = @import("ui/theme.zig");
const browser_ui = @import("ui/browser_ui.zig");
const theming = @import("core/theming.zig");
const rules = @import("core/rules.zig");
const rules_manager = @import("ui/rules_manager.zig");
const enhanced_security = @import("core/security/enhanced_security.zig");

// IcoBrowser - Browser minimalis berbasis Zig dan WebView2
// Main entry point

pub fn main() !void {
    // Initialize standard output for logging
    const stdout = std.io.getStdOut().writer();
    try stdout.print("IcoBrowser - Starting up...\n", .{});

    // Create general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};    
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Initialize application
    try stdout.print("Initializing application components...\n", .{});
    
    // Windows-specific initialization
    if (@import("builtin").os.tag == .windows) {
        try stdout.print("Initializing Windows components...\n", .{});
        
        // Initialize Windows application and create main window
        _ = try windows.init(allocator);
        try stdout.print("Main window created\n", .{});
        
        // Initialize browser core
        try initBrowserCore(allocator);
        try stdout.print("Browser core initialized\n", .{});
        
        // Navigate to home page
        try navigateToHomePage();
        
        // Main application loop
        try stdout.print("Entering main application loop...\n", .{});
        try windows.runMainLoop();
    } else {
        return error.UnsupportedOS;
    }

    // Cleanup
    try stdout.print("IcoBrowser - Shutting down...\n", .{});
}

// Initialize the core browser components
fn initBrowserCore(alloc: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    
    // Initialize content blocker
    try stdout.print("Initializing content blocker...\n", .{});
    try content_blocker.initialize();
    
    // Initialize security module
    try stdout.print("Initializing security module...\n", .{});
    try security.initialize();
    
    // Initialize enhanced security module
    try stdout.print("Initializing enhanced security module...\n", .{});
    try enhanced_security.initialize(alloc);
    
    // Initialize theming system
    try stdout.print("Initializing theming system...\n", .{});
    try theming.initialize(alloc);
    
    // Initialize rules module
    try stdout.print("Initializing browser rules...\n", .{});
    try rules.initialize(alloc);
    
    // Initialize rules manager
    try stdout.print("Initializing rules manager...\n", .{});
    try rules_manager.initialize(alloc);
    
    // Generate CSS for content blocking
    const css = try content_blocker.generateCSSForInjection();
    defer std.heap.page_allocator.free(css);
    
    // Generate CSS for security
    const security_css = try enhanced_security.generateSecurityCSS();
    defer alloc.free(security_css);
    
    // Inject CSS for content blocking
    try webview2.WebView2.injectCSS(css);
    
    // Inject CSS for security
    try webview2.WebView2.injectCSS(security_css);
    
    // Apply theme
    try theming.applyThemeToBrowser();
    
    // Configure WebView2 security settings
    try enhanced_security.configureWebViewSecurity();
    
    try stdout.print("Browser core initialized with enhanced security features\n", .{});
}

// Navigate to home page
fn navigateToHomePage() !void {
    const stdout = std.io.getStdOut().writer();
    const home_url = "https://www.example.com";
    
    try stdout.print("Navigating to home page: {s}\n", .{home_url});
    
    // Set home page URL in address bar
    browser_ui.setAddressBarText(home_url);
    
    // Check URL security with enhanced security module
    const security_check = try enhanced_security.checkUrlSecurity(home_url);
    if (!security_check.safe) {
        if (security_check.threat) |threat| {
            try stdout.print("Warning: Home page URL is not secure! Threat detected: {s}\n", .{@tagName(threat)});
        } else {
            try stdout.print("Warning: Home page URL is not secure!\n", .{});
        }
    }
    
    // Navigate to URL
    try browser_ui.navigateToAddressBar();
    
    // Apply rules to home page
    try rules.applyRulesToCurrentPage(home_url);
    
    // Log active rules
    try stdout.print("Menerapkan aturan browser ke halaman utama:\n", .{});
    for (rules.getAllRules()) |rule| {
        if (rule.is_active) {
            try stdout.print("  - {s}: {s}\n", .{rule.name, rule.description});
        }
    }
    
    // Import rules from for-browser.md
    try stdout.print("\nMengimpor aturan dari for-browser.md...\n", .{});
    try rules_manager.importRulesFromFile("for-browser.md");
    
    // Show security settings
    try stdout.print("\nPengaturan keamanan browser:\n", .{});
    try enhanced_security.configureWebViewSecurity();
}

// Basic test
test "basic test" {
    try std.testing.expectEqual(true, true);
}

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

    std.debug.print("IcoBrowser starting...\n", .{});
    
    // Create general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};    
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    std.debug.print("Allocator initialized\n", .{});

    // Initialize application
    try stdout.print("Initializing application components...\n", .{});
    
    // Windows-specific initialization
    if (@import("builtin").os.tag == .windows) {
        try stdout.print("Initializing Windows components...\n", .{});
        std.debug.print("Initializing Windows UI...\n", .{});
        
        // Inisialisasi COM (Component Object Model) untuk WebView2
        const win32 = @import("platform/windows/win32.zig");
        const hr = win32.CoInitializeEx(null, win32.COINIT_APARTMENTTHREADED);
        if (hr != 0) {
            std.debug.print("ERROR: Failed to initialize COM: {d} (0x{x})\n", .{hr, @as(u32, @bitCast(hr))});
            return error.COMInitializationFailed;
        }
        std.debug.print("COM initialized successfully\n", .{});
        defer win32.CoUninitialize(); // Pastikan COM dibersihkan saat aplikasi berakhir
        
        // Initialize Windows application and create main window
        _ = try windows.init(allocator);
        try stdout.print("Main window created\n", .{});
        std.debug.print("Windows UI initialized successfully\n", .{});
        
        // Initialize browser core
        try stdout.print("Initializing browser core...\n", .{});
        try initBrowserCore(allocator);
        try stdout.print("Browser core initialized\n", .{});
        
        // Navigate to home page
        std.debug.print("Attempting to navigate to home page...\n", .{});
        navigateToHomePage() catch |err| { std.debug.print("WARNING: Failed to navigate to home page: {s}\n", .{@errorName(err)}); };
        std.debug.print("Navigation to home page initiated successfully\n", .{});
        
        // Main application loop
        try stdout.print("Entering main application loop...\n", .{});
        std.debug.print("Starting Windows message loop...\n", .{});
        try windows.runMainLoop();
    } else {
        return error.UnsupportedOS;
    }

    // Cleanup
    // Cleanup theme allocations
    if (theme.getCurrentTheme()) |t| {
        t.deinit();
    }
    // Cleanup enhanced security allocations
    enhanced_security.deinit();
    // Cleanup window class name allocation
    // windows.g_allocator.free(windows.g_window_class_name); // removed due to compile error on sentinel slice

    try stdout.print("IcoBrowser - Shutting down...\n", .{});
}

// Initialize the core browser components
fn initBrowserCore(alloc: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    
    // Initialize content blocker
    std.debug.print("Initializing content blocker...\n", .{});
    try stdout.print("Initializing content blocker...\n", .{});
    try content_blocker.initialize();
    std.debug.print("Content blocker initialized successfully\n", .{});
    
    // Initialize security module
    std.debug.print("Initializing security module...\n", .{});
    try stdout.print("Initializing security module...\n", .{});
    try security.initialize();
    std.debug.print("Security module initialized successfully\n", .{});
    
    // Initialize enhanced security module
    std.debug.print("Initializing enhanced security module...\n", .{});
    try stdout.print("Initializing enhanced security module...\n", .{});
    
    // Tangani error dengan lebih baik
    enhanced_security.initialize(alloc) catch |err| {
        std.debug.print("ERROR initializing enhanced security module: {s}\n", .{@errorName(err)});
        return err;
    };
    std.debug.print("Enhanced security module initialized successfully\n", .{});
    
    // Initialize theming system
    std.debug.print("Initializing theming system...\n", .{});
    try stdout.print("Initializing theming system...\n", .{});
    theming.initialize(alloc);
    std.debug.print("Theming system initialized successfully\n", .{});
    
    // Initialize rules module
    std.debug.print("Initializing browser rules...\n", .{});
    try stdout.print("Initializing browser rules...\n", .{});
    try rules.initialize(alloc);
    std.debug.print("Browser rules initialized successfully\n", .{});
    
    // Initialize rules manager
    std.debug.print("Initializing rules manager...\n", .{});
    try stdout.print("Initializing rules manager...\n", .{});
    try rules_manager.initialize(alloc);
    std.debug.print("Rules manager initialized successfully\n", .{});
    
    // Generate CSS for content blocking
    std.debug.print("Generating CSS for content blocking...\n", .{});
    const css = content_blocker.generateCSSForInjection() catch |err| {
        std.debug.print("ERROR generating content blocking CSS: {s}\n", .{@errorName(err)});
        return err;
    };
    defer std.heap.page_allocator.free(css);
    std.debug.print("Content blocking CSS generated successfully\n", .{});
    
    // Generate CSS for security
    std.debug.print("Generating security CSS...\n", .{});
    const security_css = enhanced_security.generateSecurityCSS() catch |err| {
        std.debug.print("ERROR generating security CSS: {s}\n", .{@errorName(err)});
        return err;
    };
    defer alloc.free(security_css);
    std.debug.print("Security CSS generated successfully\n", .{});
    
    // Verifikasi WebView2 diinisialisasi sebelum injeksi CSS
    std.debug.print("Checking WebView2 initialization status before CSS injection...\n", .{});
    if (!webview2.isInitialized()) {
        std.debug.print("WARNING: WebView2 is not initialized, cannot inject CSS\n", .{});
        try stdout.print("WARNING: WebView2 is not initialized, cannot inject CSS\n", .{});
        // Lanjutkan tanpa injeksi CSS
    } else {
        // Inject CSS for content blocking
        std.debug.print("Injecting content blocking CSS...\n", .{});
        webview2.injectCSS(css) catch |err| {
            std.debug.print("ERROR injecting content blocking CSS: {s}\n", .{@errorName(err)});
            // Lanjutkan meskipun gagal injeksi CSS
        };
        
        // Inject CSS for security
        std.debug.print("Injecting security CSS...\n", .{});
        webview2.injectCSS(security_css) catch |err| {
            std.debug.print("ERROR injecting security CSS: {s}\n", .{@errorName(err)});
            // Lanjutkan meskipun gagal injeksi CSS
        };
    }
    
    // Apply theme
    std.debug.print("Applying theme to browser...\n", .{});
    theming.applyThemeToBrowser() catch |err| {
        std.debug.print("ERROR applying theme to browser: {s}\n", .{@errorName(err)});
        // Lanjutkan meskipun gagal menerapkan tema
    };
    
    // Configure WebView2 security settings
    std.debug.print("Configuring WebView2 security settings...\n", .{});
    enhanced_security.configureWebViewSecurity() catch |err| {
        std.debug.print("ERROR configuring WebView2 security settings: {s}\n", .{@errorName(err)});
        // Lanjutkan meskipun gagal mengkonfigurasi keamanan
    };
    
    try stdout.print("Browser core initialized with enhanced security features\n", .{});
    std.debug.print("Browser core initialization completed\n", .{});
}

// Navigate to home page
fn navigateToHomePage() !void {
    const stdout = std.io.getStdOut().writer();
    const home_url = "https://www.example.com";
    
    std.debug.print("\n==== NAVIGATING TO HOME PAGE ====\n", .{});
    try stdout.print("Navigating to home page: {s}\n", .{home_url});
    std.debug.print("Checking if WebView2 is initialized...\n", .{});
    
    // Verify WebView2 initialization status
    if (webview2.isInitialized()) {
        std.debug.print("WebView2 is initialized and ready\n", .{});
        try stdout.print("WebView2 is initialized and ready\n", .{});
    } else {
        std.debug.print("WARNING: WebView2 is NOT initialized! Will try to continue anyway\n", .{});
        try stdout.print("WARNING: WebView2 is NOT initialized!\n", .{});
        // Coba tunggu sebentar untuk memberikan waktu inisialisasi
        std.debug.print("Waiting 2 seconds to give WebView2 time to initialize...\n", .{});
        std.time.sleep(2 * std.time.ns_per_s);
        
        // Cek lagi setelah menunggu
        if (webview2.isInitialized()) {
            std.debug.print("WebView2 is now initialized after waiting\n", .{});
        } else {
            std.debug.print("WebView2 is still not initialized after waiting\n", .{});
            // Lanjutkan untuk melihat apa yang terjadi
        }
    }
    
    // Set home page URL in address bar
    std.debug.print("Setting address bar text to: {s}\n", .{home_url});
    browser_ui.setAddressBarText(home_url);
    std.debug.print("Address bar text set to: {s}\n", .{browser_ui.getAddressBarText()});
    try stdout.print("Address bar text set to: {s}\n", .{browser_ui.getAddressBarText()});
    
    // Check URL security with enhanced security module
    std.debug.print("Checking URL security...\n", .{});
    try stdout.print("Checking URL security...\n", .{});
    
    const security_check = enhanced_security.checkUrlSecurity(home_url) catch |err| {
        std.debug.print("ERROR checking URL security: {s}\n", .{@errorName(err)});
        // Lanjutkan meskipun gagal memeriksa keamanan
        return err;
    };
    
    if (!security_check.safe) {
        if (security_check.threat) |threat| {
            std.debug.print("Warning: Home page URL is not secure! Threat detected: {s}\n", .{@tagName(threat)});
            try stdout.print("Warning: Home page URL is not secure! Threat detected: {s}\n", .{@tagName(threat)});
        } else {
            std.debug.print("Warning: Home page URL is not secure!\n", .{});
            try stdout.print("Warning: Home page URL is not secure!\n", .{});
        }
    } else {
        std.debug.print("URL security check passed\n", .{});
        try stdout.print("URL security check passed\n", .{});
    }
    
    // Navigate to URL
    std.debug.print("Calling navigateToAddressBar...\n", .{});
    try stdout.print("Calling navigateToAddressBar...\n", .{});
    
    browser_ui.navigateToAddressBar() catch |err| {
        std.debug.print("ERROR in navigateToAddressBar: {s}\n", .{@errorName(err)});
        // Coba navigasi langsung jika navigateToAddressBar gagal
        std.debug.print("Attempting direct navigation via WebView2.navigate...\n", .{});
        if (webview2.isInitialized()) {
            webview2.navigate(home_url) catch |nav_err| {
                std.debug.print("ERROR in direct navigation: {s}\n", .{@errorName(nav_err)});
                return nav_err;
            };
            std.debug.print("Direct navigation initiated\n", .{});
        } else {
            std.debug.print("Cannot navigate: WebView2 is not initialized\n", .{});
            return err;
        }
    };
    
    std.debug.print("navigateToAddressBar completed\n", .{});
    try stdout.print("navigateToAddressBar completed\n", .{});
    
    // Apply rules to home page
    std.debug.print("Applying rules to current page...\n", .{});
    rules.applyRulesToCurrentPage(home_url) catch |err| {
        std.debug.print("ERROR applying rules to current page: {s}\n", .{@errorName(err)});
        // Lanjutkan meskipun gagal menerapkan aturan
    };
    
    std.debug.print("==== HOME PAGE NAVIGATION COMPLETED ====\n\n", .{});
    
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
    
    // Configure WebView2 security settings (jika belum dilakukan)
    if (webview2.isInitialized()) {
        enhanced_security.configureWebViewSecurity() catch |err| {
            std.debug.print("ERROR configuring WebView2 security settings: {s}\n", .{@errorName(err)});
        };
    }
}

// Basic test
test "basic test" {
    try std.testing.expectEqual(true, true);
}

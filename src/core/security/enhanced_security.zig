const std = @import("std");
const webview2 = @import("../../platform/windows/webview2.zig");
const security = @import("../../security.zig");

// Enhanced Security Module untuk IcoBrowser
// Mengelola fitur keamanan tambahan untuk browser pribadi

// Tingkat keamanan
pub const SecurityLevel = enum {
    low,
    medium,
    high,
    custom,
};

// Jenis ancaman
pub const ThreatType = enum {
    malware,
    phishing,
    unwanted_software,
    tracking,
    cryptomining,
    social_engineering,
    insecure_connection,
};

// Status modul
var is_initialized: bool = false;
var current_security_level: SecurityLevel = .medium;
var allocator: std.mem.Allocator = undefined;

// Daftar domain yang diblokir berdasarkan kategori
var blocked_domains = std.StringHashMap(ThreatType).init(std.heap.page_allocator);

// Pengaturan keamanan
var enforce_https: bool = true;
var block_third_party_cookies: bool = true;
var block_popups: bool = true;
var block_autoplay: bool = true;
var block_notifications: bool = true;
var safe_browsing_enabled: bool = true;
var do_not_track: bool = true;
var javascript_enabled: bool = true;
var webrtc_enabled: bool = false;

// Inisialisasi modul keamanan tambahan
pub fn initialize(alloc: std.mem.Allocator) !void {
    if (is_initialized) return;
    
    allocator = alloc;
    is_initialized = true;
    
    // Tambahkan domain berbahaya default
    try addBlockedDomain("malware-site.com", .malware);
    try addBlockedDomain("phishing-example.net", .phishing);
    try addBlockedDomain("cryptominer.org", .cryptomining);
    try addBlockedDomain("tracker.analytics.com", .tracking);
    
    // Sesuaikan pengaturan berdasarkan tingkat keamanan default
    try setSecurityLevel(.medium);
    
    // is_initialized = true; // moved before addBlockedDomain calls
}

// Mengatur tingkat keamanan
pub fn setSecurityLevel(level: SecurityLevel) !void {
    if (!is_initialized) return error.SecurityModuleNotInitialized;
    
    current_security_level = level;
    
    switch (level) {
        .low => {
            enforce_https = false;
            block_third_party_cookies = false;
            block_popups = true;
            block_autoplay = false;
            block_notifications = false;
            safe_browsing_enabled = true;
            do_not_track = false;
            javascript_enabled = true;
            webrtc_enabled = true;
        },
        .medium => {
            enforce_https = true;
            block_third_party_cookies = true;
            block_popups = true;
            block_autoplay = true;
            block_notifications = true;
            safe_browsing_enabled = true;
            do_not_track = true;
            javascript_enabled = true;
            webrtc_enabled = false;
        },
        .high => {
            enforce_https = true;
            block_third_party_cookies = true;
            block_popups = true;
            block_autoplay = true;
            block_notifications = true;
            safe_browsing_enabled = true;
            do_not_track = true;
            javascript_enabled = false;
            webrtc_enabled = false;
        },
        .custom => {
            // Pengaturan kustom tidak diubah
        },
    }
}

// Menambahkan domain yang diblokir
pub fn addBlockedDomain(domain: []const u8, threat_type: ThreatType) !void {
    if (!is_initialized) return error.SecurityModuleNotInitialized;
    
    const domain_dup = try allocator.dupe(u8, domain);
    try blocked_domains.put(domain_dup, threat_type);
    
    // Tambahkan juga ke modul keamanan dasar
    try security.SecurityModule.addBlockedDomain(domain);
}

// Menghapus domain yang diblokir
pub fn removeBlockedDomain(domain: []const u8) !void {
    if (!is_initialized) return error.SecurityModuleNotInitialized;
    
    if (blocked_domains.get(domain)) |_| {
        const domain_key = blocked_domains.getKey(domain) orelse return error.DomainNotFound;
        _ = blocked_domains.remove(domain);
        allocator.free(domain_key);
    }
    
    // Hapus juga dari modul keamanan dasar
    try security.SecurityModule.removeBlockedDomain(domain);
}

// Memeriksa apakah domain diblokir
pub fn isDomainBlocked(domain: []const u8) bool {
    if (!is_initialized) return false;
    
    return blocked_domains.contains(domain) or security.SecurityModule.isDomainBlocked(domain);
}

// Memeriksa keamanan URL

// Deinitialize enhanced security module
pub fn deinit() void {
    if (!is_initialized) return;
    // Free all domain keys
    var it = blocked_domains.iterator();
    while (it.next()) |entry| {
        // entry.key_ptr adalah pointer ke slice, jadi kita harus mengakses slice-nya dulu
        const key: []const u8 = entry.key_ptr.*;
        allocator.free(key);
    }
    blocked_domains.deinit();
    is_initialized = false;
}

// Menghasilkan header keamanan untuk permintaan
pub fn checkUrlSecurity(url: []const u8) !struct { safe: bool, threat: ?ThreatType } {
    if (!is_initialized) return error.SecurityModuleNotInitialized;
    
    // Periksa HTTPS jika diaktifkan
    if (enforce_https and !security.SecurityModule.isHttps(url)) {
        return .{ .safe = false, .threat = .insecure_connection };
    }
    
    // Ekstrak domain dari URL
    var domain: []const u8 = url;
    
    // Lewati protokol
    if (std.mem.indexOf(u8, url, "://")) |protocol_end| {
        domain = url[protocol_end + 3..];
    }
    
    // Hapus path
    if (std.mem.indexOf(u8, domain, "/")) |path_start| {
        domain = domain[0..path_start];
    }
    
    // Periksa domain yang diblokir
    if (blocked_domains.get(domain)) |threat| {
        return .{ .safe = false, .threat = threat };
    }
    
    // Periksa domain yang diblokir di modul keamanan dasar
    if (security.SecurityModule.isDomainBlocked(domain)) {
        return .{ .safe = false, .threat = .malware };
    }
    
    return .{ .safe = true, .threat = null };
}

// Menghasilkan header keamanan untuk permintaan
pub fn generateSecurityHeaders() !std.StringHashMap([]const u8) {
    if (!is_initialized) return error.SecurityModuleNotInitialized;
    
    var headers = std.StringHashMap([]const u8).init(allocator);
    
    // Content Security Policy
    try headers.put("Content-Security-Policy", "default-src 'self'; script-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline';");
    
    // X-Content-Type-Options
    try headers.put("X-Content-Type-Options", "nosniff");
    
    // X-Frame-Options
    try headers.put("X-Frame-Options", "SAMEORIGIN");
    
    // Referrer-Policy
    try headers.put("Referrer-Policy", "strict-origin-when-cross-origin");
    
    // Permissions-Policy
    try headers.put("Permissions-Policy", "camera=(), microphone=(), geolocation=()");
    
    // Do Not Track
    if (do_not_track) {
        try headers.put("DNT", "1");
    }
    
    return headers;
}

// Mengatur pengaturan WebView2 berdasarkan pengaturan keamanan
pub fn configureWebViewSecurity() !void {
    if (!is_initialized) return error.SecurityModuleNotInitialized;
    
    // Dalam implementasi nyata, kita akan mengonfigurasi WebView2 dengan pengaturan keamanan
    std.debug.print("Mengonfigurasi keamanan WebView2:\n", .{});
    std.debug.print("  - HTTPS Enforcement: {}\n", .{enforce_https});
    std.debug.print("  - Block Third-Party Cookies: {}\n", .{block_third_party_cookies});
    std.debug.print("  - Block Popups: {}\n", .{block_popups});
    std.debug.print("  - Block Autoplay: {}\n", .{block_autoplay});
    std.debug.print("  - Block Notifications: {}\n", .{block_notifications});
    std.debug.print("  - Safe Browsing: {}\n", .{safe_browsing_enabled});
    std.debug.print("  - Do Not Track: {}\n", .{do_not_track});
    std.debug.print("  - JavaScript Enabled: {}\n", .{javascript_enabled});
    std.debug.print("  - WebRTC Enabled: {}\n", .{webrtc_enabled});
}

// Menghasilkan CSS untuk keamanan
pub fn generateSecurityCSS() ![]const u8 {
    if (!is_initialized) return error.SecurityModuleNotInitialized;
    
    var css = std.ArrayList(u8).init(allocator);
    defer css.deinit();
    
    const writer = css.writer();
    
    try writer.writeAll("/* IcoBrowser Security CSS */\n");
    
    // Sembunyikan elemen berbahaya
    try writer.writeAll("iframe[src*=\"ads\"], iframe[src*=\"tracker\"], div[class*=\"cookie-banner\"] { display: none !important; }\n");
    
    // Tambahkan indikator visual untuk keamanan
    try writer.writeAll(".icobrowser-security-indicator { position: fixed; top: 0; right: 0; z-index: 9999; padding: 5px; }\n");
    try writer.writeAll(".icobrowser-security-indicator.secure { background-color: green; color: white; }\n");
    try writer.writeAll(".icobrowser-security-indicator.insecure { background-color: red; color: white; }\n");
    
    return css.toOwnedSlice();
}

// Menangani permintaan izin
pub fn handlePermissionRequest(permission: []const u8, origin: []const u8) !bool {
    if (!is_initialized) return error.SecurityModuleNotInitialized;
    
    std.debug.print("Permintaan izin: {s} dari {s}\n", .{permission, origin});
    
    // Periksa izin berdasarkan pengaturan keamanan
    if (std.mem.eql(u8, permission, "notifications") and block_notifications) {
        return false;
    }
    
    if (std.mem.eql(u8, permission, "camera") or std.mem.eql(u8, permission, "microphone")) {
        // Selalu minta konfirmasi untuk akses kamera dan mikrofon
        // Dalam implementasi nyata, kita akan menampilkan dialog konfirmasi
        return false;
    }
    
    // Periksa izin di modul keamanan dasar
    return security.SecurityModule.checkPermission(permission);
}



const std = @import("std");
const content_blocker = @import("core/security/content_blocker.zig");

// Security module untuk IcoBrowser
// Mengelola fitur keamanan seperti HTTPS enforcement, permission management, dan domain blocking

// Security state
var is_initialized: bool = false;
var blocked_domains = std.ArrayList([]const u8).init(std.heap.page_allocator);
var permission_settings = std.StringHashMap(bool).init(std.heap.page_allocator);

// Security module
pub const SecurityModule = struct {
    // Initialize security module
    pub fn initialize() !void {
        if (is_initialized) return;
        
        // Add default blocked domains
        try blocked_domains.append("malware-example.com");
        try blocked_domains.append("phishing-example.com");
        try blocked_domains.append("unsafe-example.com");
        
        // Add default permission settings
        try permission_settings.put("geolocation", false);
        try permission_settings.put("notifications", false);
        try permission_settings.put("camera", false);
        try permission_settings.put("microphone", false);
        try permission_settings.put("clipboard", false);
        
        is_initialized = true;
    }
    
    // Check URL security
    pub fn checkUrlSecurity(url: []const u8) !bool {
        if (!is_initialized) return error.SecurityModuleNotInitialized;
        
        // Check if URL is HTTPS
        if (!isHttps(url)) {
            std.debug.print("Warning: Non-HTTPS URL: {s}\n", .{url});
            return false;
        }
        
        // Check if domain is blocked
        if (isDomainBlocked(url)) {
            std.debug.print("Warning: Blocked domain in URL: {s}\n", .{url});
            return false;
        }
        
        return true;
    }
    
    // Check if URL is HTTPS
    pub fn isHttps(url: []const u8) bool {
        return std.mem.startsWith(u8, url, "https://");
    }
    
    // Check if domain is blocked
    pub fn isDomainBlocked(url: []const u8) bool {
        // Extract domain from URL
        var domain: []const u8 = url;
        
        // Skip protocol
        if (std.mem.indexOf(u8, url, "://")) |protocol_end| {
            domain = url[protocol_end + 3..];
        }
        
        // Remove path
        if (std.mem.indexOf(u8, domain, "/")) |path_start| {
            domain = domain[0..path_start];
        }
        
        // Check if domain is in blocked list
        for (blocked_domains.items) |blocked_domain| {
            if (std.mem.indexOf(u8, domain, blocked_domain) != null) {
                return true;
            }
        }
        
        return false;
    }
    
    // Check permission
    pub fn checkPermission(permission: []const u8) bool {
        if (!is_initialized) return false;
        
        if (permission_settings.get(permission)) |allowed| {
            return allowed;
        }
        
        return false;
    }
    
    // Set permission
    pub fn setPermission(permission: []const u8, allowed: bool) !void {
        if (!is_initialized) return error.SecurityModuleNotInitialized;
        
        try permission_settings.put(permission, allowed);
    }
    
    // Add blocked domain
    pub fn addBlockedDomain(domain: []const u8) !void {
        if (!is_initialized) return error.SecurityModuleNotInitialized;
        
        try blocked_domains.append(domain);
    }
    
    // Remove blocked domain
    pub fn removeBlockedDomain(domain: []const u8) !void {
        if (!is_initialized) return error.SecurityModuleNotInitialized;
        
        for (blocked_domains.items, 0..) |blocked_domain, i| {
            if (std.mem.eql(u8, blocked_domain, domain)) {
                _ = blocked_domains.orderedRemove(i);
                break;
            }
        }
    }
    
    // Get blocked domains
    pub fn getBlockedDomains() []const []const u8 {
        return blocked_domains.items;
    }
    
    // Clean up
    pub fn deinit() void {
        for (blocked_domains.items) |domain| {
            std.heap.page_allocator.free(domain);
        }
        blocked_domains.deinit();
        
        var it = permission_settings.iterator();
        while (it.next()) |entry| {
            std.heap.page_allocator.free(entry.key_ptr.*);
        }
        permission_settings.deinit();
        
        is_initialized = false;
    }
};

// Initialize security module
pub fn initialize() !void {
    try SecurityModule.initialize();
}

const std = @import("std");

// Content Blocker Module for IcoBrowser
// Handles blocking of ads, popups, and unwanted content

// Content blocking rules structure
pub const BlockingRule = struct {
    // Rule type (CSS selector, URL pattern, etc)
    rule_type: enum {
        css_selector,
        url_pattern,
        domain,
    },
    
    // Rule pattern
    pattern: []const u8,
    
    // Rule description
    description: []const u8,
    
    // Category of content to block
    category: enum {
        advertising,
        social_media_clutter,
        gambling,
        malware,
        tracking,
        other,
    },
};

// Default rules for content blocking
const default_rules = [_]BlockingRule{
    // Hide ads
    .{
        .rule_type = .css_selector,
        .pattern = "div[class*=\"ad-\"], div[class*=\"ads-\"], div[id*=\"ad-\"], div[id*=\"ads-\"]",
        .description = "Generic ad containers",
        .category = .advertising,
    },
    
    // Block gambling sites (domain-based)
    .{
        .rule_type = .domain,
        .pattern = "*.gambling.com, *.casino.com, *.bet.com",
        .description = "Common gambling domains",
        .category = .gambling,
    },
    
    // Hide Twitter/X sidebar elements
    .{
        .rule_type = .css_selector,
        .pattern = "[data-testid=\"sidebarColumn\"]",
        .description = "Twitter/X sidebar",
        .category = .social_media_clutter,
    },
};

// Content blocker state
var rules = std.ArrayList(BlockingRule).init(std.heap.page_allocator);
var initialized = false;

// Initialize the content blocker
pub fn initialize() !void {
    if (initialized) return;
    
    // Add default rules
    for (default_rules) |rule| {
        try rules.append(rule);
    }
    
    initialized = true;
}

// Generate CSS for injection based on CSS selector rules
pub fn generateCSSForInjection() ![]const u8 {
    var css = std.ArrayList(u8).init(std.heap.page_allocator);
    defer css.deinit();
    
    const writer = css.writer();
    
    try writer.writeAll("/* IcoBrowser Content Blocking CSS */\n");
    
    for (rules.items) |rule| {
        if (rule.rule_type == .css_selector) {
            try writer.print("{s} {{ display: none !important; }}\n", .{rule.pattern});
        }
    }
    
    return css.toOwnedSlice();
}

// Check if a URL should be blocked
pub fn shouldBlockUrl(url: []const u8) bool {
    _ = url; // Will be implemented in future milestones
    return false;
}

// Add a custom blocking rule
pub fn addRule(rule: BlockingRule) !void {
    try rules.append(rule);
}

// Remove a blocking rule by pattern
pub fn removeRule(pattern: []const u8) void {
    var i: usize = 0;
    while (i < rules.items.len) {
        if (std.mem.eql(u8, rules.items[i].pattern, pattern)) {
            _ = rules.orderedRemove(i);
        } else {
            i += 1;
        }
    }
}

// Clean up resources
pub fn deinit() void {
    rules.deinit();
    initialized = false;
}

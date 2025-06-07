const std = @import("std");
const webview2 = @import("../platform/windows/webview2.zig");

// Rules Module untuk IcoBrowser
// Mengelola aturan browser seperti mode gelap universal dan penyembunyian elemen

// Struktur aturan browser
pub const BrowserRule = struct {
    // Nama aturan
    name: []const u8,
    
    // Deskripsi aturan
    description: []const u8,
    
    // Pola URL yang cocok dengan aturan
    url_patterns: []const []const u8,
    
    // Tipe aksi
    action_type: enum {
        inject_css,
        inject_js,
        block_request,
        modify_headers,
    },
    
    // Konten aksi (CSS atau JavaScript)
    action_content: []const u8,
    
    // Apakah aturan aktif
    is_active: bool,
    
    // Apakah aturan dijalankan saat halaman dimuat
    on_load: bool,
};

// Aturan default
const default_rules = [_]BrowserRule{
    // UniversalDarkMode
    .{
        .name = "UniversalDarkMode",
        .description = "Menerapkan tema gelap sederhana ke semua situs web.",
        .url_patterns = &[_][]const u8{"*://*/*"},
        .action_type = .inject_css,
        .action_content = 
            \\/* Ini adalah filter CSS sederhana untuk membalik warna, cara cepat untuk mode gelap */
            \\html {
            \\  filter: invert(1) hue-rotate(180deg);
            \\  /* Memastikan gambar dan video tidak ikut terbalik warnanya */
            \\  background-color: #fdfdfd;
            \\}
            \\img, video, iframe {
            \\  filter: invert(1) hue-rotate(180deg);
            \\}
        ,
        .is_active = false, // Default tidak aktif
        .on_load = true,
    },
    
    // SocialMediaZen
    .{
        .name = "SocialMediaZen",
        .description = "Menyembunyikan elemen yang mengganggu di media sosial.",
        .url_patterns = &[_][]const u8{
            "*://x.com/*",
            "*://twitter.com/*",
        },
        .action_type = .inject_css,
        .action_content = 
            \\/* Sembunyikan sidebar 'Trends' dan 'Who to follow' */
            \\[data-testid="sidebarColumn"] {
            \\  display: none !important;
            \\}
        ,
        .is_active = true, // Default aktif
        .on_load = true,
    },
};

// Status modul rules
var rules = std.ArrayList(BrowserRule).init(std.heap.page_allocator);
var initialized = false;
var allocator: std.mem.Allocator = undefined;

// Inisialisasi modul rules
pub fn initialize(alloc: std.mem.Allocator) !void {
    if (initialized) return;
    
    allocator = alloc;
    
    // Tambahkan aturan default
    for (default_rules) |rule| {
        try rules.append(rule);
    }
    
    initialized = true;
}

// Menghasilkan CSS untuk aturan yang aktif berdasarkan URL
pub fn generateCSSForUrl(url: []const u8) ![]const u8 {
    if (!initialized) return error.RulesModuleNotInitialized;
    
    var css = std.ArrayList(u8).init(allocator);
    defer css.deinit();
    
    const writer = css.writer();
    
    try writer.writeAll("/* IcoBrowser Rules CSS */\n");
    
    for (rules.items) |rule| {
        if (!rule.is_active or rule.action_type != .inject_css) continue;
        
        // Periksa apakah URL cocok dengan pola
        const url_match = for (rule.url_patterns) |pattern| {
            if (matchUrlPattern(url, pattern)) break true;
        } else false;
        
        if (url_match) {
            try writer.print("/* {s} */\n{s}\n\n", .{rule.name, rule.action_content});
        }
    }
    
    return css.toOwnedSlice();
}

// Mencocokkan URL dengan pola
fn matchUrlPattern(url: []const u8, pattern: []const u8) bool {
    // Implementasi sederhana untuk pencocokan pola wildcard
    // Contoh: "*://example.com/*" akan cocok dengan "http://example.com/page"
    
    // Jika pola adalah "*", cocok dengan semua URL
    if (std.mem.eql(u8, pattern, "*")) return true;
    
    // Jika pola diakhiri dengan "*", periksa awalan
    if (pattern[pattern.len - 1] == '*') {
        const prefix = pattern[0 .. pattern.len - 1];
        return std.mem.startsWith(u8, url, prefix);
    }
    
    // Jika pola diawali dengan "*", periksa akhiran
    if (pattern[0] == '*') {
        const suffix = pattern[1..];
        return std.mem.endsWith(u8, url, suffix);
    }
    
    // Jika pola berisi "*" di tengah, periksa awalan dan akhiran
    if (std.mem.indexOf(u8, pattern, "*")) |star_pos| {
        const prefix = pattern[0..star_pos];
        const suffix = pattern[star_pos + 1 ..];
        
        return std.mem.startsWith(u8, url, prefix) and std.mem.endsWith(u8, url, suffix);
    }
    
    // Jika tidak ada wildcard, periksa kesamaan persis
    return std.mem.eql(u8, url, pattern);
}

// Mengaktifkan aturan berdasarkan nama
pub fn enableRule(name: []const u8) !void {
    if (!initialized) return error.RulesModuleNotInitialized;
    
    for (rules.items, 0..) |*rule, i| {
        if (std.mem.eql(u8, rule.name, name)) {
            rules.items[i].is_active = true;
            return;
        }
    }
    
    return error.RuleNotFound;
}

// Menonaktifkan aturan berdasarkan nama
pub fn disableRule(name: []const u8) !void {
    if (!initialized) return error.RulesModuleNotInitialized;
    
    for (rules.items, 0..) |*rule, i| {
        if (std.mem.eql(u8, rule.name, name)) {
            rules.items[i].is_active = false;
            return;
        }
    }
    
    return error.RuleNotFound;
}

// Menambahkan aturan baru
pub fn addRule(rule: BrowserRule) !void {
    if (!initialized) return error.RulesModuleNotInitialized;
    
    try rules.append(rule);
}

// Menghapus aturan berdasarkan nama
pub fn removeRule(name: []const u8) !void {
    if (!initialized) return error.RulesModuleNotInitialized;
    
    for (rules.items, 0..) |rule, i| {
        if (std.mem.eql(u8, rule.name, name)) {
            _ = rules.orderedRemove(i);
            return;
        }
    }
    
    return error.RuleNotFound;
}

// Mendapatkan semua aturan
pub fn getAllRules() []const BrowserRule {
    return rules.items;
}

// Menerapkan aturan ke halaman web saat ini
pub fn applyRulesToCurrentPage(url: []const u8) !void {
    if (!initialized) return error.RulesModuleNotInitialized;
    
    // Hasilkan CSS untuk URL saat ini
    const css = try generateCSSForUrl(url);
    defer allocator.free(css);
    
    // Terapkan CSS ke WebView2
    try webview2.WebView2.injectCSS(css);
}

// Membersihkan sumber daya
pub fn deinit() void {
    rules.deinit();
    initialized = false;
}

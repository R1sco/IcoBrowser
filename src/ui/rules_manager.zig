const std = @import("std");
const rules = @import("../core/rules.zig");
const webview2 = @import("../platform/windows/webview2.zig");
const win32 = @import("../platform/windows/win32.zig");

// Rules Manager UI untuk IcoBrowser
// Mengelola tampilan dan interaksi untuk aturan browser

// Status
var allocator: std.mem.Allocator = undefined;
var is_initialized: bool = false;

// Inisialisasi rules manager
pub fn initialize(alloc: std.mem.Allocator) !void {
    if (is_initialized) return;
    
    allocator = alloc;
    is_initialized = true;
}

// Mengaktifkan atau menonaktifkan aturan
pub fn toggleRule(rule_name: []const u8) !void {
    if (!is_initialized) return error.RulesManagerNotInitialized;
    
    // Dapatkan semua aturan
    const all_rules = rules.getAllRules();
    
    // Cari aturan dengan nama yang sesuai
    for (all_rules) |rule| {
        if (std.mem.eql(u8, rule.name, rule_name)) {
            if (rule.is_active) {
                // Nonaktifkan aturan
                try rules.disableRule(rule_name);
                std.debug.print("Aturan '{s}' dinonaktifkan\n", .{rule_name});
            } else {
                // Aktifkan aturan
                try rules.enableRule(rule_name);
                std.debug.print("Aturan '{s}' diaktifkan\n", .{rule_name});
            }
            
            // Terapkan perubahan ke halaman saat ini
            // Dalam implementasi nyata, kita akan mendapatkan URL saat ini dari WebView2
            try rules.applyRulesToCurrentPage("https://www.example.com");
            
            return;
        }
    }
    
    return error.RuleNotFound;
}

// Menampilkan dialog pengaturan aturan
pub fn showRulesDialog(hwnd: win32.HWND) !void {
    _ = hwnd; // Akan digunakan dalam implementasi nyata untuk dialog Win32
    if (!is_initialized) return error.RulesManagerNotInitialized;
    
    // Dalam implementasi nyata, kita akan menampilkan dialog Win32
    // Untuk saat ini, kita hanya menampilkan aturan di konsol
    
    std.debug.print("=== Pengaturan Aturan Browser ===\n", .{});
    
    // Dapatkan semua aturan
    const all_rules = rules.getAllRules();
    
    for (all_rules, 0..) |rule, i| {
        std.debug.print("{d}. [{s}] {s}: {s}\n", .{
            i + 1,
            if (rule.is_active) "✓" else " ",
            rule.name,
            rule.description,
        });
        
        // Tampilkan pola URL
        std.debug.print("   URL: ", .{});
        for (rule.url_patterns) |pattern| {
            std.debug.print("{s} ", .{pattern});
        }
        std.debug.print("\n", .{});
    }
    
    std.debug.print("==============================\n", .{});
}

// Menambahkan aturan baru
pub fn addNewRule(
    name: []const u8,
    description: []const u8,
    url_patterns: []const []const u8,
    action_type: rules.BrowserRule.action_type,
    action_content: []const u8,
    on_load: bool,
) !void {
    if (!is_initialized) return error.RulesManagerNotInitialized;
    
    // Duplikasi string untuk memastikan mereka tetap valid
    const name_dup = try allocator.dupe(u8, name);
    const desc_dup = try allocator.dupe(u8, description);
    const content_dup = try allocator.dupe(u8, action_content);
    
    // Duplikasi array pola URL
    var patterns = std.ArrayList([]const u8).init(allocator);
    defer patterns.deinit();
    
    for (url_patterns) |pattern| {
        const pattern_dup = try allocator.dupe(u8, pattern);
        try patterns.append(pattern_dup);
    }
    
    // Buat aturan baru
    const new_rule = rules.BrowserRule{
        .name = name_dup,
        .description = desc_dup,
        .url_patterns = patterns.toOwnedSlice(),
        .action_type = action_type,
        .action_content = content_dup,
        .is_active = true,
        .on_load = on_load,
    };
    
    // Tambahkan aturan
    try rules.addRule(new_rule);
    
    std.debug.print("Aturan baru '{s}' ditambahkan\n", .{name});
}

// Menghapus aturan
pub fn deleteRule(rule_name: []const u8) !void {
    if (!is_initialized) return error.RulesManagerNotInitialized;
    
    try rules.removeRule(rule_name);
    std.debug.print("Aturan '{s}' dihapus\n", .{rule_name});
}

// Mengimpor aturan dari file
pub fn importRulesFromFile(file_path: []const u8) !void {
    if (!is_initialized) return error.RulesManagerNotInitialized;
    
    // Dalam implementasi nyata, kita akan membaca file dan mengimpor aturan
    std.debug.print("Mengimpor aturan dari file: {s}\n", .{file_path});
    
    // Contoh implementasi sederhana untuk mengimpor aturan dari file for-browser.md
    if (std.mem.eql(u8, file_path, "for-browser.md")) {
        // Tambahkan aturan UniversalDarkMode
        try addNewRule(
            "UniversalDarkMode",
            "Menerapkan tema gelap sederhana ke semua situs web.",
            &[_][]const u8{"*://*/*"},
            .inject_css,
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
            true,
        );
        
        // Tambahkan aturan SocialMediaZen
        try addNewRule(
            "SocialMediaZen",
            "Menyembunyikan elemen yang mengganggu di media sosial.",
            &[_][]const u8{
                "*://x.com/*",
                "*://twitter.com/*",
            },
            .inject_css,
            \\/* Sembunyikan sidebar 'Trends' dan 'Who to follow' */
            \\[data-testid="sidebarColumn"] {
            \\  display: none !important;
            \\}
            ,
            true,
        );
    }
}

// Mengekspor aturan ke file
pub fn exportRulesToFile(file_path: []const u8) !void {
    if (!is_initialized) return error.RulesManagerNotInitialized;
    
    // Dalam implementasi nyata, kita akan menulis aturan ke file
    std.debug.print("Mengekspor aturan ke file: {s}\n", .{file_path});
}

// Membersihkan sumber daya
pub fn deinit() void {
    is_initialized = false;
}

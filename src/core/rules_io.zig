const std = @import("std");
const rules = @import("rules.zig");
const fs = std.fs;
const json = std.json;

// Rules IO - Modul untuk mengimpor dan mengekspor aturan browser
// Mendukung format file JSON dan Markdown

// Status
var allocator: std.mem.Allocator = undefined;
var is_initialized: bool = false;

// Inisialisasi modul
pub fn initialize(alloc: std.mem.Allocator) !void {
    if (is_initialized) return;
    
    allocator = alloc;
    is_initialized = true;
}

// Mengimpor aturan dari file JSON
pub fn importFromJson(file_path: []const u8) !void {
    if (!is_initialized) return error.RulesIONotInitialized;
    
    // Buka file
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();
    
    // Baca konten file
    const content = try file.readToEndAlloc(allocator, 1024 * 1024); // Batas 1MB
    defer allocator.free(content);
    
    // Parse JSON
    var parser = json.Parser.init(allocator, false);
    defer parser.deinit();
    
    var tree = try parser.parse(content);
    defer tree.deinit();
    
    const root = tree.root;
    
    // Pastikan root adalah array
    const rules_array = root.Array.items;
    
    // Iterasi setiap aturan
    for (rules_array) |rule_value| {
        const rule_obj = rule_value.Object;
        
        // Dapatkan nilai-nilai aturan
        const name = rule_obj.get("name").?.String;
        const description = rule_obj.get("description").?.String;
        const action_type_str = rule_obj.get("action_type").?.String;
        const action_content = rule_obj.get("action_content").?.String;
        const on_load = rule_obj.get("on_load").?.Bool;
        const is_active = rule_obj.get("is_active").?.Bool;
        
        // Parse action_type
        var action_type: rules.BrowserRule.action_type = .inject_css;
        if (std.mem.eql(u8, action_type_str, "inject_css")) {
            action_type = .inject_css;
        } else if (std.mem.eql(u8, action_type_str, "block_request")) {
            action_type = .block_request;
        } else if (std.mem.eql(u8, action_type_str, "redirect")) {
            action_type = .redirect;
        }
        
        // Dapatkan array URL patterns
        const patterns_array = rule_obj.get("url_patterns").?.Array.items;
        var patterns = std.ArrayList([]const u8).init(allocator);
        defer patterns.deinit();
        
        for (patterns_array) |pattern_value| {
            const pattern = pattern_value.String;
            const pattern_dup = try allocator.dupe(u8, pattern);
            try patterns.append(pattern_dup);
        }
        
        // Duplikasi string
        const name_dup = try allocator.dupe(u8, name);
        const desc_dup = try allocator.dupe(u8, description);
        const content_dup = try allocator.dupe(u8, action_content);
        
        // Buat aturan baru
        const new_rule = rules.BrowserRule{
            .name = name_dup,
            .description = desc_dup,
            .url_patterns = patterns.toOwnedSlice(),
            .action_type = action_type,
            .action_content = content_dup,
            .is_active = is_active,
            .on_load = on_load,
        };
        
        // Tambahkan aturan
        try rules.addRule(new_rule);
    }
}

// Mengekspor aturan ke file JSON
pub fn exportToJson(file_path: []const u8) !void {
    if (!is_initialized) return error.RulesIONotInitialized;
    
    // Dapatkan semua aturan
    const all_rules = rules.getAllRules();
    
    // Buat array JSON
    var array = std.ArrayList(std.json.Value).init(allocator);
    defer array.deinit();
    
    // Iterasi setiap aturan
    for (all_rules) |rule| {
        // Buat objek untuk aturan
        var rule_obj = std.StringHashMap(std.json.Value).init(allocator);
        
        // Tambahkan properti aturan
        try rule_obj.put("name", std.json.Value{ .String = rule.name });
        try rule_obj.put("description", std.json.Value{ .String = rule.description });
        
        // Konversi action_type ke string
        const action_type_str = switch (rule.action_type) {
            .inject_css => "inject_css",
            .block_request => "block_request",
            .redirect => "redirect",
        };
        try rule_obj.put("action_type", std.json.Value{ .String = action_type_str });
        
        try rule_obj.put("action_content", std.json.Value{ .String = rule.action_content });
        try rule_obj.put("on_load", std.json.Value{ .Bool = rule.on_load });
        try rule_obj.put("is_active", std.json.Value{ .Bool = rule.is_active });
        
        // Buat array untuk URL patterns
        var patterns_array = std.ArrayList(std.json.Value).init(allocator);
        for (rule.url_patterns) |pattern| {
            try patterns_array.append(std.json.Value{ .String = pattern });
        }
        
        try rule_obj.put("url_patterns", std.json.Value{ .Array = patterns_array.toOwnedSlice() });
        
        // Tambahkan objek aturan ke array utama
        try array.append(std.json.Value{ .Object = rule_obj });
    }
    
    // Konversi ke JSON
    const json_root = std.json.Value{ .Array = array.toOwnedSlice() };
    
    // Buat file
    const file = try fs.cwd().createFile(file_path, .{});
    defer file.close();
    
    // Tulis JSON ke file
    try std.json.stringify(json_root, .{}, file.writer());
}

// Mengimpor aturan dari file Markdown
pub fn importFromMarkdown(file_path: []const u8) !void {
    if (!is_initialized) return error.RulesIONotInitialized;
    
    // Buka file
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();
    
    // Baca konten file
    const content = try file.readToEndAlloc(allocator, 1024 * 1024); // Batas 1MB
    defer allocator.free(content);
    
    // Parsing format Markdown sederhana
    var lines = std.mem.split(u8, content, "\n");
    
    var current_rule_name: ?[]const u8 = null;
    var current_rule_description: ?[]const u8 = null;
    var current_url_patterns = std.ArrayList([]const u8).init(allocator);
    var current_action_type: ?rules.BrowserRule.action_type = null;
    var current_action_content = std.ArrayList(u8).init(allocator);
    var current_on_load: bool = true;
    var in_style_block: bool = false;
    
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        
        if (trimmed.len == 0) continue;
        
        if (std.mem.startsWith(u8, trimmed, "name:")) {
            // Simpan aturan sebelumnya jika ada
            try saveCurrentRule(
                &current_rule_name, 
                &current_rule_description, 
                &current_url_patterns, 
                &current_action_type, 
                &current_action_content,
                &current_on_load
            );
            
            // Mulai aturan baru
            const name_value = std.mem.trim(u8, trimmed[5..], " \t\r\n\"");
            current_rule_name = try allocator.dupe(u8, name_value);
            current_url_patterns.clearRetainingCapacity();
            current_action_content.clearRetainingCapacity();
        } else if (std.mem.startsWith(u8, trimmed, "description:")) {
            const desc_value = std.mem.trim(u8, trimmed[12..], " \t\r\n\"");
            current_rule_description = try allocator.dupe(u8, desc_value);
        } else if (std.mem.startsWith(u8, trimmed, "match:")) {
            // Bagian match akan diproses di baris berikutnya
        } else if (std.mem.startsWith(u8, trimmed, "url_patterns:")) {
            // URL patterns akan diproses di baris berikutnya
        } else if (std.mem.startsWith(u8, trimmed, "- \"") or std.mem.startsWith(u8, trimmed, "    - \"")) {
            // URL pattern
            var pattern = std.mem.trim(u8, trimmed, " \t\r\n-");
            pattern = std.mem.trim(u8, pattern, "\"");
            const pattern_dup = try allocator.dupe(u8, pattern);
            try current_url_patterns.append(pattern_dup);
        } else if (std.mem.startsWith(u8, trimmed, "actions:")) {
            // Bagian actions akan diproses di baris berikutnya
        } else if (std.mem.startsWith(u8, trimmed, "- type:")) {
            // Action type
            const type_value = std.mem.trim(u8, trimmed[7..], " \t\r\n\"");
            if (std.mem.eql(u8, type_value, "inject_css")) {
                current_action_type = .inject_css;
            } else if (std.mem.eql(u8, type_value, "block_request")) {
                current_action_type = .block_request;
            } else if (std.mem.eql(u8, type_value, "redirect")) {
                current_action_type = .redirect;
            }
        } else if (std.mem.startsWith(u8, trimmed, "on_load:")) {
            const on_load_value = std.mem.trim(u8, trimmed[8..], " \t\r\n");
            current_on_load = std.mem.eql(u8, on_load_value, "true");
        } else if (std.mem.startsWith(u8, trimmed, "style:") or std.mem.startsWith(u8, trimmed, "    style:")) {
            in_style_block = true;
        } else if (in_style_block) {
            if (std.mem.eql(u8, trimmed, "|")) {
                // Awal atau akhir blok style, abaikan
            } else {
                // Tambahkan baris ke action_content
                try current_action_content.appendSlice(trimmed);
                try current_action_content.append('\n');
            }
        }
    }
    
    // Simpan aturan terakhir jika ada
    try saveCurrentRule(
        &current_rule_name, 
        &current_rule_description, 
        &current_url_patterns, 
        &current_action_type, 
        &current_action_content,
        &current_on_load
    );
}

// Helper untuk menyimpan aturan saat ini
fn saveCurrentRule(
    name: *?[]const u8,
    description: *?[]const u8,
    url_patterns: *std.ArrayList([]const u8),
    action_type: *?rules.BrowserRule.action_type,
    action_content: *std.ArrayList(u8),
    on_load: *bool,
) !void {
    if (name.* != null and action_type.* != null) {
        // Buat aturan baru
        const new_rule = rules.BrowserRule{
            .name = name.*.?,
            .description = description.*.? orelse "No description",
            .url_patterns = url_patterns.toOwnedSlice(),
            .action_type = action_type.*.?,
            .action_content = try action_content.toOwnedSlice(),
            .is_active = true,
            .on_load = on_load.*,
        };
        
        // Tambahkan aturan
        try rules.addRule(new_rule);
        
        // Reset variabel
        name.* = null;
        if (description.*.?) |desc| {
            allocator.free(desc);
        }
        description.* = null;
        url_patterns.* = std.ArrayList([]const u8).init(allocator);
        action_type.* = null;
        action_content.* = std.ArrayList(u8).init(allocator);
        on_load.* = true;
    }
}

// Mengekspor aturan ke file Markdown
pub fn exportToMarkdown(file_path: []const u8) !void {
    if (!is_initialized) return error.RulesIONotInitialized;
    
    // Dapatkan semua aturan
    const all_rules = rules.getAllRules();
    
    // Buat file
    const file = try fs.cwd().createFile(file_path, .{});
    defer file.close();
    
    const writer = file.writer();
    
    // Iterasi setiap aturan
    for (all_rules) |rule| {
        // Tulis nama dan deskripsi
        try writer.print("\nname: \"{s}\"\n", .{rule.name});
        try writer.print("description: \"{s}\"\n\n", .{rule.description});
        
        // Tulis bagian match
        try writer.writeAll("match:\n");
        try writer.writeAll("  url_patterns:\n");
        
        // Tulis URL patterns
        for (rule.url_patterns) |pattern| {
            try writer.print("    - \"{s}\"\n", .{pattern});
        }
        
        // Tulis bagian actions
        try writer.writeAll("\nactions:\n");
        
        // Tulis action type
        const action_type_str = switch (rule.action_type) {
            .inject_css => "inject_css",
            .block_request => "block_request",
            .redirect => "redirect",
        };
        try writer.print("  - type: \"{s}\"\n", .{action_type_str});
        try writer.print("    on_load: {}\n", .{rule.on_load});
        
        // Tulis action content
        if (rule.action_type == .inject_css) {
            try writer.writeAll("    style: |\n");
            try writer.print("      {s}\n", .{rule.action_content});
        } else {
            try writer.print("    content: \"{s}\"\n", .{rule.action_content});
        }
        
        try writer.writeAll("\n");
    }
}

// Membersihkan sumber daya
pub fn deinit() void {
    is_initialized = false;
}

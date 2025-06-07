const std = @import("std");

// Main build script for IcoBrowser
pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "icobrowser",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Windows-specific: add WebView2 dependencies
    if (target.result.os.tag == .windows) {
        // Add Windows libraries
        exe.linkLibC();
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("kernel32");
        exe.linkSystemLibrary("gdi32");
        
        // Add WebView2 SDK
        exe.linkSystemLibrary("WebView2Loader");
        
        // Add library search paths from vendor directory
        // Menggunakan WebView2 SDK yang disimpan di direktori vendor lokal
        exe.addLibraryPath(b.path("vendor/WebView2-SDK/build/native/x64"));
        
        // Windows-specific macros (UNICODE and _UNICODE are typically defined by the Windows SDK)
        // Removed explicit definitions to avoid build issues
    }

    // Install the executable
    b.installArtifact(exe);

    // Create a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create "run" step
    const run_step = b.step("run", "Run IcoBrowser");
    run_step.dependOn(&run_cmd.step);

    // Add tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Create "test" step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

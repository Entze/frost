const std = @import("std");

/// Generates a target-specific artifact name in the format: {base}-{os}-{arch}[-{abi}][.ext]
///
/// Parameters:
/// - allocator: Allocator for string formatting (borrowed)
/// - base_name: Base name of the artifact without extension (borrowed)
/// - target: Resolved build target containing OS, CPU architecture, and ABI info (borrowed)
/// - extension: Optional file extension (e.g., "exe" for Windows), can be null (borrowed)
///
/// Returns:
/// - Formatted string with target-specific name (caller owns memory)
///
/// Preconditions:
/// - base_name must be non-empty
/// - target must be valid and resolved
///
/// Ownership:
/// - Caller owns returned string and must free it
fn formatTargetName(
    allocator: std.mem.Allocator,
    base_name: []const u8,
    target: std.Build.ResolvedTarget,
    extension: ?[]const u8,
) ![]const u8 {
    std.debug.assert(base_name.len > 0);

    const os_tag = @tagName(target.result.os.tag);
    const arch_tag = @tagName(target.result.cpu.arch);
    const abi_tag = @tagName(target.result.abi);

    // Include ABI in name only if it's not "none"
    const name_with_target = if (!std.mem.eql(u8, abi_tag, "none"))
        try std.fmt.allocPrint(allocator, "{s}-{s}-{s}-{s}", .{ base_name, os_tag, arch_tag, abi_tag })
    else
        try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ base_name, os_tag, arch_tag });

    // Add extension if provided
    if (extension) |ext| {
        defer allocator.free(name_with_target);
        return std.fmt.allocPrint(allocator, "{s}.{s}", .{ name_with_target, ext });
    }

    // No extension, return name_with_target directly
    return name_with_target;
}

/// Creates an executable artifact with target-specific naming.
///
/// Parameters:
/// - b: Build context pointer (borrowed)
/// - mod: Frost module to import (borrowed)
/// - target: Compilation target
/// - optimize: Optimization mode
///
/// Returns:
/// - Configured executable artifact
///
/// Preconditions:
/// - mod must be initialized with valid root source file
/// - target must be valid compilation target
///
/// Ownership:
/// - Returned artifact is owned by the build graph
fn createExecutable(
    b: *std.Build,
    mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const exe_name = formatTargetName(
        b.allocator,
        "frost",
        target,
        null,
    ) catch @panic("OOM");

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "frost", .module = mod },
            },
        }),
    });

    return exe;
}

/// Creates a static library artifact with target-specific naming.
///
/// Parameters:
/// - b: Build context pointer (borrowed)
/// - target: Compilation target
/// - optimize: Optimization mode
///
/// Returns:
/// - Configured static library artifact
///
/// Preconditions:
/// - target must be valid compilation target
///
/// Ownership:
/// - Returned artifact is owned by the build graph
fn createStaticLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib_name = formatTargetName(
        b.allocator,
        "frost",
        target,
        null,
    ) catch @panic("OOM");

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = lib_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    return lib;
}

/// Creates a dynamic/shared library artifact with target-specific naming.
///
/// Parameters:
/// - b: Build context pointer (borrowed)
/// - target: Compilation target
/// - optimize: Optimization mode
///
/// Returns:
/// - Configured shared library artifact
///
/// Preconditions:
/// - target must be valid compilation target
///
/// Ownership:
/// - Returned artifact is owned by the build graph
fn createSharedLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lib_name = formatTargetName(
        b.allocator,
        "frost",
        target,
        null,
    ) catch @panic("OOM");

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = lib_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    return lib;
}

/// Defines supported target triples for release builds.
///
/// Returns:
/// - Array of target query strings for cross-compilation
///
/// Preconditions:
/// - None
///
/// Postconditions:
/// - Returns valid target triple strings compatible with Zig's target system
fn getSupportedTargets() []const []const u8 {
    return &[_][]const u8{
        // Linux targets
        "x86_64-linux-musl",
        "x86_64-linux-gnu",
        "aarch64-linux-musl",
        "aarch64-linux-gnu",
        // macOS targets
        "x86_64-macos",
        "aarch64-macos",
        // Windows targets
        "x86_64-windows-gnu",
        "aarch64-windows-gnu",
    };
}

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the frost module
    const mod = b.addModule("frost", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // Step 1: exe - Build executable (default step)
    const exe = createExecutable(b, mod, target, optimize);
    b.installArtifact(exe);

    // Create exe step (explicitly callable)
    const exe_step = b.step("exe", "Build the executable");
    const install_exe = b.addInstallArtifact(exe, .{});
    exe_step.dependOn(&install_exe.step);

    // Step 2: lib-static - Build static library
    const lib_static = createStaticLibrary(b, target, optimize);
    const lib_static_step = b.step("lib-static", "Build static library");
    const install_lib_static = b.addInstallArtifact(lib_static, .{});
    lib_static_step.dependOn(&install_lib_static.step);

    // Step 3: lib-dynamic - Build dynamic/shared library
    const lib_dynamic = createSharedLibrary(b, target, optimize);
    const lib_dynamic_step = b.step("lib-dynamic", "Build dynamic/shared library");
    const install_lib_dynamic = b.addInstallArtifact(lib_dynamic, .{});
    lib_dynamic_step.dependOn(&install_lib_dynamic.step);

    // Step 4: docs - Documentation generation (not yet implemented)
    const docs_step = b.step("docs", "Generate documentation");
    const docs_fail = b.addFail("Documentation generation not yet implemented");
    docs_step.dependOn(&docs_fail.step);

    // Step 5: test - Run all tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Step 6: release - Build for all supported targets
    const release_profile = b.option(
        std.builtin.OptimizeMode,
        "release-profile",
        "Optimization profile for release builds (default: ReleaseFast)",
    ) orelse .ReleaseFast;

    const release_step = b.step("release", "Build for all supported target platforms");

    const supported_targets = getSupportedTargets();
    for (supported_targets) |target_query_str| {
        const query = std.Target.Query.parse(.{ .arch_os_abi = target_query_str }) catch |err| {
            std.debug.print("Failed to parse target '{s}': {}\n", .{ target_query_str, err });
            continue;
        };

        const release_target = b.resolveTargetQuery(query);

        // Build executable for this target
        const release_exe = createExecutable(b, mod, release_target, release_profile);
        const install_release_exe = b.addInstallArtifact(release_exe, .{});
        release_step.dependOn(&install_release_exe.step);

        // Build static library for this target
        const release_lib_static = createStaticLibrary(b, release_target, release_profile);
        const install_release_lib_static = b.addInstallArtifact(release_lib_static, .{});
        release_step.dependOn(&install_release_lib_static.step);

        // Build dynamic library for this target
        const release_lib_dynamic = createSharedLibrary(b, release_target, release_profile);
        const install_release_lib_dynamic = b.addInstallArtifact(release_lib_dynamic, .{});
        release_step.dependOn(&install_release_lib_dynamic.step);
    }

    // Existing run step
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

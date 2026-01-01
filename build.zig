const std = @import("std");

/// Represents a build target with OS, CPU architecture, and ABI information.
const BuildTarget = struct {
    os: std.Target.Os.Tag,
    arch: std.Target.Cpu.Arch,
    abi: std.Target.Abi,

    /// Converts the build target to a target query string.
    ///
    /// Returns:
    /// - Target query string in format "{arch}-{os}[-{abi}]"
    ///
    /// Preconditions:
    /// - os, arch, and abi must be valid enum values
    ///
    /// Postconditions:
    /// - Returns valid target triple string compatible with Zig's target system
    fn toQueryString(self: BuildTarget, allocator: std.mem.Allocator) ![]const u8 {
        const os_str = @tagName(self.os);
        const arch_str = @tagName(self.arch);
        const abi_str = @tagName(self.abi);

        if (self.abi == .none) {
            return std.fmt.allocPrint(allocator, "{s}-{s}", .{ arch_str, os_str });
        } else {
            return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ arch_str, os_str, abi_str });
        }
    }
};

/// File extension for artifacts across different target platforms.
const ArtifactExtension = union(enum) {
    none,
    exe,
    lib,
    dll,
    dylib,
    a,
    so,

    /// Returns the string representation of the extension (without the dot).
    fn toString(self: ArtifactExtension) ?[]const u8 {
        return switch (self) {
            .none => null,
            .exe => "exe",
            .lib => "lib",
            .dll => "dll",
            .dylib => "dylib",
            .a => "a",
            .so => "so",
        };
    }
};

/// Generates a target-specific artifact name in the format: {base}-{os}-{arch}[-{abi}][.ext]
///
/// Parameters:
/// - allocator: Allocator for string formatting (borrowed)
/// - base_name: Base name of the artifact without extension (borrowed)
/// - target: Resolved build target containing OS, CPU architecture, and ABI info (borrowed)
/// - extension: Optional file extension (borrowed)
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
    extension: ArtifactExtension,
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
    if (extension.toString()) |ext| {
        defer allocator.free(name_with_target);
        return std.fmt.allocPrint(allocator, "{s}.{s}", .{ name_with_target, ext });
    }

    // No extension, return name_with_target directly
    return name_with_target;
}

test "formatTargetName: basic target without ABI" {
    const allocator = std.testing.allocator;

    // Create a mock target
    const target = std.Build.ResolvedTarget{
        .query = .{},
        .result = .{
            .cpu = .{
                .arch = .x86_64,
                .model = &std.Target.x86.cpu.baseline,
                .features = std.Target.x86.featureSet(&.{}),
            },
            .os = .{
                .tag = .linux,
                .version_range = .{ .none = {} },
            },
            .abi = .none,
            .ofmt = .elf,
            .dynamic_linker = std.Target.DynamicLinker.none,
        },
    };

    const result = try formatTargetName(allocator, "frost", target, .none);
    defer allocator.free(result);

    const expected = "frost-linux-x86_64";
    try std.testing.expectEqualStrings(expected, result);
}

test "formatTargetName: target with ABI" {
    const allocator = std.testing.allocator;

    const target = std.Build.ResolvedTarget{
        .query = .{},
        .result = .{
            .cpu = .{
                .arch = .aarch64,
                .model = &std.Target.aarch64.cpu.generic,
                .features = std.Target.aarch64.featureSet(&.{}),
            },
            .os = .{
                .tag = .linux,
                .version_range = .{ .none = {} },
            },
            .abi = .musl,
            .ofmt = .elf,
            .dynamic_linker = std.Target.DynamicLinker.none,
        },
    };

    const result = try formatTargetName(allocator, "frost", target, .none);
    defer allocator.free(result);

    const expected = "frost-linux-aarch64-musl";
    try std.testing.expectEqualStrings(expected, result);
}

test "formatTargetName: with extension" {
    const allocator = std.testing.allocator;

    const target = std.Build.ResolvedTarget{
        .query = .{},
        .result = .{
            .cpu = .{
                .arch = .x86_64,
                .model = &std.Target.x86.cpu.baseline,
                .features = std.Target.x86.featureSet(&.{}),
            },
            .os = .{
                .tag = .windows,
                .version_range = .{ .none = {} },
            },
            .abi = .gnu,
            .ofmt = .coff,
            .dynamic_linker = std.Target.DynamicLinker.none,
        },
    };

    const result = try formatTargetName(allocator, "frost", target, .exe);
    defer allocator.free(result);

    const expected = "frost-windows-x86_64-gnu.exe";
    try std.testing.expectEqualStrings(expected, result);
}

test "formatTargetName: with std.testing.FailingAllocator should return error" {
    var failing_allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const allocator = failing_allocator.allocator();

    const target = std.Build.ResolvedTarget{
        .query = .{},
        .result = .{
            .cpu = .{
                .arch = .x86_64,
                .model = &std.Target.x86.cpu.baseline,
                .features = std.Target.x86.featureSet(&.{}),
            },
            .os = .{
                .tag = .linux,
                .version_range = .{ .none = {} },
            },
            .abi = .none,
            .ofmt = .elf,
            .dynamic_linker = std.Target.DynamicLinker.none,
        },
    };

    const result = formatTargetName(allocator, "frost", target, .none);
    try std.testing.expectError(error.OutOfMemory, result);
}

test "formatTargetName: with FailingAllocator on second allocation should return error" {
    var failing_allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const allocator = failing_allocator.allocator();

    const target = std.Build.ResolvedTarget{
        .query = .{},
        .result = .{
            .cpu = .{
                .arch = .x86_64,
                .model = &std.Target.x86.cpu.baseline,
                .features = std.Target.x86.featureSet(&.{}),
            },
            .os = .{
                .tag = .windows,
                .version_range = .{ .none = {} },
            },
            .abi = .gnu,
            .ofmt = .coff,
            .dynamic_linker = std.Target.DynamicLinker.none,
        },
    };

    const result = formatTargetName(allocator, "frost", target, .exe);
    try std.testing.expectError(error.OutOfMemory, result);
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
        .none,
    ) catch @panic("Failed to allocate memory for executable name");

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
        .none,
    ) catch @panic("Failed to allocate memory for static library name");

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
        .none,
    ) catch @panic("Failed to allocate memory for shared library name");

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

/// Supported target triples for release builds.
const SUPPORTED_TARGETS = [_]BuildTarget{
    // Linux targets
    .{ .os = .linux, .arch = .x86_64, .abi = .musl },
    .{ .os = .linux, .arch = .x86_64, .abi = .gnu },
    .{ .os = .linux, .arch = .aarch64, .abi = .musl },
    .{ .os = .linux, .arch = .aarch64, .abi = .gnu },
    // macOS targets
    .{ .os = .macos, .arch = .x86_64, .abi = .none },
    .{ .os = .macos, .arch = .aarch64, .abi = .none },
    // Windows targets
    .{ .os = .windows, .arch = .x86_64, .abi = .gnu },
    .{ .os = .windows, .arch = .aarch64, .abi = .gnu },
};

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

    // Step 4: docs - Documentation generation
    const docs_step = b.step("docs", "Generate documentation");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib_static.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

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

    for (SUPPORTED_TARGETS) |build_target| {
        const query_str = build_target.toQueryString(b.allocator) catch @panic("Failed to allocate memory for target query string");
        defer b.allocator.free(query_str);

        const query = std.Target.Query.parse(.{ .arch_os_abi = query_str }) catch |err| {
            std.debug.panic("Invalid hardcoded target '{s}': {}\n", .{ query_str, err });
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

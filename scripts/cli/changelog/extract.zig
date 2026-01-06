//! CLI tool for extracting changelog version sections.
//!
//! This command-line interface wraps the changelog extraction functionality,
//! supporting the same interface as the bash-based mise task.

const std = @import("std");
const changelog = @import("changelog");

/// Prints usage information to stderr.
fn printUsage(program_name: []const u8) void {
    std.debug.print(
        \\Usage: {s} <changelog-path> [version]
        \\
        \\Extract a version section from a changelog file.
        \\
        \\Arguments:
        \\  <changelog-path>  Path to the changelog file (e.g., CHANGELOG.md)
        \\  [version]         Optional version to extract (defaults to environment variables)
        \\
        \\Environment Variables:
        \\  VERSION          Explicit version to extract (takes priority)
        \\  GITHUB_REF       GitHub ref in format refs/tags/v<version> (fallback)
        \\
        \\Examples:
        \\  {s} CHANGELOG.md 0.2.0
        \\  VERSION=0.2.0 {s} CHANGELOG.md
        \\  GITHUB_REF=refs/tags/v0.2.0 {s} CHANGELOG.md
        \\
    , .{ program_name, program_name, program_name, program_name });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command-line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const program_name = args.next() orelse "changelog-extract";

    const changelog_path = args.next() orelse {
        std.debug.print("Error: Missing required argument <changelog-path>\n\n", .{});
        printUsage(program_name);
        std.process.exit(1);
    };

    const version = args.next(); // Optional version argument

    // Extract version section
    const content = changelog.extractVersionSection(
        allocator,
        changelog_path,
        version,
    ) catch |err| {
        const err_msg = switch (err) {
            error.FileNotFound => "Changelog file not found",
            error.VersionNotSpecified => "Version not specified via argument or environment variables (VERSION or GITHUB_REF)",
            error.ParseFailed => "Failed to parse changelog",
            error.ReadFailed => "Failed to read changelog file",
            else => "Unknown error occurred",
        };
        std.debug.print("Error: {s}\n", .{err_msg});
        std.process.exit(1);
    };
    defer allocator.free(content);

    // Output the extracted content to stdout
    const stdout_file = std.fs.File.stdout();
    try stdout_file.writeAll(content);
    try stdout_file.writeAll("\n");
}

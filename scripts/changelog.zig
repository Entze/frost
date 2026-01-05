//! Changelog manipulation and extraction utilities.
//!
//! This module provides functions for extracting version sections from changelog files.
//! All functions are designed to be:
//! - Cross-platform (Windows, Linux, macOS)
//! - Testable with Zig's built-in testing framework
//! - Composable and orthogonal
//!
//! The API handles:
//! - Version section extraction from changelog files
//! - Version determination from multiple sources (explicit, VERSION env, GITHUB_REF env)

const std = @import("std");
const assert = std.debug.assert;

// C library for setenv/unsetenv in tests
const c = @cImport({
    @cInclude("stdlib.h");
});

/// Errors that can occur during changelog operations.
pub const ChangelogError = error{
    /// Changelog file does not exist
    FileNotFound,
    /// Failed to parse changelog structure
    ParseFailed,
    /// Version not specified (neither parameter nor env vars set)
    VersionNotSpecified,
    /// Failed to read file contents
    ReadFailed,
    /// Failed to write file contents
    WriteFailed,
    /// Invalid changelog format
    InvalidFormat,
    /// Failed to allocate memory
    OutOfMemory,
};

/// Determines version from explicit parameter or environment variables.
///
/// The version is determined by checking sources in this order:
/// 1. Explicit version parameter (if provided)
/// 2. VERSION environment variable (if set)
/// 3. GITHUB_REF environment variable (if set)
///
/// Caller must free returned string if explicit_version was null.
/// Returns ChangelogError.VersionNotSpecified if no version source found.
///
/// Preconditions:
/// - explicit_version (if provided) must be non-empty
///
/// Postconditions:
/// - Returns non-empty version string or error
fn determineVersion(
    allocator: std.mem.Allocator,
    explicit_version: ?[]const u8,
) ![]const u8 {
    // Use explicit version if provided
    if (explicit_version) |v| {
        assert(v.len > 0);
        return v;
    }

    // Try VERSION environment variable
    if (std.process.getEnvVarOwned(allocator, "VERSION")) |v| {
        if (v.len > 0) {
            defer assert(v.len > 0);
            return v;
        }
        allocator.free(v);
    } else |_| {}

    // Try GITHUB_REF environment variable
    if (std.process.getEnvVarOwned(allocator, "GITHUB_REF")) |github_ref| {
        defer allocator.free(github_ref);

        // Parse GITHUB_REF format: "refs/tags/v{version}"
        const prefix = "refs/tags/v";
        if (std.mem.startsWith(u8, github_ref, prefix)) {
            const version_part = github_ref[prefix.len..];
            if (version_part.len > 0) {
                const result = try allocator.dupe(u8, version_part);
                defer assert(result.len > 0);
                return result;
            }
        }
    } else |_| {}

    // No version found
    return ChangelogError.VersionNotSpecified;
}

/// Extracts version section content from changelog.
///
/// Parses changelog line-by-line to find the version header and extracts
/// content between that header and the next version header.
///
/// Caller must free returned string.
///
/// Preconditions:
/// - content must be non-empty
/// - version must be non-empty
///
/// Postconditions:
/// - Returns non-empty string (either extracted content or default message)
fn extractContentForVersion(
    allocator: std.mem.Allocator,
    content: []const u8,
    version: []const u8,
) ![]const u8 {
    assert(content.len > 0);
    assert(version.len > 0);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var found_version = false;
    var content_lines: std.ArrayList(u8) = .empty;
    defer content_lines.deinit(allocator);

    while (lines.next()) |line| {
        // Check if this is a version header (starts with "## ")
        if (std.mem.startsWith(u8, line, "## ")) {
            const header_content = line[3..]; // Skip "## "

            // Extract version from header (format: "version (date)" or just "version")
            const version_end = std.mem.indexOfAny(u8, header_content, " (") orelse header_content.len;
            const header_version = header_content[0..version_end];

            if (std.mem.eql(u8, header_version, version)) {
                found_version = true;
                continue;
            } else if (found_version) {
                // Found the next version header, stop collecting
                break;
            }
        } else if (found_version) {
            // Collect content lines for the target version
            if (content_lines.items.len > 0) {
                try content_lines.append(allocator, '\n');
            }
            try content_lines.appendSlice(allocator, line);
        }
    }

    // Trim trailing whitespace from collected content
    const trimmed_content = std.mem.trim(u8, content_lines.items, " \t\n\r");

    // If version not found or content is empty, return default message
    if (!found_version or trimmed_content.len == 0) {
        const result = try std.fmt.allocPrint(allocator, "Release v{s}", .{version});
        defer assert(result.len > 0);
        return result;
    }

    // Return the extracted content
    const result = try allocator.dupe(u8, trimmed_content);
    defer assert(result.len > 0);
    return result;
}

/// Extracts a specific version section from the changelog.
///
/// Finds and extracts the content for a specific version from the changelog.
/// The version is determined by:
/// 1. Explicit version parameter (if provided)
/// 2. VERSION environment variable (if set)
/// 3. GITHUB_REF environment variable (if set)
///
/// If the version section is empty or the version is not found in the changelog,
/// returns a default message "Release v{version}".
///
/// Caller must free returned string.
/// Asserts changelog_path and explicit_version (if provided) are non-empty.
/// Returns ChangelogError.VersionNotSpecified if version cannot be determined.
pub fn extractVersionSection(
    allocator: std.mem.Allocator,
    changelog_path: []const u8,
    explicit_version: ?[]const u8,
) ![]const u8 {
    assert(changelog_path.len > 0);
    if (explicit_version) |v| {
        assert(v.len > 0);
    }

    // Determine version from parameters or environment variables
    const version = try determineVersion(allocator, explicit_version);
    const should_free_version = explicit_version == null;
    defer if (should_free_version) allocator.free(version);

    // Read the changelog file
    const file = std.fs.cwd().openFile(changelog_path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => ChangelogError.FileNotFound,
            else => ChangelogError.ReadFailed,
        };
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch {
        return ChangelogError.ReadFailed;
    };
    defer allocator.free(content);

    // Handle empty file
    if (content.len == 0) {
        return ChangelogError.ParseFailed;
    }

    // Extract content for the determined version
    return extractContentForVersion(allocator, content, version);
}

test extractVersionSection {
    const allocator = std.testing.allocator;
    const content = try extractVersionSection(
        allocator,
        "CHANGELOG.md",
        "0.1.0",
    );
    defer allocator.free(content);
    // content contains the changelog section for version 0.1.0
    try std.testing.expect(content.len > 0);
}

test "extractVersionSection: typical changelog via explicit version" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/typical.md";
    const version = "0.2.0";

    const result = try extractVersionSection(allocator, changelog_path, version);
    defer allocator.free(result);

    // Should extract the content for version 0.2.0
    const expected =
        \\- Added new feature X
        \\- Improved performance of algorithm Y
        \\- Fixed bug in module Z
    ;

    try std.testing.expectEqualStrings(expected, result);
}

test "extractVersionSection: typical changelog via VERSION env var" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/typical.md";

    // Set VERSION environment variable
    _ = c.setenv("VERSION", "0.2.0", 1);
    defer _ = c.unsetenv("VERSION");

    const result = try extractVersionSection(allocator, changelog_path, null);
    defer allocator.free(result);

    // Should extract the content for version 0.2.0
    const expected =
        \\- Added new feature X
        \\- Improved performance of algorithm Y
        \\- Fixed bug in module Z
    ;

    try std.testing.expectEqualStrings(expected, result);
}

test "extractVersionSection: typical changelog via GITHUB_REF env var" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/typical.md";

    // Set GITHUB_REF environment variable
    _ = c.setenv("GITHUB_REF", "refs/tags/v0.2.0", 1);
    defer _ = c.unsetenv("GITHUB_REF");

    const result = try extractVersionSection(allocator, changelog_path, null);
    defer allocator.free(result);

    // Should extract the content for version 0.2.0
    const expected =
        \\- Added new feature X
        \\- Improved performance of algorithm Y
        \\- Fixed bug in module Z
    ;

    try std.testing.expectEqualStrings(expected, result);
}

test "extractVersionSection: single entry via explicit version" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/single-entry.md";
    const version = "1.0.0";

    const result = try extractVersionSection(allocator, changelog_path, version);
    defer allocator.free(result);

    // Should extract the content for version 1.0.0
    const expected =
        \\- First stable release
        \\- Production ready
    ;

    try std.testing.expectEqualStrings(expected, result);
}

test "extractVersionSection: single entry via VERSION env var" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/single-entry.md";

    // Set VERSION environment variable
    _ = c.setenv("VERSION", "1.0.0", 1);
    defer _ = c.unsetenv("VERSION");

    const result = try extractVersionSection(allocator, changelog_path, null);
    defer allocator.free(result);

    // Should extract the content for version 1.0.0
    const expected =
        \\- First stable release
        \\- Production ready
    ;

    try std.testing.expectEqualStrings(expected, result);
}

test "extractVersionSection: single entry via GITHUB_REF env var" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/single-entry.md";

    // Set GITHUB_REF environment variable
    _ = c.setenv("GITHUB_REF", "refs/tags/v1.0.0", 1);
    defer _ = c.unsetenv("GITHUB_REF");

    const result = try extractVersionSection(allocator, changelog_path, null);
    defer allocator.free(result);

    // Should extract the content for version 1.0.0
    const expected =
        \\- First stable release
        \\- Production ready
    ;

    try std.testing.expectEqualStrings(expected, result);
}

test "extractVersionSection: empty content returns default message via explicit version" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/empty-content.md";
    const version = "0.3.0";

    const result = try extractVersionSection(allocator, changelog_path, version);
    defer allocator.free(result);

    // Should return default message when content is empty
    try std.testing.expectEqualStrings("Release v0.3.0", result);
}

test "extractVersionSection: empty content returns default message via VERSION env var" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/empty-content.md";

    // Set VERSION environment variable
    _ = c.setenv("VERSION", "0.3.0", 1);
    defer _ = c.unsetenv("VERSION");

    const result = try extractVersionSection(allocator, changelog_path, null);
    defer allocator.free(result);

    // Should return default message when content is empty
    try std.testing.expectEqualStrings("Release v0.3.0", result);
}

test "extractVersionSection: empty content returns default message via GITHUB_REF env var" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/empty-content.md";

    // Set GITHUB_REF environment variable
    _ = c.setenv("GITHUB_REF", "refs/tags/v0.3.0", 1);
    defer _ = c.unsetenv("GITHUB_REF");

    const result = try extractVersionSection(allocator, changelog_path, null);
    defer allocator.free(result);

    // Should return default message when content is empty
    try std.testing.expectEqualStrings("Release v0.3.0", result);
}

test "extractVersionSection: empty file returns error" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/empty.md";
    const version = "0.1.0";

    const result = extractVersionSection(allocator, changelog_path, version);

    // Should return an error for empty file
    try std.testing.expectError(ChangelogError.ParseFailed, result);
}

test "extractVersionSection: version not specified returns VersionNotSpecified error" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/typical.md";

    // Clear environment variables to ensure they're not set
    _ = c.unsetenv("VERSION");
    _ = c.unsetenv("GITHUB_REF");

    const result = extractVersionSection(allocator, changelog_path, null);

    // Should return VersionNotSpecified error when no version is specified
    try std.testing.expectError(ChangelogError.VersionNotSpecified, result);
}

test "extractVersionSection: unknown version returns default message" {
    const allocator = std.testing.allocator;
    const changelog_path = "test/fixtures/changelog/typical.md";
    const version = "99.99.99";

    const result = try extractVersionSection(allocator, changelog_path, version);
    defer allocator.free(result);

    // Should return default message when version doesn't exist in changelog
    try std.testing.expectEqualStrings("Release v99.99.99", result);
}

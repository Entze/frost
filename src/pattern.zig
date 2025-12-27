//! Pattern matching module for building lexer-parser pipelines.
//!
//! This module provides a Pattern type as a tagged union with four basic variants:
//! - Wildcard: Matches any single character (regex `.`)
//! - Character: Matches a specific single character
//! - CharacterClass: Matches characters in a set (regex `[ ]`)
//! - Concatenation: Matches sequential patterns
//!
//! All patterns are defined at compile time, allowing variants to use arrays for storage.

const std = @import("std");
const assert = std.debug.assert;

/// Result of a pattern matching operation.
///
/// Contains the number of bytes consumed from the input and a slice of matched groups.
/// Group 0 represents the entire matched pattern.
pub const Match = struct {
    bytes_consumed: usize,
    groups: []const []const u8,

    const Self = @This();

    /// Creates a new Match result.
    ///
    /// Preconditions:
    /// - bytes_consumed >= 0 (enforced by type)
    ///
    /// Postconditions:
    /// - Returns Match with specified values
    ///
    /// Ownership:
    /// - Caller retains ownership of groups slice
    ///
    /// Lifetime:
    /// - groups slice must remain valid for lifetime of Match
    pub fn init(bytes_consumed: usize, groups: []const []const u8) Self {
        const result = Self{
            .bytes_consumed = bytes_consumed,
            .groups = groups,
        };

        // Postconditions
        defer assert(result.bytes_consumed == bytes_consumed);
        defer assert(result.groups.ptr == groups.ptr);
        defer assert(result.groups.len == groups.len);

        return result;
    }
};

test "Match: init with no groups" {
    const empty_groups: []const []const u8 = &[_][]const u8{};
    const match = Match.init(0, empty_groups);

    try std.testing.expectEqual(@as(usize, 0), match.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), match.groups.len);
}

test "Match: init with single group" {
    const input = "hello";
    const groups = &[_][]const u8{input};
    const match = Match.init(5, groups);

    try std.testing.expectEqual(@as(usize, 5), match.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), match.groups.len);
    try std.testing.expectEqualStrings("hello", match.groups[0]);
}

test "Match: init with multiple groups" {
    const group0 = "hello";
    const group1 = "world";
    const groups = &[_][]const u8{ group0, group1 };
    const match = Match.init(10, groups);

    try std.testing.expectEqual(@as(usize, 10), match.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), match.groups.len);
    try std.testing.expectEqualStrings("hello", match.groups[0]);
    try std.testing.expectEqualStrings("world", match.groups[1]);
}

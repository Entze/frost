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

/// Wildcard pattern that matches any single character (regex `.`).
pub const Wildcard = struct {
    const Self = @This();

    /// Matches any single character from the input.
    ///
    /// Preconditions:
    /// - input must be valid UTF-8 slice
    ///
    /// Postconditions:
    /// - If input is empty, returns Match with 0 bytes consumed and empty groups
    /// - If input is non-empty, returns Match with 1 byte consumed and groups[0] = first character
    ///
    /// Ownership:
    /// - input slice is borrowed, not owned
    /// - returned Match.groups references input memory
    ///
    /// Lifetime:
    /// - input must remain valid for lifetime of returned Match
    pub fn match(self: Self, input: []const u8) Match {
        _ = self;

        // Preconditions - input is already validated by type system

        if (input.len == 0) {
            // No input to match
            const empty_groups: []const []const u8 = &[_][]const u8{};
            const result = Match.init(0, empty_groups);

            // Postconditions
            defer assert(result.bytes_consumed == 0);
            defer assert(result.groups.len == 0);

            return result;
        }

        // Match first character
        const matched = input[0..1];
        const groups = &[_][]const u8{matched};
        const result = Match.init(1, groups);

        // Postconditions
        defer assert(result.bytes_consumed == 1);
        defer assert(result.groups.len == 1);
        defer assert(result.groups[0].len == 1);

        return result;
    }
};

test "Wildcard: match empty input" {
    const wildcard = Wildcard{};
    const input = "";
    const result = wildcard.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Wildcard: match single character" {
    const wildcard = Wildcard{};
    const input = "a";
    const result = wildcard.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("a", result.groups[0]);
}

test "Wildcard: match first character of multiple" {
    const wildcard = Wildcard{};
    const input = "hello";
    const result = wildcard.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("h", result.groups[0]);
}

test "Wildcard: match special characters" {
    const wildcard = Wildcard{};

    // Test newline
    const input1 = "\n";
    const result1 = wildcard.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("\n", result1.groups[0]);

    // Test tab
    const input2 = "\t";
    const result2 = wildcard.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("\t", result2.groups[0]);

    // Test space
    const input3 = " ";
    const result3 = wildcard.match(input3);
    try std.testing.expectEqual(@as(usize, 1), result3.bytes_consumed);
    try std.testing.expectEqualStrings(" ", result3.groups[0]);
}

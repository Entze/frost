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

// Re-export types from submodules
pub const MatchGroup = @import("pattern/match_group.zig").MatchGroup;
pub const Match = @import("pattern/match.zig").Match;
pub const Wildcard = @import("pattern/wildcard.zig").Wildcard;
pub const Character = @import("pattern/character.zig").Character;
pub const CharacterClass = @import("pattern/character_class.zig").CharacterClass;
pub const characterClass = @import("pattern/character_class.zig").characterClass;
pub const Concatenation = @import("pattern/concatenation.zig").Concatenation;
pub const concatenation = @import("pattern/concatenation.zig").concatenation;

/// Pattern tagged union containing all pattern variants.
///
/// This is the main abstraction for pattern matching. It delegates matching
/// behavior to its variants.
///
/// The size parameter determines:
/// - Maximum size of CharacterClass character sets
/// - Maximum number of patterns in Concatenation sequences
pub fn Pattern(comptime max_size: usize) type {
    return union(enum) {
        wildcard: Wildcard,
        character: Character,
        character_class: CharacterClass(max_size),
        concatenation: Concatenation(max_size),

        const Self = @This();

        /// Number of groups this pattern union produces (always 1 for basic patterns).
        pub const groups_count = 1;

        /// Matches the pattern against the input.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        ///
        /// Postconditions:
        /// - Returns Match result from the active variant
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match(groups_count) {
            return switch (self) {
                .wildcard => |w| w.match(input),
                .character => |c| c.match(input),
                .character_class => |cc| cc.match(input),
                .concatenation => |cat| cat.match(input),
            };
        }
    };
}

test "Pattern: groups_count constant" {
    const P = Pattern(10);
    // Verify that groups_count constant is accessible and correct
    try std.testing.expectEqual(@as(usize, 1), P.groups_count);
}

test Pattern {
    // Supports CharacterClass up to 10 chars, Concatenation up to 10 patterns
    const P = Pattern(10);
    const pattern = P{ .character_class = characterClass("0123456789") };

    const input = "5 apples";
    const result = pattern.match(input);
    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("5", input[result.groups[0].begin..result.groups[0].end]);
}

test "Pattern: wildcard variant" {
    const P = Pattern(10);
    const pattern = P{ .wildcard = Wildcard{} };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqualStrings("h", input[result.groups[0].begin..result.groups[0].end]);
}

test "Pattern: character variant matching" {
    const P = Pattern(10);
    const pattern = P{ .character = Character{ .character = 'h' } };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqualStrings("h", input[result.groups[0].begin..result.groups[0].end]);
}

test "Pattern: character variant not matching" {
    const P = Pattern(10);
    const pattern = P{ .character = Character{ .character = 'x' } };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
}

test "Pattern: character class variant" {
    const P = Pattern(10);
    const cc = CharacterClass(10).init("aei");
    const pattern = P{ .character_class = cc };

    const input1 = "apple";
    const result1 = pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "banana";
    const result2 = pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "Pattern: concatenation variant" {
    const P = Pattern(10);
    const p1 = P{ .character = Character{ .character = 'h' } };
    const p2 = P{ .character = Character{ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const pattern = P{ .concatenation = concat };
    const input = "hi there";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqualStrings("hi", input[result.groups[0].begin..result.groups[0].end]);
}

test "fuzz: Pattern union never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const P = Pattern(10);
            // Test wildcard variant
            const pattern1 = P{ .wildcard = Wildcard{} };
            const result1 = pattern1.match(input);
            try std.testing.expect(result1.bytes_consumed <= input.len);

            // Test character variant
            const pattern2 = P{ .character = Character{ .character = 'x' } };
            const result2 = pattern2.match(input);
            try std.testing.expect(result2.bytes_consumed <= input.len);

            // Test character class variant
            const cc = CharacterClass(10).init("abc");
            const pattern3 = P{ .character_class = cc };
            const result3 = pattern3.match(input);
            try std.testing.expect(result3.bytes_consumed <= input.len);

            // Test concatenation variant
            const p1 = P{ .character = Character{ .character = 'a' } };
            const p2 = P{ .character = Character{ .character = 'b' } };
            const patterns = [_]*const P{ &p1, &p2 };
            const concat = Concatenation(10).init(&patterns);
            const pattern4 = P{ .concatenation = concat };
            const result4 = pattern4.match(input);
            try std.testing.expect(result4.bytes_consumed <= input.len);
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

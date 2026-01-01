//! Pattern matching module for building lexer-parser pipelines.
//!
//! This module provides a Pattern type as a tagged union with seven variants:
//! - Wildcard: Matches any single character (regex `.`)
//! - Character: Matches a specific single character
//! - CharacterClass: Matches characters in a set (regex `[ ]`)
//! - InvertedCharacterClass: Matches characters not in a set (regex `[^ ]`)
//! - Concatenation: Matches sequential patterns
//! - Group: Matches a subpattern and counts as a capture group (regex `(PATTERN)`)
//! - NoneOrOnce: Matches a subpattern zero or one time (regex `PATTERN?`)
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
pub const InvertedCharacterClass = @import("pattern/inverted_character_class.zig").InvertedCharacterClass;
pub const invertedCharacterClass = @import("pattern/inverted_character_class.zig").invertedCharacterClass;
pub const Concatenation = @import("pattern/concatenation.zig").Concatenation;
pub const concatenation = @import("pattern/concatenation.zig").concatenation;
pub const Group = @import("pattern/group.zig").Group;
pub const NoneOrOnce = @import("pattern/none_or_once.zig").NoneOrOnce;

/// Pattern tagged union containing all pattern variants.
///
/// This is the main abstraction for pattern matching. It delegates matching
/// behavior to its variants.
///
/// The size parameter determines:
/// - Maximum size of CharacterClass character sets
/// - Maximum size of InvertedCharacterClass exclusion sets
/// - Maximum number of patterns in Concatenation sequences
pub fn Pattern(comptime max_size: usize) type {
    return union(enum) {
        wildcard: Wildcard(max_size),
        character: Character(max_size),
        character_class: CharacterClass(max_size),
        inverted_character_class: InvertedCharacterClass(max_size),
        concatenation: Concatenation(max_size),
        group: Group(max_size),
        none_or_once: NoneOrOnce(max_size),

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
        pub fn match(self: Self, input: []const u8) Match(max_size) {
            return switch (self) {
                .wildcard => |w| w.match(input),
                .character => |c| c.match(input),
                .character_class => |cc| cc.match(input),
                .inverted_character_class => |icc| icc.match(input),
                .concatenation => |cat| cat.match(input),
                .group => |g| g.match(input),
                .none_or_once => |noo| noo.match(input),
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
    const pattern = P{ .wildcard = Wildcard(10){} };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqualStrings("h", input[result.groups[0].begin..result.groups[0].end]);
}

test "Pattern: character variant matching" {
    const P = Pattern(10);
    const pattern = P{ .character = Character(10){ .character = 'h' } };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqualStrings("h", input[result.groups[0].begin..result.groups[0].end]);
}

test "Pattern: character variant not matching" {
    const P = Pattern(10);
    const pattern = P{ .character = Character(10){ .character = 'x' } };
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
    const p1 = P{ .character = Character(10){ .character = 'h' } };
    const p2 = P{ .character = Character(10){ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const pattern = P{ .concatenation = concat };
    const input = "hi there";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqualStrings("hi", input[result.groups[0].begin..result.groups[0].end]);
}

test "Pattern: inverted character class variant matching" {
    const P = Pattern(10);
    const icc = InvertedCharacterClass(10).init("aeiou");
    const pattern = P{ .inverted_character_class = icc };

    const input1 = "banana";
    const result1 = pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("b", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "apple";
    const result2 = pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "Pattern: inverted character class variant with helper" {
    const P = Pattern(10);
    const pattern = P{ .inverted_character_class = invertedCharacterClass("0123456789") };

    const input1 = "abc";
    const result1 = pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "123";
    const result2 = pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "Pattern: group variant wrapping character" {
    const P = Pattern(10);
    const char = P{ .character = Character(10){ .character = 'a' } };
    const pattern = P{ .group = Group(10){ .pattern = &char } };

    const input1 = "abc";
    const result1 = pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result1.groups_matched);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);
    try std.testing.expectEqualStrings("a", input1[result1.groups[1].begin..result1.groups[1].end]);

    const input2 = "bcd";
    const result2 = pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "Pattern: group variant wrapping concatenation" {
    const P = Pattern(10);
    const p1 = P{ .character = Character(10){ .character = 'h' } };
    const p2 = P{ .character = Character(10){ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const concat_pattern = P{ .concatenation = concat };
    const pattern = P{ .group = Group(10){ .pattern = &concat_pattern } };

    const input = "hi there";
    const result = pattern.match(input);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.groups_matched);
    try std.testing.expectEqualStrings("hi", input[result.groups[0].begin..result.groups[0].end]);
    try std.testing.expectEqualStrings("hi", input[result.groups[1].begin..result.groups[1].end]);
}

test "Pattern: nested group variant" {
    const P = Pattern(10);
    const char = P{ .character = Character(10){ .character = 'x' } };
    const inner_group = P{ .group = Group(10){ .pattern = &char } };
    const outer_pattern = P{ .group = Group(10){ .pattern = &inner_group } };

    const input1 = "xyz";
    const result1 = outer_pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result1.groups_matched);
    try std.testing.expectEqualStrings("x", input1[result1.groups[0].begin..result1.groups[0].end]);
    try std.testing.expectEqualStrings("x", input1[result1.groups[1].begin..result1.groups[1].end]);
    try std.testing.expectEqualStrings("x", input1[result1.groups[2].begin..result1.groups[2].end]);

    const input2 = "abc";
    const result2 = outer_pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "Pattern: none_or_once variant with matching character" {
    const P = Pattern(10);
    const char = P{ .character = Character(10){ .character = 'a' } };
    const pattern = P{ .none_or_once = NoneOrOnce(10){ .pattern = &char } };

    const input1 = "abc";
    const result1 = pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result1.groups_matched);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "bcd";
    const result2 = pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result2.groups_matched);
}

test "Pattern: none_or_once variant with group" {
    const P = Pattern(10);
    const char = P{ .character = Character(10){ .character = 'x' } };
    const group = P{ .group = Group(10){ .pattern = &char } };
    const pattern = P{ .none_or_once = NoneOrOnce(10){ .pattern = &group } };

    const input1 = "xyz";
    const result1 = pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result1.groups_matched);
    try std.testing.expectEqualStrings("x", input1[result1.groups[0].begin..result1.groups[0].end]);
    try std.testing.expectEqualStrings("x", input1[result1.groups[1].begin..result1.groups[1].end]);

    const input2 = "abc";
    const result2 = pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result2.groups_matched);
}

test "Pattern: nested none_or_once variant" {
    const P = Pattern(10);
    const char = P{ .character = Character(10){ .character = 'a' } };
    const inner = P{ .none_or_once = NoneOrOnce(10){ .pattern = &char } };
    const pattern = P{ .none_or_once = NoneOrOnce(10){ .pattern = &inner } };

    const input1 = "abc";
    const result1 = pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result1.groups_matched);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "xyz";
    const result2 = pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result2.groups_matched);
}

test "Pattern: ((abc)xyz) example - nested group in concatenation" {
    // Pattern: ((abc)xyz)
    // Group 0: ((abc)xyz) - the whole match
    // Group 1: (abc)xyz - outer group
    // Group 2: abc - inner group
    const P = Pattern(10);

    // Build "abc" pattern
    const pa = P{ .character = Character(10){ .character = 'a' } };
    const pb = P{ .character = Character(10){ .character = 'b' } };
    const pc = P{ .character = Character(10){ .character = 'c' } };
    const abc_patterns = [_]*const P{ &pa, &pb, &pc };
    const abc_concat = P{ .concatenation = Concatenation(10).init(&abc_patterns) };

    // Wrap "abc" in a group: (abc)
    const inner_group = P{ .group = Group(10){ .pattern = &abc_concat } };

    // Build "xyz" pattern
    const px = P{ .character = Character(10){ .character = 'x' } };
    const py = P{ .character = Character(10){ .character = 'y' } };
    const pz = P{ .character = Character(10){ .character = 'z' } };
    const xyz_patterns = [_]*const P{ &px, &py, &pz };
    const xyz_concat = P{ .concatenation = Concatenation(10).init(&xyz_patterns) };

    // Concatenate (abc) with xyz: (abc)xyz
    const concat_patterns = [_]*const P{ &inner_group, &xyz_concat };
    const full_concat = P{ .concatenation = Concatenation(10).init(&concat_patterns) };

    // Wrap in outer group: ((abc)xyz)
    const outer_pattern = P{ .group = Group(10){ .pattern = &full_concat } };

    const input = "abcxyz";
    const result = outer_pattern.match(input);

    try std.testing.expectEqual(@as(usize, 6), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.groups_matched);
    // Group 0: the whole match
    try std.testing.expectEqualStrings("abcxyz", input[result.groups[0].begin..result.groups[0].end]);
    // Group 1: outer group (abc)xyz
    try std.testing.expectEqualStrings("abcxyz", input[result.groups[1].begin..result.groups[1].end]);
    // Group 2: inner group abc
    try std.testing.expectEqualStrings("abc", input[result.groups[2].begin..result.groups[2].end]);
}

test "Pattern: (abc)((x)yz) example - multiple groups in concatenation" {
    // Pattern: (abc)((x)yz)
    // Group 0: (abc)((x)yz) - the whole match
    // Group 1: abc - first group
    // Group 2: (x)yz - second outer group
    // Group 3: x - second inner group
    const P = Pattern(10);

    // Build first group: (abc)
    const pa = P{ .character = Character(10){ .character = 'a' } };
    const pb = P{ .character = Character(10){ .character = 'b' } };
    const pc = P{ .character = Character(10){ .character = 'c' } };
    const abc_patterns = [_]*const P{ &pa, &pb, &pc };
    const abc_concat = P{ .concatenation = Concatenation(10).init(&abc_patterns) };
    const group1 = P{ .group = Group(10){ .pattern = &abc_concat } };

    // Build nested group: ((x)yz)
    // Inner: (x)
    const px = P{ .character = Character(10){ .character = 'x' } };
    const x_group = P{ .group = Group(10){ .pattern = &px } };

    // yz
    const py = P{ .character = Character(10){ .character = 'y' } };
    const pz = P{ .character = Character(10){ .character = 'z' } };
    const yz_patterns = [_]*const P{ &py, &pz };
    const yz_concat = P{ .concatenation = Concatenation(10).init(&yz_patterns) };

    // (x)yz
    const xyz_patterns = [_]*const P{ &x_group, &yz_concat };
    const xyz_concat = P{ .concatenation = Concatenation(10).init(&xyz_patterns) };

    // ((x)yz)
    const group2 = P{ .group = Group(10){ .pattern = &xyz_concat } };

    // Concatenate (abc) with ((x)yz)
    const full_patterns = [_]*const P{ &group1, &group2 };
    const full_pattern = P{ .concatenation = Concatenation(10).init(&full_patterns) };

    const input = "abcxyz";
    const result = full_pattern.match(input);

    try std.testing.expectEqual(@as(usize, 6), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 4), result.groups_matched);
    // Group 0: the whole match
    try std.testing.expectEqualStrings("abcxyz", input[result.groups[0].begin..result.groups[0].end]);
    // Group 1: first capture group (abc)
    try std.testing.expectEqualStrings("abc", input[result.groups[1].begin..result.groups[1].end]);
    // Group 2: second outer capture group (x)yz
    try std.testing.expectEqualStrings("xyz", input[result.groups[2].begin..result.groups[2].end]);
    // Group 3: second inner capture group x
    try std.testing.expectEqualStrings("x", input[result.groups[3].begin..result.groups[3].end]);
}

test "fuzz: Pattern union never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const P = Pattern(10);
            // Test wildcard variant
            const pattern1 = P{ .wildcard = Wildcard(10){} };
            const result1 = pattern1.match(input);
            try std.testing.expect(result1.bytes_consumed <= input.len);

            // Test character variant
            const pattern2 = P{ .character = Character(10){ .character = 'x' } };
            const result2 = pattern2.match(input);
            try std.testing.expect(result2.bytes_consumed <= input.len);

            // Test character class variant
            const cc = CharacterClass(10).init("abc");
            const pattern3 = P{ .character_class = cc };
            const result3 = pattern3.match(input);
            try std.testing.expect(result3.bytes_consumed <= input.len);

            // Test inverted character class variant
            const icc = InvertedCharacterClass(10).init("abc");
            const pattern4 = P{ .inverted_character_class = icc };
            const result4 = pattern4.match(input);
            try std.testing.expect(result4.bytes_consumed <= input.len);

            // Test concatenation variant
            const p1 = P{ .character = Character(10){ .character = 'a' } };
            const p2 = P{ .character = Character(10){ .character = 'b' } };
            const patterns = [_]*const P{ &p1, &p2 };
            const concat = Concatenation(10).init(&patterns);
            const pattern5 = P{ .concatenation = concat };
            const result5 = pattern5.match(input);
            try std.testing.expect(result5.bytes_consumed <= input.len);

            // Test group variant
            const char_pattern = P{ .character = Character(10){ .character = 'x' } };
            const pattern6 = P{ .group = Group(10){ .pattern = &char_pattern } };
            const result6 = pattern6.match(input);
            try std.testing.expect(result6.bytes_consumed <= input.len);

            // Test none_or_once variant
            const pattern7 = P{ .none_or_once = NoneOrOnce(10){ .pattern = &char_pattern } };
            const result7 = pattern7.match(input);
            try std.testing.expect(result7.bytes_consumed <= input.len);
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

//! Concatenation pattern that matches sequential patterns.

const std = @import("std");
const assert = std.debug.assert;
const MatchGroup = @import("match_group.zig").MatchGroup;
const Match = @import("match.zig").Match;

// Note: Pattern is imported from parent, creating a circular dependency
// This is intentional and necessary: Pattern contains Concatenation,
// and Concatenation contains pointers to Pattern
const Pattern = @import("../pattern.zig").Pattern;

/// Helper function to create Concatenation with inferred size.
/// The max_size is determined by the patterns slice length.
///
/// **Note**: This helper has limitations due to type inference.
/// It infers max_size from pattern count rather than from Pattern's max_size,
/// which can cause type mismatches. Consider using `Concatenation(max_size).init()` directly instead.
pub fn concatenation(comptime patterns: anytype) Concatenation(patterns.len) {
    return Concatenation(patterns.len).init(patterns);
}

test "concatenation: doctest - expected vs actual style" {
    // Expected: Match "hi" from "hi there"
    const expected_bytes: usize = 2;
    const expected_groups: usize = 1;
    const expected_match = "hi";

    // Actual: Create and use Concatenation.init (note: concatenation helper has limitations)
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'h' } };
    const p2 = P{ .character = Character(10){ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "hi there";
    const result = concat.match(input);
    const actual_match = input[result.groups[0].begin..result.groups[0].end];

    // Verify expectations
    try std.testing.expectEqual(expected_bytes, result.bytes_consumed);
    try std.testing.expectEqual(expected_groups, result.groups_matched);
    try std.testing.expectEqualStrings(expected_match, actual_match);
}

/// Concatenation pattern that matches sequential patterns.
///
/// Since patterns are defined at compile time, uses an array with a compile-time count.
/// The max_size parameter determines the maximum number of patterns that can be stored.
/// Uses pointers to Pattern to handle the circular dependency between Pattern and Concatenation.
pub fn Concatenation(comptime max_size: usize) type {
    return struct {
        patterns: [max_size]*const Pattern(max_size),
        count: usize,

        const Self = @This();

        /// Number of groups this pattern produces (always 1: the full match).
        pub const groups_count = 1;

        /// Creates a Concatenation from a pattern slice.
        /// The count is taken from the slice length.
        ///
        /// Preconditions:
        /// - patterns.len <= max_size
        /// - patterns.len > 0
        pub fn init(patterns: []const *const Pattern(max_size)) Self {
            assert(patterns.len <= max_size);
            assert(patterns.len > 0);
            var result: Self = undefined;
            result.count = patterns.len;
            // Initialize used pattern slots
            for (patterns, 0..) |pattern, i| {
                result.patterns[i] = pattern;
            }
            // Remaining slots don't need initialization since we use count
            return result;
        }

        test init {
            const P = Pattern(10);
            const Character = @import("character.zig").Character;
            const p1 = P{ .character = Character(10){ .character = 'a' } };
            const p2 = P{ .character = Character(10){ .character = 'b' } };
            const patterns = [_]*const P{ &p1, &p2 };
            const concat = Concatenation(10).init(&patterns);

            try std.testing.expectEqual(@as(usize, 2), concat.count);

            const input = "abc";
            const result = concat.match(input);
            try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
            try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
            try std.testing.expectEqualStrings("ab", input[result.groups[0].begin..result.groups[0].end]);
        }

        test "init: doctest - expected vs actual style" {
            // Expected: Create Concatenation matching "ab" in "abc"
            const expected_count: usize = 2;
            const expected_bytes: usize = 2;
            const expected_groups: usize = 1;
            const expected_match = "ab";

            // Actual: Create and use Concatenation.init
            const P = Pattern(10);
            const Character = @import("character.zig").Character;
            const p1 = P{ .character = Character(10){ .character = 'a' } };
            const p2 = P{ .character = Character(10){ .character = 'b' } };
            const patterns = [_]*const P{ &p1, &p2 };
            const concat = Concatenation(10).init(&patterns);
            const input = "abc";
            const result = concat.match(input);
            const actual_match = input[result.groups[0].begin..result.groups[0].end];

            // Verify expectations
            try std.testing.expectEqual(expected_count, concat.count);
            try std.testing.expectEqual(expected_bytes, result.bytes_consumed);
            try std.testing.expectEqual(expected_groups, result.groups_matched);
            try std.testing.expectEqualStrings(expected_match, actual_match);
        }

        /// Matches patterns in sequence.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        /// - count <= max_size
        /// - count > 0
        ///
        /// Postconditions:
        /// - If any pattern fails to match, returns Match with 0 bytes consumed
        /// - If all patterns match, returns Match with total bytes consumed and 1 group (the full match)
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match(max_size) {
            // Preconditions
            assert(self.count <= max_size);
            assert(self.count > 0);

            var total_consumed: usize = 0;
            var current_input = input;
            var total_groups: usize = 1; // Start with 1 for group 0 (full match)
            var all_groups = [_]MatchGroup{MatchGroup{ .begin = 0, .end = 0 }} ** max_size;

            // Loop has determinable upper bound: self.count (compile-time validated <= max_size)
            var i: usize = 0;
            while (i < self.count) : (i += 1) {
                // Loop invariant: i < self.count
                assert(i < self.count);

                const pattern_match = self.patterns[i].match(current_input);

                if (pattern_match.bytes_consumed == 0) {
                    // Pattern failed to match
                    const result = Match(max_size).empty;

                    // Postconditions
                    defer assert(result.bytes_consumed == 0);
                    defer assert(result.groups_matched == 0);

                    return result;
                }

                // Collect capture groups from this subpattern (skip group 0 which is the subpattern's full match)
                var j: usize = 1;
                while (j < pattern_match.groups_matched) : (j += 1) {
                    assert(j < pattern_match.groups_matched);
                    assert(total_groups < max_size);

                    // Adjust group positions relative to concatenation start
                    const group = pattern_match.groups[j];
                    all_groups[total_groups] = MatchGroup.init(group.begin + total_consumed, group.end + total_consumed);
                    total_groups += 1;
                }

                total_consumed += pattern_match.bytes_consumed;
                current_input = current_input[pattern_match.bytes_consumed..];
            }

            // All patterns matched successfully
            // Group 0 is the full concatenation match
            all_groups[0] = MatchGroup.init(0, total_consumed);
            const result = Match(max_size).init(total_consumed, total_groups, all_groups);

            // Postconditions
            defer assert(result.bytes_consumed == total_consumed);
            defer assert(result.groups_matched == total_groups);
            defer assert(result.groups[0].len() == total_consumed);

            return result;
        }
    };
}

test "Concatenation: match empty input" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'a' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Concatenation: match two characters" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'a' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("ab", input[result.groups[0].begin..result.groups[0].end]);
}

test "Concatenation: partial match fails" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'a' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const p3 = P{ .character = Character(10){ .character = 'c' } };
    const patterns = [_]*const P{ &p1, &p2, &p3 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abx";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Concatenation: mixed pattern types" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const Wildcard = @import("wildcard.zig").Wildcard;
    const CharacterClass = @import("character_class.zig").CharacterClass;
    const p1 = P{ .character = Character(10){ .character = 'h' } };
    const p2 = P{ .wildcard = Wildcard(10){} };
    const cc = CharacterClass(10).init("lmn");
    const p3 = P{ .character_class = cc };
    const patterns = [_]*const P{ &p1, &p2, &p3 };
    const concat = Concatenation(10).init(&patterns);
    const input = "hello";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("hel", input[result.groups[0].begin..result.groups[0].end]);
}

test "Concatenation: first pattern fails" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'x' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Concatenation: insufficient input" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'a' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const p3 = P{ .character = Character(10){ .character = 'c' } };
    const p4 = P{ .character = Character(10){ .character = 'd' } };
    const patterns = [_]*const P{ &p1, &p2, &p3, &p4 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "fuzz: Concatenation never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const P = Pattern(10);
            const Character = @import("character.zig").Character;
            const p1 = P{ .character = Character(10){ .character = 'a' } };
            const p2 = P{ .character = Character(10){ .character = 'b' } };
            const p3 = P{ .character = Character(10){ .character = 'c' } };
            const patterns = [_]*const P{ &p1, &p2, &p3 };
            const concat = Concatenation(10).init(&patterns);
            const result = concat.match(input);
            // Concatenation should never panic and should consume 0 or 3 bytes
            try std.testing.expect(result.bytes_consumed == 0 or result.bytes_consumed == 3);
            if (result.bytes_consumed == 0) {
                try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
            } else {
                try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
                try std.testing.expectEqual(@as(usize, 3), result.groups[0].len());
                try std.testing.expectEqualStrings("abc", input[result.groups[0].begin..result.groups[0].end]);
            }
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

test concatenation {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'h' } };
    const p2 = P{ .character = Character(10){ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);

    const input = "hi there";
    const result = concat.match(input);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("hi", input[result.groups[0].begin..result.groups[0].end]);
}

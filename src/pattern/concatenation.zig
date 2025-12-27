//! Concatenation pattern that matches sequential patterns.

const std = @import("std");
const assert = std.debug.assert;
const Group = @import("group.zig").Group;
const Match = @import("match.zig").Match;

// Note: Pattern is imported from parent, creating a circular dependency
// This is intentional and necessary: Pattern contains Concatenation,
// and Concatenation contains pointers to Pattern
const Pattern = @import("../pattern.zig").Pattern;

/// Helper function to create Concatenation with inferred size.
/// The max_size is determined by the patterns slice length.
pub fn concatenation(comptime patterns: anytype) Concatenation(patterns.len) {
    return Concatenation(patterns.len).init(patterns);
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
        pub const num_groups = 1;

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
            const p1 = P{ .character = Character{ .character = 'a' } };
            const p2 = P{ .character = Character{ .character = 'b' } };
            const patterns = [_]*const P{ &p1, &p2 };
            const concat = Concatenation(10).init(&patterns);

            try std.testing.expectEqual(@as(usize, 2), concat.count);

            const input = "abc";
            const result = concat.match(input);
            try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
            try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
            try std.testing.expectEqualStrings("ab", input[result.groups[0].begin..result.groups[0].end]);
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
        pub fn match(self: Self, input: []const u8) Match(num_groups) {
            // Preconditions
            assert(self.count <= max_size);
            assert(self.count > 0);

            var total_consumed: usize = 0;
            var current_input = input;

            // Loop has determinable upper bound: self.count (compile-time validated <= max_size)
            var i: usize = 0;
            while (i < self.count) : (i += 1) {
                // Loop invariant: i < self.count
                assert(i < self.count);

                const pattern_match = self.patterns[i].match(current_input);

                if (pattern_match.bytes_consumed == 0) {
                    // Pattern failed to match
                    const result = Match(num_groups).empty;

                    // Postconditions
                    defer assert(result.bytes_consumed == 0);
                    defer assert(result.groups_matched == 0);

                    return result;
                }

                total_consumed += pattern_match.bytes_consumed;
                current_input = current_input[pattern_match.bytes_consumed..];
            }

            // All patterns matched successfully
            const groups = [_]Group{Group.init(0, total_consumed)};
            const result = Match(num_groups).init(total_consumed, 1, groups);

            // Postconditions
            defer assert(result.bytes_consumed == total_consumed);
            defer assert(result.groups_matched == 1);
            defer assert(result.groups[0].len() == total_consumed);

            return result;
        }
    };
}

test "Concatenation: match empty input" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character{ .character = 'a' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
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
    const p1 = P{ .character = Character{ .character = 'a' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
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
    const p1 = P{ .character = Character{ .character = 'a' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
    const p3 = P{ .character = Character{ .character = 'c' } };
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
    const p1 = P{ .character = Character{ .character = 'h' } };
    const p2 = P{ .wildcard = Wildcard{} };
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
    const p1 = P{ .character = Character{ .character = 'x' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
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
    const p1 = P{ .character = Character{ .character = 'a' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
    const p3 = P{ .character = Character{ .character = 'c' } };
    const p4 = P{ .character = Character{ .character = 'd' } };
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
            const p1 = P{ .character = Character{ .character = 'a' } };
            const p2 = P{ .character = Character{ .character = 'b' } };
            const p3 = P{ .character = Character{ .character = 'c' } };
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
    const p1 = P{ .character = Character{ .character = 'h' } };
    const p2 = P{ .character = Character{ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);

    const input = "hi there";
    const result = concat.match(input);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("hi", input[result.groups[0].begin..result.groups[0].end]);
}

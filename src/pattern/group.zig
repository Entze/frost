//! Group pattern that matches a subpattern and counts as a capture group (regex `(PATTERN)`).

const std = @import("std");
const assert = std.debug.assert;
const MatchGroup = @import("match_group.zig").MatchGroup;
const Match = @import("match.zig").Match;

// Note: Pattern is imported from parent, creating a circular dependency
// This is intentional and necessary: Pattern contains Group,
// and Group contains pointer to Pattern
const Pattern = @import("../pattern.zig").Pattern;

/// Group pattern that wraps another pattern and represents a capture group.
///
/// Since patterns are defined at compile time, uses a pointer to Pattern.
/// The max_size parameter is inherited from the Pattern type.
pub fn Group(comptime max_size: usize) type {
    return struct {
        pattern: *const Pattern(max_size),

        const Self = @This();

        /// Number of groups this pattern produces (always 1: the full match).
        /// This constant is for compatibility with other patterns.
        /// The actual number of groups produced during matching is 1 + pattern.groups_matched.
        pub const groups_count = 1;

        /// Matches the wrapped pattern from the input.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        /// - pattern must be valid pointer
        ///
        /// Postconditions:
        /// - If pattern doesn't match, returns Match with 0 bytes consumed
        /// - If pattern matches, returns Match with same bytes consumed and 1 group
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match(groups_count) {
            // Preconditions - pattern pointer validity is guaranteed by type system

            // Delegate to wrapped pattern
            const pattern_match = self.pattern.match(input);

            if (pattern_match.bytes_consumed == 0) {
                // Pattern failed to match
                const result = Match(groups_count).empty;

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups_matched == 0);

                return result;
            }

            // Pattern matched successfully - Group produces its own group 0 which wraps the subpattern
            const groups = [_]MatchGroup{MatchGroup.init(0, pattern_match.bytes_consumed)};
            const result = Match(groups_count).init(
                pattern_match.bytes_consumed,
                1,
                groups,
            );

            // Postconditions
            defer assert(result.bytes_consumed == pattern_match.bytes_consumed);
            defer assert(result.groups_matched == 1);
            defer assert(result.groups[0].len() == pattern_match.bytes_consumed);

            return result;
        }
    };
}

test "Group: match empty input" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character{ .character = 'a' } };
    const group = Group(10){ .pattern = &char };
    const input = "";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Group: match character pattern" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character{ .character = 'a' } };
    const group = Group(10){ .pattern = &char };
    const input = "abc";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
}

test "Group: match wildcard pattern" {
    const P = Pattern(10);
    const Wildcard = @import("wildcard.zig").Wildcard;
    const wildcard = P{ .wildcard = Wildcard{} };
    const group = Group(10){ .pattern = &wildcard };
    const input = "hello";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("h", input[result.groups[0].begin..result.groups[0].end]);
}

test "Group: no match for non-matching character" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character{ .character = 'x' } };
    const group = Group(10){ .pattern = &char };
    const input = "abc";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Group: match concatenation" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const Concatenation = @import("concatenation.zig").Concatenation;
    const p1 = P{ .character = Character{ .character = 'h' } };
    const p2 = P{ .character = Character{ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const concat_pattern = P{ .concatenation = concat };
    const group = Group(10){ .pattern = &concat_pattern };
    const input = "hi there";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("hi", input[result.groups[0].begin..result.groups[0].end]);
}

test "Group: groups_count constant" {
    const G = Group(10);
    try std.testing.expectEqual(@as(usize, 1), G.groups_count);
}

test "fuzz: Group never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const P = Pattern(10);
            const Character = @import("character.zig").Character;
            const char = P{ .character = Character{ .character = 'a' } };
            const group = Group(10){ .pattern = &char };
            const result = group.match(input);
            // Group should never panic and should consume 0 or 1 bytes
            try std.testing.expect(result.bytes_consumed <= 1);
            if (result.bytes_consumed == 0) {
                try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
            } else {
                try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
                try std.testing.expectEqual(@as(usize, 1), result.groups[0].len());
                try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
            }
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

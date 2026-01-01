//! NoneOrOnce pattern that matches its subpattern zero or one time (regex `PATTERN?`).

const std = @import("std");
const assert = std.debug.assert;
const MatchGroup = @import("match_group.zig").MatchGroup;
const Match = @import("match.zig").Match;

// Note: Pattern is imported from parent, creating a circular dependency
// This is intentional and necessary: Pattern contains NoneOrOnce,
// and NoneOrOnce contains pointer to Pattern
const Pattern = @import("../pattern.zig").Pattern;

/// NoneOrOnce pattern that wraps another pattern and matches it zero or one time.
///
/// Since patterns are defined at compile time, uses a pointer to Pattern.
/// The max_size parameter is inherited from the Pattern type.
/// NoneOrOnce always succeeds: it returns the wrapped pattern's match on success,
/// or a zero-length match on failure.
pub fn NoneOrOnce(comptime max_size: usize) type {
    return struct {
        pattern: *const Pattern(max_size),

        const Self = @This();

        /// Matches the wrapped pattern from the input, or succeeds with zero-length match.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        /// - pattern must be valid pointer
        ///
        /// Postconditions:
        /// - Always returns a Match (never fails)
        /// - If pattern doesn't match, returns Match with 0 bytes consumed and 0 groups
        /// - If pattern matches, returns Match with same bytes consumed and groups as pattern
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match(max_size) {
            // Preconditions - pattern pointer validity is guaranteed by type system

            // Delegate to wrapped pattern
            const pattern_match = self.pattern.match(input);

            if (pattern_match.groups_matched == 0) {
                // Pattern failed to match - return zero-length match (NoneOrOnce always succeeds)
                const result = Match(max_size).empty;

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups_matched == 0);

                return result;
            }

            // Pattern matched successfully - return the pattern's match as-is
            const result = pattern_match;

            // Postconditions
            defer assert(result.bytes_consumed == pattern_match.bytes_consumed);
            defer assert(result.groups_matched == pattern_match.groups_matched);

            return result;
        }
    };
}

test "NoneOrOnce: match empty input with character pattern" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character(10){ .character = 'a' } };
    const none_or_once = NoneOrOnce(10){ .pattern = &char };
    const input = "";
    const result = none_or_once.match(input);

    // Should succeed with zero-length match since pattern doesn't match empty input
    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "NoneOrOnce: subpattern succeeds - returns subpattern match" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character(10){ .character = 'a' } };
    const none_or_once = NoneOrOnce(10){ .pattern = &char };
    const input = "abc";
    const result = none_or_once.match(input);

    // Should match 'a' and return the character's match
    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
}

test "NoneOrOnce: subpattern fails - returns zero-length match" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character(10){ .character = 'x' } };
    const none_or_once = NoneOrOnce(10){ .pattern = &char };
    const input = "abc";
    const result = none_or_once.match(input);

    // Should succeed with zero-length match since 'x' doesn't match 'a'
    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "NoneOrOnce: with wildcard pattern" {
    const P = Pattern(10);
    const Wildcard = @import("wildcard.zig").Wildcard;
    const wildcard = P{ .wildcard = Wildcard(10){} };
    const none_or_once = NoneOrOnce(10){ .pattern = &wildcard };
    const input = "hello";
    const result = none_or_once.match(input);

    // Should match first character
    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("h", input[result.groups[0].begin..result.groups[0].end]);
}

test "NoneOrOnce: nested NoneOrOnce patterns" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character(10){ .character = 'a' } };
    const inner = P{ .none_or_once = NoneOrOnce(10){ .pattern = &char } };
    const outer = NoneOrOnce(10){ .pattern = &inner };

    const input1 = "abc";
    const result1 = outer.match(input1);
    // Should match 'a'
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result1.groups_matched);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "xyz";
    const result2 = outer.match(input2);
    // Should succeed with zero-length match (inner doesn't match, outer returns empty)
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result2.groups_matched);
}

test "NoneOrOnce: with group pattern" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const Group = @import("group.zig").Group;
    const char = P{ .character = Character(10){ .character = 'a' } };
    const group = P{ .group = Group(10){ .pattern = &char } };
    const none_or_once = NoneOrOnce(10){ .pattern = &group };

    const input1 = "abc";
    const result1 = none_or_once.match(input1);
    // Should match 'a' with 2 groups (group 0 and group 1)
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result1.groups_matched);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);
    try std.testing.expectEqualStrings("a", input1[result1.groups[1].begin..result1.groups[1].end]);

    const input2 = "xyz";
    const result2 = none_or_once.match(input2);
    // Should succeed with zero-length match
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result2.groups_matched);
}

test "fuzz: NoneOrOnce never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const P = Pattern(10);
            const Character = @import("character.zig").Character;
            const char = P{ .character = Character(10){ .character = 'a' } };
            const none_or_once = NoneOrOnce(10){ .pattern = &char };
            const result = none_or_once.match(input);
            // NoneOrOnce should never panic and should consume 0 or 1 bytes (for this simple pattern)
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

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
/// Group produces 1 + pattern.groups_matched groups: the outer group plus all inner groups.
pub fn Group(comptime max_size: usize) type {
    return struct {
        pattern: *const Pattern(max_size),

        const Self = @This();

        /// Matches the wrapped pattern from the input.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        /// - pattern must be valid pointer
        ///
        /// Postconditions:
        /// - If pattern doesn't match, returns Match with 0 bytes consumed
        /// - If pattern matches, returns Match with same bytes consumed and 1 + pattern.groups_matched groups
        ///   - Group 0: the entire match (same as pattern's group 0)
        ///   - Group 1: the group itself (same span as group 0, but represents this capture group)
        ///   - Groups 2+: groups from the wrapped pattern (shifted by 1)
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

            if (pattern_match.bytes_consumed == 0) {
                // Pattern failed to match
                const result = Match(max_size).empty;

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups_matched == 0);

                return result;
            }

            // Pattern matched successfully
            // Group produces: group 0 (full match), group 1 (this capture group), then all subgroups shifted
            var groups = [_]MatchGroup{MatchGroup{ .begin = 0, .end = 0 }} ** max_size;
            
            // Group 0: the entire match (same as pattern's group 0)
            groups[0] = pattern_match.groups[0];
            
            // Group 1: this capture group (same span as group 0)
            groups[1] = MatchGroup.init(0, pattern_match.bytes_consumed);
            
            // Copy subpattern groups, shifting indices by 1
            // Loop has determinable upper bound: pattern_match.groups_matched
            var i: usize = 1;
            while (i < pattern_match.groups_matched) : (i += 1) {
                // Loop invariant: i < pattern_match.groups_matched
                assert(i < pattern_match.groups_matched);
                assert(i + 1 < max_size);
                
                groups[i + 1] = pattern_match.groups[i];
            }

            const total_groups = 1 + pattern_match.groups_matched;
            const result = Match(max_size).init(
                pattern_match.bytes_consumed,
                total_groups,
                groups,
            );

            // Postconditions
            defer assert(result.bytes_consumed == pattern_match.bytes_consumed);
            defer assert(result.groups_matched == total_groups);
            defer assert(result.groups[0].len() == pattern_match.bytes_consumed);
            defer assert(result.groups[1].len() == pattern_match.bytes_consumed);

            return result;
        }
    };
}

test "Group: match empty input" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character(10){ .character = 'a' } };
    const group = Group(10){ .pattern = &char };
    const input = "";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Group: match character pattern" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character(10){ .character = 'a' } };
    const group = Group(10){ .pattern = &char };
    const input = "abc";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.groups_matched);
    try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
    try std.testing.expectEqualStrings("a", input[result.groups[1].begin..result.groups[1].end]);
}

test "Group: match wildcard pattern" {
    const P = Pattern(10);
    const Wildcard = @import("wildcard.zig").Wildcard;
    const wildcard = P{ .wildcard = Wildcard(10){} };
    const group = Group(10){ .pattern = &wildcard };
    const input = "hello";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.groups_matched);
    try std.testing.expectEqualStrings("h", input[result.groups[0].begin..result.groups[0].end]);
    try std.testing.expectEqualStrings("h", input[result.groups[1].begin..result.groups[1].end]);
}

test "Group: no match for non-matching character" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character(10){ .character = 'x' } };
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
    const p1 = P{ .character = Character(10){ .character = 'h' } };
    const p2 = P{ .character = Character(10){ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const concat_pattern = P{ .concatenation = concat };
    const group = Group(10){ .pattern = &concat_pattern };
    const input = "hi there";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.groups_matched);
    try std.testing.expectEqualStrings("hi", input[result.groups[0].begin..result.groups[0].end]);
    try std.testing.expectEqualStrings("hi", input[result.groups[1].begin..result.groups[1].end]);
}

test "Group: nested groups" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character(10){ .character = 'a' } };
    const inner_group = P{ .group = Group(10){ .pattern = &char } };
    const outer_group = Group(10){ .pattern = &inner_group };
    const input = "abc";
    const result = outer_group.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.groups_matched);
    try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
    try std.testing.expectEqualStrings("a", input[result.groups[1].begin..result.groups[1].end]);
    try std.testing.expectEqualStrings("a", input[result.groups[2].begin..result.groups[2].end]);
}

test "Group: wrapping empty match" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const char = P{ .character = Character(10){ .character = 'z' } };
    const group = Group(10){ .pattern = &char };
    const input = "abc";
    const result = group.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "fuzz: Group never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const P = Pattern(10);
            const Character = @import("character.zig").Character;
            const char = P{ .character = Character(10){ .character = 'a' } };
            const group = Group(10){ .pattern = &char };
            const result = group.match(input);
            // Group should never panic and should consume 0 or 1 bytes
            try std.testing.expect(result.bytes_consumed <= 1);
            if (result.bytes_consumed == 0) {
                try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
            } else {
                try std.testing.expectEqual(@as(usize, 2), result.groups_matched);
                try std.testing.expectEqual(@as(usize, 1), result.groups[0].len());
                try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
            }
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

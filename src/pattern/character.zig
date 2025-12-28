//! Character pattern that matches a specific single character.

const std = @import("std");
const assert = std.debug.assert;
const MatchGroup = @import("match_group.zig").MatchGroup;
const Match = @import("match.zig").Match;

/// Character pattern that matches a specific single character.
///
/// This is a function that returns a struct, allowing the Match return type
/// to be sized appropriately for the containing Pattern.
pub fn Character(comptime max_groups: usize) type {
    return struct {
        character: u8,

        const Self = @This();

        /// Matches the specified character from the input.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        ///
        /// Postconditions:
        /// - If input is empty or first character doesn't match, returns Match with 0 bytes consumed
        /// - If first character matches, returns Match with 1 byte consumed and 1 group
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match(max_groups) {
            // Preconditions - validated by type system

            if (input.len == 0) {
                // No input to match
                const result = Match(max_groups).empty;

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups_matched == 0);

                return result;
            }

            if (input[0] != self.character) {
                // Character doesn't match
                const result = Match(max_groups).empty;

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups_matched == 0);

                return result;
            }

            // Character matches
            var groups = [_]MatchGroup{MatchGroup{ .begin = 0, .end = 0 }} ** max_groups;
            groups[0] = MatchGroup.init(0, 1);
            const result = Match(max_groups).init(1, 1, groups);

            // Postconditions
            defer assert(result.bytes_consumed == 1);
            defer assert(result.groups_matched == 1);
            defer assert(result.groups[0].len() == 1);

            return result;
        }
    };
}

test "Character: match empty input" {
    const char = Character(1){ .character = 'a' };
    const input = "";
    const result = char.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Character: match matching character" {
    const char = Character(1){ .character = 'a' };
    const input = "abc";
    const result = char.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
}

test "Character: no match for different character" {
    const char = Character(1){ .character = 'a' };
    const input = "bcd";
    const result = char.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Character: match first character only" {
    const char = Character(1){ .character = 'h' };
    const input = "hello";
    const result = char.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("h", input[result.groups[0].begin..result.groups[0].end]);
}

test "Character: match special characters" {
    // Test newline
    const char1 = Character(1){ .character = '\n' };
    const input1 = "\ntest";
    const result1 = char1.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("\n", input1[result1.groups[0].begin..result1.groups[0].end]);

    // Test digit
    const char2 = Character(1){ .character = '5' };
    const input2 = "5678";
    const result2 = char2.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("5", input2[result2.groups[0].begin..result2.groups[0].end]);
}

test "fuzz: Character never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const char = Character(1){ .character = 'a' };
            const result = char.match(input);
            // Character should never panic and should consume 0 or 1 bytes
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

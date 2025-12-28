//! Wildcard pattern that matches any single character (regex `.`).

const std = @import("std");
const assert = std.debug.assert;
const MatchGroup = @import("match_group.zig").MatchGroup;
const Match = @import("match.zig").Match;

/// Wildcard pattern that matches any single character (regex `.`).
/// 
/// This is a function that returns a struct, allowing the Match return type
/// to be sized appropriately for the containing Pattern.
pub fn Wildcard(comptime max_groups: usize) type {
    return struct {
        const Self = @This();

        /// Matches any single character from the input.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        ///
        /// Postconditions:
        /// - If input is empty, returns Match with 0 bytes consumed and 0 groups
        /// - If input is non-empty, returns Match with 1 byte consumed and 1 group
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match(max_groups) {
            _ = self;

            // Preconditions - input is already validated by type system

            if (input.len == 0) {
                // No input to match
                const result = Match(max_groups).empty;

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups_matched == 0);

                return result;
            }

            // Match first character
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

test "Wildcard: match empty input" {
    const wildcard = Wildcard(1){};
    const input = "";
    const result = wildcard.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Wildcard: match single character" {
    const wildcard = Wildcard(1){};
    const input = "a";
    const result = wildcard.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqual(@as(usize, 0), result.groups[0].begin);
    try std.testing.expectEqual(@as(usize, 1), result.groups[0].end);
    try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
}

test "Wildcard: match first character of multiple" {
    const wildcard = Wildcard(1){};
    const input = "hello";
    const result = wildcard.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("h", input[result.groups[0].begin..result.groups[0].end]);
}

test "Wildcard: match special characters" {
    const wildcard = Wildcard(1){};

    // Test newline
    const input1 = "\n";
    const result1 = wildcard.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("\n", input1[result1.groups[0].begin..result1.groups[0].end]);

    // Test tab
    const input2 = "\t";
    const result2 = wildcard.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("\t", input2[result2.groups[0].begin..result2.groups[0].end]);

    // Test space
    const input3 = " ";
    const result3 = wildcard.match(input3);
    try std.testing.expectEqual(@as(usize, 1), result3.bytes_consumed);
    try std.testing.expectEqualStrings(" ", input3[result3.groups[0].begin..result3.groups[0].end]);
}

test "fuzz: Wildcard never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const wildcard = Wildcard(1){};
            const result = wildcard.match(input);
            // Wildcard should never panic and should consume 0 or 1 bytes
            try std.testing.expect(result.bytes_consumed <= 1);
            if (result.bytes_consumed == 0) {
                try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
            } else {
                try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
                try std.testing.expectEqual(@as(usize, 1), result.groups[0].len());
            }
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

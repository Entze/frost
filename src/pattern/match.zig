//! Result of a pattern matching operation.

const std = @import("std");
const assert = std.debug.assert;
const Group = @import("group.zig").Group;

/// Result of a pattern matching operation.
///
/// Contains the number of bytes consumed from the input and an array of matched groups.
/// Group 0 represents the entire matched pattern.
/// The maximum number of groups is determined at compile time by the pattern type.
pub fn Match(comptime max_groups: usize) type {
    return struct {
        /// Number of bytes consumed from the input string.
        /// Zero indicates no match or empty input.
        bytes_consumed: usize,

        /// Number of groups matched (0 for no match, at least 1 for a match).
        groups_matched: usize,

        /// Matched groups. All groups > 0 are a subgroup of group 0.
        /// Only the first groups_matched elements are valid.
        groups: [max_groups]Group,

        const Self = @This();

        /// Empty match constant for cases where no match occurred.
        pub const empty: Self = .{
            .bytes_consumed = 0,
            .groups_matched = 0,
            .groups = [_]Group{Group{ .begin = 0, .end = 0 }} ** max_groups,
        };

        /// Creates a new Match result.
        ///
        /// Preconditions:
        /// - bytes_consumed >= 0 (enforced by type)
        /// - groups_matched <= max_groups
        /// - groups_matched == 0 iff bytes_consumed == 0
        ///
        /// Postconditions:
        /// - Returns Match with specified values
        pub fn init(bytes_consumed: usize, groups_matched: usize, groups: [max_groups]Group) Self {
            // Preconditions
            assert(groups_matched <= max_groups);
            assert((groups_matched == 0) == (bytes_consumed == 0));

            const result = Self{
                .bytes_consumed = bytes_consumed,
                .groups_matched = groups_matched,
                .groups = groups,
            };

            // Postconditions
            defer assert(result.bytes_consumed == bytes_consumed);
            defer assert(result.groups_matched == groups_matched);

            return result;
        }
    };
}

test "Match: init with no groups" {
    const M = Match(1);
    const match = M.empty;

    try std.testing.expectEqual(@as(usize, 0), match.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), match.groups_matched);
}

test "Match: init with single group" {
    const M = Match(1);
    const input = "hello";
    const groups = [_]Group{Group.init(0, 5)};
    const match = M.init(5, 1, groups);

    try std.testing.expectEqual(@as(usize, 5), match.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), match.groups_matched);
    try std.testing.expectEqual(@as(usize, 0), match.groups[0].begin);
    try std.testing.expectEqual(@as(usize, 5), match.groups[0].end);
    // Verify we can extract the matched text
    const matched_text = input[match.groups[0].begin..match.groups[0].end];
    try std.testing.expectEqualStrings("hello", matched_text);
}

test "Match: init with multiple groups" {
    const M = Match(2);
    const input = "helloworld";
    const groups = [_]Group{ Group.init(0, 10), Group.init(5, 10) };
    const match = M.init(10, 2, groups);

    try std.testing.expectEqual(@as(usize, 10), match.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), match.groups_matched);
    // Verify group 0
    const group0_text = input[match.groups[0].begin..match.groups[0].end];
    try std.testing.expectEqualStrings("helloworld", group0_text);
    // Verify group 1
    const group1_text = input[match.groups[1].begin..match.groups[1].end];
    try std.testing.expectEqualStrings("world", group1_text);
}

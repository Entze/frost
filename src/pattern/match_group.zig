//! Represents a matched group as a range in the input string.

const std = @import("std");
const assert = std.debug.assert;

/// Represents a matched group as a range in the input string.
///
/// begin and end are byte indices into the original input string.
/// The matched text is input[begin..end].
pub const MatchGroup = struct {
    /// Start index (inclusive) of the matched group in the input string.
    begin: usize,
    /// End index (exclusive) of the matched group in the input string.
    end: usize,

    const Self = @This();

    /// Creates a new MatchGroup from begin and end indices.
    pub fn init(begin: usize, end: usize) Self {
        assert(begin <= end);
        return Self{
            .begin = begin,
            .end = end,
        };
    }

    /// Returns the length of the matched group.
    pub fn len(self: Self) usize {
        return self.end - self.begin;
    }
};

test "MatchGroup: basic functionality" {
    const group = MatchGroup.init(5, 10);
    try std.testing.expectEqual(@as(usize, 5), group.begin);
    try std.testing.expectEqual(@as(usize, 10), group.end);
    try std.testing.expectEqual(@as(usize, 5), group.len());
}

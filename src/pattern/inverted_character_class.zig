//! InvertedCharacterClass pattern that matches any character not in a set (regex `[^ ]`).

const std = @import("std");
const assert = std.debug.assert;
const MatchGroup = @import("match_group.zig").MatchGroup;
const Match = @import("match.zig").Match;

/// Helper function to create InvertedCharacterClass with inferred size.
///
/// Since patterns are defined at compile time, the character set is stored
/// as a compile-time array.
pub fn invertedCharacterClass(comptime characters: []const u8) InvertedCharacterClass(characters.len) {
    var result: InvertedCharacterClass(characters.len) = undefined;
    result.count = characters.len;
    for (characters, 0..) |c, i| {
        result.characters[i] = c;
    }
    return result;
}

/// InvertedCharacterClass pattern that matches any character not in a set (regex `[^ ]`).
///
/// Since patterns are defined at compile time, the character set is stored
/// as a compile-time array.
pub fn InvertedCharacterClass(comptime size: usize) type {
    return struct {
        characters: [size]u8,
        count: usize,

        const Self = @This();

        /// Number of groups this pattern produces (always 1: the full match).
        pub const groups_count = 1;

        /// Creates an InvertedCharacterClass from a compile-time character slice.
        /// The storage size must be >= slice length.
        ///
        /// Note: Unlike CharacterClass, empty exclusion sets are allowed.
        /// An empty exclusion set matches any character (nothing is excluded).
        ///
        /// It's easier to use the module-level `invertedCharacterClass()` function
        /// which infers the size automatically.
        pub fn init(comptime characters: []const u8) Self {
            assert(characters.len <= size);
            var result: Self = undefined;
            result.count = characters.len;
            for (characters, 0..) |c, i| {
                result.characters[i] = c;
            }
            return result;
        }

        /// Matches any character not in the character set.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        /// - characters array may be empty (matches any character)
        ///
        /// Postconditions:
        /// - If input is empty, returns Match with 0 bytes consumed
        /// - If first character in exclusion set, returns Match with 0 bytes consumed
        /// - If first character not in exclusion set, returns Match with 1 byte consumed and 1 group
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match(groups_count) {
            // Preconditions
            assert(self.count <= size);

            if (input.len == 0) {
                // No input to match
                const result = Match(groups_count).empty;

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups_matched == 0);

                return result;
            }

            // If exclusion set is empty, match any character
            if (self.count == 0) {
                const groups = [_]MatchGroup{MatchGroup.init(0, 1)};
                const result = Match(groups_count).init(1, 1, groups);

                // Postconditions
                defer assert(result.bytes_consumed == 1);
                defer assert(result.groups_matched == 1);
                defer assert(result.groups[0].len() == 1);

                return result;
            }

            const first_char = input[0];

            // Check if first character is NOT in the exclusion set
            // Loop has determinable upper bound: self.count (runtime validated <= size)
            // We only reach here if count > 0
            // Note: comptime check required because Zig won't allow indexing into
            // zero-sized arrays even if runtime logic prevents it
            if (comptime size > 0) {
                var i: usize = 0;
                while (i < self.count) : (i += 1) {
                    // Loop invariant: i < self.count
                    assert(i < self.count);

                    if (self.characters[i] == first_char) {
                        // Character is in exclusion set - no match
                        const result = Match(groups_count).empty;

                        // Postconditions
                        defer assert(result.bytes_consumed == 0);
                        defer assert(result.groups_matched == 0);

                        return result;
                    }
                }
            }

            // Character not in exclusion set - match
            const groups = [_]MatchGroup{MatchGroup.init(0, 1)};
            const result = Match(groups_count).init(1, 1, groups);

            // Postconditions
            defer assert(result.bytes_consumed == 1);
            defer assert(result.groups_matched == 1);
            defer assert(result.groups[0].len() == 1);

            return result;
        }
    };
}

test "InvertedCharacterClass: match empty input" {
    const class = InvertedCharacterClass(3).init("abc");
    const input = "";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "InvertedCharacterClass: match character not in set" {
    const class = InvertedCharacterClass(3).init("abc");
    const input = "dog";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("d", input[result.groups[0].begin..result.groups[0].end]);
}

test "InvertedCharacterClass: no match for character in set" {
    const class = InvertedCharacterClass(3).init("abc");
    const input = "apple";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "InvertedCharacterClass: match with empty exclusion set" {
    const class = InvertedCharacterClass(0).init("");
    const input = "anything";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
}

test "InvertedCharacterClass: no match for first character in set" {
    const class = InvertedCharacterClass(3).init("abc");
    const input = "apple";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "InvertedCharacterClass: no match for middle character in set" {
    const class = InvertedCharacterClass(3).init("abc");
    const input = "banana";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "InvertedCharacterClass: no match for last character in set" {
    const class = InvertedCharacterClass(3).init("abc");
    const input = "cat";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "InvertedCharacterClass: match non-digit" {
    const class = InvertedCharacterClass(10).init("0123456789");

    const input1 = "abc";
    const result1 = class.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "xyz";
    const result2 = class.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("x", input2[result2.groups[0].begin..result2.groups[0].end]);
}

test "InvertedCharacterClass: no match for digit" {
    const class = InvertedCharacterClass(10).init("0123456789");

    const input1 = "123";
    const result1 = class.match(input1);
    try std.testing.expectEqual(@as(usize, 0), result1.bytes_consumed);

    const input2 = "987";
    const result2 = class.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "InvertedCharacterClass: single character exclusion" {
    const class = InvertedCharacterClass(1).init("x");
    const input1 = "abc";
    const result1 = class.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "xyz";
    const result2 = class.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "InvertedCharacterClass: invertedCharacterClass helper with automatic size inference" {
    const nonVowels = invertedCharacterClass("aeiou");
    const input1 = "banana";
    const result1 = nonVowels.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("b", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "apple";
    const result2 = nonVowels.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);

    const nonDigits = invertedCharacterClass("0123456789");
    const input3 = "test42";
    const result3 = nonDigits.match(input3);
    try std.testing.expectEqual(@as(usize, 1), result3.bytes_consumed);
    try std.testing.expectEqualStrings("t", input3[result3.groups[0].begin..result3.groups[0].end]);
}

test "fuzz: InvertedCharacterClass never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const class = InvertedCharacterClass(3).init("abc");
            const result = class.match(input);
            // InvertedCharacterClass should never panic and should consume 0 or 1 bytes
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

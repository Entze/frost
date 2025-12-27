//! CharacterClass pattern that matches any character in a set (regex `[ ]`).

const std = @import("std");
const assert = std.debug.assert;
const Group = @import("group.zig").Group;
const Match = @import("match.zig").Match;

/// Helper function to create CharacterClass with inferred size.
///
/// Since patterns are defined at compile time, the character set is stored
/// as a compile-time array.
pub fn characterClass(comptime characters: []const u8) CharacterClass(characters.len) {
    var result: CharacterClass(characters.len) = undefined;
    result.count = characters.len;
    for (characters, 0..) |c, i| {
        result.characters[i] = c;
    }
    return result;
}

test characterClass {
    // Helper function to create CharacterClass with inferred size
    const vowels = characterClass("aeiou");
    const input = "apple";
    const result = vowels.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
}

/// CharacterClass pattern that matches any character in a set (regex `[ ]`).
///
/// Since patterns are defined at compile time, the character set is stored
/// as a compile-time array.
pub fn CharacterClass(comptime size: usize) type {
    return struct {
        characters: [size]u8,
        count: usize,

        const Self = @This();

        /// Number of groups this pattern produces (always 1: the full match).
        pub const groups_count = 1;

        /// Creates a CharacterClass from a compile-time character slice.
        /// The storage size must be >= slice length.
        ///
        /// Note: It's easier to use the module-level `characterClass()` function
        /// which infers the size automatically.
        pub fn init(comptime characters: []const u8) Self {
            assert(characters.len <= size);
            assert(characters.len > 0);
            var result: Self = undefined;
            result.count = characters.len;
            for (characters, 0..) |c, i| {
                result.characters[i] = c;
            }
            return result;
        }

        test init {
            // Example: Uses 3 of 10 slots
            const cc = CharacterClass(10).init("aei");
            try std.testing.expectEqual(@as(usize, 3), cc.count);

            // Example: Uses all 10 slots
            const digits = CharacterClass(10).init("0123456789");
            try std.testing.expectEqual(@as(usize, 10), digits.count);

            // Test matching
            const input = "apple";
            const result = cc.match(input);
            try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
            try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
        }

        /// Matches any character from the character set.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        /// - characters array contains at least one character (size > 0)
        ///
        /// Postconditions:
        /// - If input is empty or first character not in set, returns Match with 0 bytes consumed
        /// - If first character in set, returns Match with 1 byte consumed and 1 group
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match(groups_count) {
            // Preconditions
            assert(self.count > 0);
            assert(self.count <= size);

            if (input.len == 0) {
                // No input to match
                const result = Match(groups_count).empty;

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups_matched == 0);

                return result;
            }

            const first_char = input[0];

            // Check if first character is in the set
            // Loop has determinable upper bound: self.count (runtime validated <= size)
            var i: usize = 0;
            while (i < self.count) : (i += 1) {
                // Loop invariant: i < self.count
                assert(i < self.count);

                if (self.characters[i] == first_char) {
                    // Character matches
                    const groups = [_]Group{Group.init(0, 1)};
                    const result = Match(groups_count).init(1, 1, groups);

                    // Postconditions
                    defer assert(result.bytes_consumed == 1);
                    defer assert(result.groups_matched == 1);
                    defer assert(result.groups[0].len() == 1);

                    return result;
                }
            }

            // No match found
            const result = Match(groups_count).empty;

            // Postconditions
            defer assert(result.bytes_consumed == 0);
            defer assert(result.groups_matched == 0);

            return result;
        }
    };
}

test "CharacterClass: match empty input" {
    const class = CharacterClass(3).init("abc");
    const input = "";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "CharacterClass: match first character in set" {
    const class = CharacterClass(3).init("abc");
    const input = "apple";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("a", input[result.groups[0].begin..result.groups[0].end]);
}

test "CharacterClass: match middle character in set" {
    const class = CharacterClass(3).init("abc");
    const input = "banana";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("b", input[result.groups[0].begin..result.groups[0].end]);
}

test "CharacterClass: match last character in set" {
    const class = CharacterClass(3).init("abc");
    const input = "cat";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("c", input[result.groups[0].begin..result.groups[0].end]);
}

test "CharacterClass: no match for character not in set" {
    const class = CharacterClass(3).init("abc");
    const input = "dog";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "CharacterClass: match digits" {
    const class = CharacterClass(10).init("0123456789");

    const input1 = "123";
    const result1 = class.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("1", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "987";
    const result2 = class.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("9", input2[result2.groups[0].begin..result2.groups[0].end]);
}

test "CharacterClass: single character set" {
    const class = CharacterClass(1).init("x");
    const input1 = "xyz";
    const result1 = class.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("x", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "abc";
    const result2 = class.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "CharacterClass: init helper with size inference" {
    const vowels = CharacterClass(5).init("aeiou");
    const input1 = "apple";
    const result1 = vowels.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);

    const input2 = "banana";
    const result2 = vowels.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "CharacterClass: characterClass helper with automatic size inference" {
    const vowels = characterClass("aeiou");
    const input1 = "apple";
    const result1 = vowels.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", input1[result1.groups[0].begin..result1.groups[0].end]);

    const digits = characterClass("0123456789");
    const input2 = "42";
    const result2 = digits.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("4", input2[result2.groups[0].begin..result2.groups[0].end]);
}

test "fuzz: CharacterClass never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const class = CharacterClass(3).init("abc");
            const result = class.match(input);
            // CharacterClass should never panic and should consume 0 or 1 bytes
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

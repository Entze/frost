//! Pattern matching module for building lexer-parser pipelines.
//!
//! This module provides a Pattern type as a tagged union with four basic variants:
//! - Wildcard: Matches any single character (regex `.`)
//! - Character: Matches a specific single character
//! - CharacterClass: Matches characters in a set (regex `[ ]`)
//! - Concatenation: Matches sequential patterns
//!
//! All patterns are defined at compile time, allowing variants to use arrays for storage.

const std = @import("std");
const assert = std.debug.assert;

/// Result of a pattern matching operation.
///
/// Contains the number of bytes consumed from the input and a slice of matched groups.
/// Group 0 represents the entire matched pattern.
pub const Match = struct {
    bytes_consumed: usize,
    groups: []const []const u8,

    const Self = @This();

    /// Creates a new Match result.
    ///
    /// Preconditions:
    /// - bytes_consumed >= 0 (enforced by type)
    ///
    /// Postconditions:
    /// - Returns Match with specified values
    ///
    /// Ownership:
    /// - Caller retains ownership of groups slice
    ///
    /// Lifetime:
    /// - groups slice must remain valid for lifetime of Match
    pub fn init(bytes_consumed: usize, groups: []const []const u8) Self {
        const result = Self{
            .bytes_consumed = bytes_consumed,
            .groups = groups,
        };

        // Postconditions
        defer assert(result.bytes_consumed == bytes_consumed);
        defer assert(result.groups.ptr == groups.ptr);
        defer assert(result.groups.len == groups.len);

        return result;
    }
};

test "Match: init with no groups" {
    const empty_groups: []const []const u8 = &[_][]const u8{};
    const match = Match.init(0, empty_groups);

    try std.testing.expectEqual(@as(usize, 0), match.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), match.groups.len);
}

test "Match: init with single group" {
    const input = "hello";
    const groups = &[_][]const u8{input};
    const match = Match.init(5, groups);

    try std.testing.expectEqual(@as(usize, 5), match.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), match.groups.len);
    try std.testing.expectEqualStrings("hello", match.groups[0]);
}

test "Match: init with multiple groups" {
    const group0 = "hello";
    const group1 = "world";
    const groups = &[_][]const u8{ group0, group1 };
    const match = Match.init(10, groups);

    try std.testing.expectEqual(@as(usize, 10), match.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), match.groups.len);
    try std.testing.expectEqualStrings("hello", match.groups[0]);
    try std.testing.expectEqualStrings("world", match.groups[1]);
}

/// Wildcard pattern that matches any single character (regex `.`).
pub const Wildcard = struct {
    const Self = @This();

    /// Matches any single character from the input.
    ///
    /// Preconditions:
    /// - input must be valid UTF-8 slice
    ///
    /// Postconditions:
    /// - If input is empty, returns Match with 0 bytes consumed and empty groups
    /// - If input is non-empty, returns Match with 1 byte consumed and groups[0] = first character
    ///
    /// Ownership:
    /// - input slice is borrowed, not owned
    /// - returned Match.groups references input memory
    ///
    /// Lifetime:
    /// - input must remain valid for lifetime of returned Match
    pub fn match(self: Self, input: []const u8) Match {
        _ = self;

        // Preconditions - input is already validated by type system

        if (input.len == 0) {
            // No input to match
            const empty_groups: []const []const u8 = &[_][]const u8{};
            const result = Match.init(0, empty_groups);

            // Postconditions
            defer assert(result.bytes_consumed == 0);
            defer assert(result.groups.len == 0);

            return result;
        }

        // Match first character
        const matched = input[0..1];
        const groups = &[_][]const u8{matched};
        const result = Match.init(1, groups);

        // Postconditions
        defer assert(result.bytes_consumed == 1);
        defer assert(result.groups.len == 1);
        defer assert(result.groups[0].len == 1);

        return result;
    }
};

test "Wildcard: match empty input" {
    const wildcard = Wildcard{};
    const input = "";
    const result = wildcard.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Wildcard: match single character" {
    const wildcard = Wildcard{};
    const input = "a";
    const result = wildcard.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("a", result.groups[0]);
}

test "Wildcard: match first character of multiple" {
    const wildcard = Wildcard{};
    const input = "hello";
    const result = wildcard.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("h", result.groups[0]);
}

test "Wildcard: match special characters" {
    const wildcard = Wildcard{};

    // Test newline
    const input1 = "\n";
    const result1 = wildcard.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("\n", result1.groups[0]);

    // Test tab
    const input2 = "\t";
    const result2 = wildcard.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("\t", result2.groups[0]);

    // Test space
    const input3 = " ";
    const result3 = wildcard.match(input3);
    try std.testing.expectEqual(@as(usize, 1), result3.bytes_consumed);
    try std.testing.expectEqualStrings(" ", result3.groups[0]);
}

/// Character pattern that matches a specific single character.
pub const Character = struct {
    character: u8,

    const Self = @This();

    /// Matches the specified character from the input.
    ///
    /// Preconditions:
    /// - input must be valid UTF-8 slice
    ///
    /// Postconditions:
    /// - If input is empty or first character doesn't match, returns Match with 0 bytes consumed
    /// - If first character matches, returns Match with 1 byte consumed and groups[0] = matched character
    ///
    /// Ownership:
    /// - input slice is borrowed, not owned
    /// - returned Match.groups references input memory
    ///
    /// Lifetime:
    /// - input must remain valid for lifetime of returned Match
    pub fn match(self: Self, input: []const u8) Match {
        // Preconditions - validated by type system

        if (input.len == 0) {
            // No input to match
            const empty_groups: []const []const u8 = &[_][]const u8{};
            const result = Match.init(0, empty_groups);

            // Postconditions
            defer assert(result.bytes_consumed == 0);
            defer assert(result.groups.len == 0);

            return result;
        }

        if (input[0] != self.character) {
            // Character doesn't match
            const empty_groups: []const []const u8 = &[_][]const u8{};
            const result = Match.init(0, empty_groups);

            // Postconditions
            defer assert(result.bytes_consumed == 0);
            defer assert(result.groups.len == 0);

            return result;
        }

        // Character matches
        const matched = input[0..1];
        const groups = &[_][]const u8{matched};
        const result = Match.init(1, groups);

        // Postconditions
        defer assert(result.bytes_consumed == 1);
        defer assert(result.groups.len == 1);
        defer assert(result.groups[0].len == 1);
        defer assert(result.groups[0][0] == self.character);

        return result;
    }
};

test "Character: match empty input" {
    const char = Character{ .character = 'a' };
    const input = "";
    const result = char.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Character: match matching character" {
    const char = Character{ .character = 'a' };
    const input = "abc";
    const result = char.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("a", result.groups[0]);
}

test "Character: no match for different character" {
    const char = Character{ .character = 'a' };
    const input = "bcd";
    const result = char.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Character: match first character only" {
    const char = Character{ .character = 'h' };
    const input = "hello";
    const result = char.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("h", result.groups[0]);
}

test "Character: match special characters" {
    // Test newline
    const char1 = Character{ .character = '\n' };
    const input1 = "\ntest";
    const result1 = char1.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("\n", result1.groups[0]);

    // Test digit
    const char2 = Character{ .character = '5' };
    const input2 = "5678";
    const result2 = char2.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("5", result2.groups[0]);
}

/// CharacterClass pattern that matches any character in a set (regex `[ ]`).
///
/// Since patterns are defined at compile time, the character set is stored
/// as a compile-time array.
pub fn CharacterClass(comptime size: usize) type {
    return struct {
        characters: [size]u8,

        const Self = @This();

        /// Matches any character from the character set.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        /// - characters array contains at least one character (size > 0)
        ///
        /// Postconditions:
        /// - If input is empty or first character not in set, returns Match with 0 bytes consumed
        /// - If first character in set, returns Match with 1 byte consumed and groups[0] = matched character
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        /// - returned Match.groups references input memory
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match {
            // Preconditions
            assert(size > 0);

            if (input.len == 0) {
                // No input to match
                const empty_groups: []const []const u8 = &[_][]const u8{};
                const result = Match.init(0, empty_groups);

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups.len == 0);

                return result;
            }

            const first_char = input[0];

            // Check if first character is in the set
            // Loop has determinable upper bound: size (compile-time constant)
            var i: usize = 0;
            while (i < size) : (i += 1) {
                // Loop invariant: i <= size
                assert(i < size);

                if (self.characters[i] == first_char) {
                    // Character matches
                    const matched = input[0..1];
                    const groups = &[_][]const u8{matched};
                    const result = Match.init(1, groups);

                    // Postconditions
                    defer assert(result.bytes_consumed == 1);
                    defer assert(result.groups.len == 1);
                    defer assert(result.groups[0].len == 1);
                    defer assert(result.groups[0][0] == first_char);

                    return result;
                }
            }

            // No match found
            const empty_groups: []const []const u8 = &[_][]const u8{};
            const result = Match.init(0, empty_groups);

            // Postconditions
            defer assert(result.bytes_consumed == 0);
            defer assert(result.groups.len == 0);

            return result;
        }
    };
}

test "CharacterClass: match empty input" {
    const class = CharacterClass(3){ .characters = .{ 'a', 'b', 'c' } };
    const input = "";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "CharacterClass: match first character in set" {
    const class = CharacterClass(3){ .characters = .{ 'a', 'b', 'c' } };
    const input = "apple";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("a", result.groups[0]);
}

test "CharacterClass: match middle character in set" {
    const class = CharacterClass(3){ .characters = .{ 'a', 'b', 'c' } };
    const input = "banana";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("b", result.groups[0]);
}

test "CharacterClass: match last character in set" {
    const class = CharacterClass(3){ .characters = .{ 'a', 'b', 'c' } };
    const input = "cat";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("c", result.groups[0]);
}

test "CharacterClass: no match for character not in set" {
    const class = CharacterClass(3){ .characters = .{ 'a', 'b', 'c' } };
    const input = "dog";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "CharacterClass: match digits" {
    const class = CharacterClass(10){ .characters = .{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' } };

    const input1 = "123";
    const result1 = class.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("1", result1.groups[0]);

    const input2 = "987";
    const result2 = class.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("9", result2.groups[0]);
}

test "CharacterClass: single character set" {
    const class = CharacterClass(1){ .characters = .{'x'} };
    const input1 = "xyz";
    const result1 = class.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("x", result1.groups[0]);

    const input2 = "abc";
    const result2 = class.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

/// Pattern tagged union containing all pattern variants.
///
/// This is the main abstraction for pattern matching. It delegates matching
/// behavior to its variants.
pub const Pattern = union(enum) {
    wildcard: Wildcard,
    character: Character,
    character_class_1: CharacterClass(1),
    character_class_2: CharacterClass(2),
    character_class_3: CharacterClass(3),
    character_class_10: CharacterClass(10),
    concatenation_2_char: Concatenation(struct { Character, Character }),
    concatenation_3_char: Concatenation(struct { Character, Character, Character }),
    concatenation_mixed_3: Concatenation(struct { Character, Wildcard, CharacterClass(3) }),

    const Self = @This();

    /// Matches the pattern against the input.
    ///
    /// Preconditions:
    /// - input must be valid UTF-8 slice
    ///
    /// Postconditions:
    /// - Returns Match result from the active variant
    ///
    /// Ownership:
    /// - input slice is borrowed, not owned
    /// - returned Match.groups references input memory
    ///
    /// Lifetime:
    /// - input must remain valid for lifetime of returned Match
    pub fn match(self: Self, input: []const u8) Match {
        return switch (self) {
            .wildcard => |w| w.match(input),
            .character => |c| c.match(input),
            .character_class_1 => |cc| cc.match(input),
            .character_class_2 => |cc| cc.match(input),
            .character_class_3 => |cc| cc.match(input),
            .character_class_10 => |cc| cc.match(input),
            .concatenation_2_char => |cat| cat.match(input),
            .concatenation_3_char => |cat| cat.match(input),
            .concatenation_mixed_3 => |cat| cat.match(input),
        };
    }
};

/// Concatenation pattern that matches sequential patterns.
///
/// Since patterns are defined at compile time, this is a generic type that
/// accepts pattern types as compile-time parameters.
pub fn Concatenation(comptime PatternTypes: type) type {
    return struct {
        patterns: PatternTypes,

        const Self = @This();

        /// Matches patterns in sequence.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        ///
        /// Postconditions:
        /// - If any pattern fails to match, returns Match with 0 bytes consumed
        /// - If all patterns match, returns Match with total bytes consumed and groups[0] = entire matched string
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        /// - returned Match.groups references input memory
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match {
            var total_consumed: usize = 0;
            var current_input = input;

            // Use comptime to iterate over tuple fields
            inline for (@typeInfo(PatternTypes).@"struct".fields) |field| {
                const pattern = @field(self.patterns, field.name);
                const pattern_match = pattern.match(current_input);

                if (pattern_match.bytes_consumed == 0) {
                    // Pattern failed to match
                    const empty_groups: []const []const u8 = &[_][]const u8{};
                    const result = Match.init(0, empty_groups);

                    // Postconditions
                    defer assert(result.bytes_consumed == 0);
                    defer assert(result.groups.len == 0);

                    return result;
                }

                total_consumed += pattern_match.bytes_consumed;
                current_input = current_input[pattern_match.bytes_consumed..];
            }

            // All patterns matched successfully
            const matched = input[0..total_consumed];
            const groups = &[_][]const u8{matched};
            const result = Match.init(total_consumed, groups);

            // Postconditions
            defer assert(result.bytes_consumed == total_consumed);
            defer assert(result.groups.len == 1);
            defer assert(result.groups[0].len == total_consumed);

            return result;
        }
    };
}

test "Pattern: wildcard variant" {
    const pattern = Pattern{ .wildcard = Wildcard{} };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqualStrings("h", result.groups[0]);
}

test "Pattern: character variant matching" {
    const pattern = Pattern{ .character = Character{ .character = 'h' } };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqualStrings("h", result.groups[0]);
}

test "Pattern: character variant not matching" {
    const pattern = Pattern{ .character = Character{ .character = 'x' } };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
}

test "Pattern: character class variant" {
    const pattern = Pattern{ .character_class_3 = CharacterClass(3){ .characters = .{ 'a', 'e', 'i' } } };

    const input1 = "apple";
    const result1 = pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", result1.groups[0]);

    const input2 = "banana";
    const result2 = pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "Concatenation: match empty input" {
    const concat = Concatenation(struct { Character, Character }){
        .patterns = .{
            Character{ .character = 'a' },
            Character{ .character = 'b' },
        },
    };
    const input = "";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Concatenation: match two characters" {
    const concat = Concatenation(struct { Character, Character }){
        .patterns = .{
            Character{ .character = 'a' },
            Character{ .character = 'b' },
        },
    };
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("ab", result.groups[0]);
}

test "Concatenation: partial match fails" {
    const concat = Concatenation(struct { Character, Character, Character }){
        .patterns = .{
            Character{ .character = 'a' },
            Character{ .character = 'b' },
            Character{ .character = 'c' },
        },
    };
    const input = "abx";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Concatenation: mixed pattern types" {
    const concat = Concatenation(struct { Character, Wildcard, CharacterClass(3) }){
        .patterns = .{
            Character{ .character = 'h' },
            Wildcard{},
            CharacterClass(3){ .characters = .{ 'l', 'm', 'n' } },
        },
    };
    const input = "hello";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("hel", result.groups[0]);
}

test "Concatenation: first pattern fails" {
    const concat = Concatenation(struct { Character, Character }){
        .patterns = .{
            Character{ .character = 'x' },
            Character{ .character = 'b' },
        },
    };
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Concatenation: insufficient input" {
    const concat = Concatenation(struct { Character, Character, Character, Character }){
        .patterns = .{
            Character{ .character = 'a' },
            Character{ .character = 'b' },
            Character{ .character = 'c' },
            Character{ .character = 'd' },
        },
    };
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Pattern: concatenation variant" {
    const pattern = Pattern{
        .concatenation_2_char = Concatenation(struct { Character, Character }){
            .patterns = .{
                Character{ .character = 'h' },
                Character{ .character = 'i' },
            },
        },
    };
    const input = "hi there";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqualStrings("hi", result.groups[0]);
}

test "fuzz: Wildcard never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const wildcard = Wildcard{};
            const result = wildcard.match(input);
            // Wildcard should never panic and should consume 0 or 1 bytes
            try std.testing.expect(result.bytes_consumed <= 1);
            if (result.bytes_consumed == 0) {
                try std.testing.expectEqual(@as(usize, 0), result.groups.len);
            } else {
                try std.testing.expectEqual(@as(usize, 1), result.groups.len);
                try std.testing.expectEqual(@as(usize, 1), result.groups[0].len);
            }
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

test "fuzz: Character never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const char = Character{ .character = 'a' };
            const result = char.match(input);
            // Character should never panic and should consume 0 or 1 bytes
            try std.testing.expect(result.bytes_consumed <= 1);
            if (result.bytes_consumed == 0) {
                try std.testing.expectEqual(@as(usize, 0), result.groups.len);
            } else {
                try std.testing.expectEqual(@as(usize, 1), result.groups.len);
                try std.testing.expectEqual(@as(usize, 1), result.groups[0].len);
                try std.testing.expectEqualStrings("a", result.groups[0]);
            }
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

test "fuzz: CharacterClass never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const class = CharacterClass(3){ .characters = .{ 'a', 'b', 'c' } };
            const result = class.match(input);
            // CharacterClass should never panic and should consume 0 or 1 bytes
            try std.testing.expect(result.bytes_consumed <= 1);
            if (result.bytes_consumed == 0) {
                try std.testing.expectEqual(@as(usize, 0), result.groups.len);
            } else {
                try std.testing.expectEqual(@as(usize, 1), result.groups.len);
                try std.testing.expectEqual(@as(usize, 1), result.groups[0].len);
            }
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

test "fuzz: Concatenation never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const concat = Concatenation(struct { Character, Character, Character }){
                .patterns = .{
                    Character{ .character = 'a' },
                    Character{ .character = 'b' },
                    Character{ .character = 'c' },
                },
            };
            const result = concat.match(input);
            // Concatenation should never panic and should consume 0 or 3 bytes
            try std.testing.expect(result.bytes_consumed == 0 or result.bytes_consumed == 3);
            if (result.bytes_consumed == 0) {
                try std.testing.expectEqual(@as(usize, 0), result.groups.len);
            } else {
                try std.testing.expectEqual(@as(usize, 1), result.groups.len);
                try std.testing.expectEqual(@as(usize, 3), result.groups[0].len);
                try std.testing.expectEqualStrings("abc", result.groups[0]);
            }
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

test "fuzz: Pattern union never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Test wildcard variant
            const pattern1 = Pattern{ .wildcard = Wildcard{} };
            const result1 = pattern1.match(input);
            try std.testing.expect(result1.bytes_consumed <= input.len);

            // Test character variant
            const pattern2 = Pattern{ .character = Character{ .character = 'x' } };
            const result2 = pattern2.match(input);
            try std.testing.expect(result2.bytes_consumed <= input.len);

            // Test character class variant
            const pattern3 = Pattern{ .character_class_3 = CharacterClass(3){ .characters = .{ 'a', 'b', 'c' } } };
            const result3 = pattern3.match(input);
            try std.testing.expect(result3.bytes_consumed <= input.len);

            // Test concatenation variant
            const pattern4 = Pattern{
                .concatenation_2_char = Concatenation(struct { Character, Character }){
                    .patterns = .{
                        Character{ .character = 'a' },
                        Character{ .character = 'b' },
                    },
                },
            };
            const result4 = pattern4.match(input);
            try std.testing.expect(result4.bytes_consumed <= input.len);
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

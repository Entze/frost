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
    /// Number of bytes consumed from the input string.
    /// Zero indicates no match or empty input.
    bytes_consumed: usize,

    /// Matched groups. All groups > 0 are a substring of group 0.
    /// Empty slice indicates no match.
    groups: []const []const u8,

    const Self = @This();

    /// Empty match constant for cases where no match occurred.
    /// Similar to ArrayListAligned.empty.
    pub const empty: Self = .{
        .bytes_consumed = 0,
        .groups = &[_][]const u8{},
    };

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
            const result = Match.empty;

            // Postconditions
            defer assert(result.bytes_consumed == 0);
            defer assert(result.groups.len == 0);

            return result;
        }

        if (input[0] != self.character) {
            // Character doesn't match
            const result = Match.empty;

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
///
/// Helper function to create CharacterClass with inferred size:
/// ```
/// const vowels = characterClass("aeiou");
/// ```
pub fn characterClass(comptime characters: []const u8) CharacterClass(characters.len) {
    var result: CharacterClass(characters.len) = undefined;
    result.count = characters.len;
    for (characters, 0..) |c, i| {
        result.characters[i] = c;
    }
    return result;
}

pub fn CharacterClass(comptime size: usize) type {
    return struct {
        characters: [size]u8,
        count: usize,

        const Self = @This();

        /// Creates a CharacterClass from a compile-time character slice.
        /// The storage size must be >= slice length.
        ///
        /// Note: It's easier to use the module-level `characterClass()` function
        /// which infers the size automatically.
        ///
        /// Example:
        /// ```
        /// const cc = CharacterClass(10).init("aei"); // Uses 3 of 10 slots
        /// const digits = CharacterClass(10).init("0123456789"); // Uses all 10 slots
        /// ```
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
            assert(self.count > 0);
            assert(self.count <= size);

            if (input.len == 0) {
                // No input to match
                const result = Match.empty;

                // Postconditions
                defer assert(result.bytes_consumed == 0);
                defer assert(result.groups.len == 0);

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
            const result = Match.empty;

            // Postconditions
            defer assert(result.bytes_consumed == 0);
            defer assert(result.groups.len == 0);

            return result;
        }
    };
}

test "CharacterClass: match empty input" {
    const class = CharacterClass(3).init("abc");
    const input = "";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "CharacterClass: match first character in set" {
    const class = CharacterClass(3).init("abc");
    const input = "apple";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("a", result.groups[0]);
}

test "CharacterClass: match middle character in set" {
    const class = CharacterClass(3).init("abc");
    const input = "banana";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("b", result.groups[0]);
}

test "CharacterClass: match last character in set" {
    const class = CharacterClass(3).init("abc");
    const input = "cat";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("c", result.groups[0]);
}

test "CharacterClass: no match for character not in set" {
    const class = CharacterClass(3).init("abc");
    const input = "dog";
    const result = class.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "CharacterClass: match digits" {
    const class = CharacterClass(10).init("0123456789");

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
    const class = CharacterClass(1).init("x");
    const input1 = "xyz";
    const result1 = class.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("x", result1.groups[0]);

    const input2 = "abc";
    const result2 = class.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "CharacterClass: init helper with size inference" {
    const vowels = CharacterClass(5).init("aeiou");
    const input1 = "apple";
    const result1 = vowels.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", result1.groups[0]);

    const input2 = "banana";
    const result2 = vowels.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "CharacterClass: characterClass helper with automatic size inference" {
    const vowels = characterClass("aeiou");
    const input1 = "apple";
    const result1 = vowels.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", result1.groups[0]);

    const digits = characterClass("0123456789");
    const input2 = "42";
    const result2 = digits.match(input2);
    try std.testing.expectEqual(@as(usize, 1), result2.bytes_consumed);
    try std.testing.expectEqualStrings("4", result2.groups[0]);
}

/// Pattern tagged union containing all pattern variants.
///
/// This is the main abstraction for pattern matching. It delegates matching
/// behavior to its variants.
///
/// The size parameter determines:
/// - Maximum size of CharacterClass character sets
/// - Maximum number of patterns in Concatenation sequences
///
/// Example:
/// ```
/// const P = Pattern(10); // Supports CharacterClass up to 10 chars, Concatenation up to 10 patterns
/// const pattern = P{ .character_class = characterClass("0123456789") };
/// ```
pub fn Pattern(comptime max_size: usize) type {
    return union(enum) {
        wildcard: Wildcard,
        character: Character,
        character_class: CharacterClass(max_size),
        concatenation: Concatenation(max_size),

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
                .character_class => |cc| cc.match(input),
                .concatenation => |cat| cat.match(input),
            };
        }
    };
}

/// Helper function to create Concatenation with inferred size.
/// The max_size is determined by the patterns slice length.
///
/// Example:
/// ```
/// const P = Pattern(10);
/// const concat = concatenation(&[_]P{
///     P{ .character = Character{ .character = 'h' } },
///     P{ .character = Character{ .character = 'i' } },
/// });
/// ```
pub fn concatenation(comptime patterns: anytype) Concatenation(patterns.len) {
    return Concatenation(patterns.len).init(patterns);
}

/// Concatenation pattern that matches sequential patterns.
///
/// Since patterns are defined at compile time, uses an array with a compile-time count.
/// The max_size parameter determines the maximum number of patterns that can be stored.
/// Uses pointers to avoid circular dependency with Pattern.
pub fn Concatenation(comptime max_size: usize) type {
    return struct {
        patterns: [max_size]*const Pattern(max_size),
        count: usize,

        const Self = @This();

        /// Creates a Concatenation from a pattern slice.
        /// The count is taken from the slice length.
        ///
        /// Preconditions:
        /// - patterns.len <= max_size
        /// - patterns.len > 0
        ///
        /// Example:
        /// ```
        /// const P = Pattern(10);
        /// const p1 = P{ .character = Character{ .character = 'a' } };
        /// const p2 = P{ .character = Character{ .character = 'b' } };
        /// const patterns = [_]*const P{ &p1, &p2 };
        /// const concat = Concatenation(10).init(&patterns);
        /// ```
        pub fn init(patterns: []const *const Pattern(max_size)) Self {
            assert(patterns.len <= max_size);
            assert(patterns.len > 0);
            var result: Self = undefined;
            result.count = patterns.len;
            // Initialize used pattern slots
            for (patterns, 0..) |pattern, i| {
                result.patterns[i] = pattern;
            }
            // Remaining slots don't need initialization since we use count
            return result;
        }

        /// Matches patterns in sequence.
        ///
        /// Preconditions:
        /// - input must be valid UTF-8 slice
        /// - count <= max_size
        /// - count > 0
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
            // Preconditions
            assert(self.count <= max_size);
            assert(self.count > 0);

            var total_consumed: usize = 0;
            var current_input = input;

            // Loop has determinable upper bound: self.count (compile-time validated <= max_size)
            var i: usize = 0;
            while (i < self.count) : (i += 1) {
                // Loop invariant: i < self.count
                assert(i < self.count);

                const pattern_match = self.patterns[i].match(current_input);

                if (pattern_match.bytes_consumed == 0) {
                    // Pattern failed to match
                    const result = Match.empty;

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
    const P = Pattern(10);
    const pattern = P{ .wildcard = Wildcard{} };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqualStrings("h", result.groups[0]);
}

test "Pattern: character variant matching" {
    const P = Pattern(10);
    const pattern = P{ .character = Character{ .character = 'h' } };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 1), result.bytes_consumed);
    try std.testing.expectEqualStrings("h", result.groups[0]);
}

test "Pattern: character variant not matching" {
    const P = Pattern(10);
    const pattern = P{ .character = Character{ .character = 'x' } };
    const input = "hello";
    const result = pattern.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
}

test "Pattern: character class variant" {
    const P = Pattern(10);
    const cc = CharacterClass(10).init("aei");
    const pattern = P{ .character_class = cc };

    const input1 = "apple";
    const result1 = pattern.match(input1);
    try std.testing.expectEqual(@as(usize, 1), result1.bytes_consumed);
    try std.testing.expectEqualStrings("a", result1.groups[0]);

    const input2 = "banana";
    const result2 = pattern.match(input2);
    try std.testing.expectEqual(@as(usize, 0), result2.bytes_consumed);
}

test "Concatenation: match empty input" {
    const P = Pattern(10);
    const p1 = P{ .character = Character{ .character = 'a' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Concatenation: match two characters" {
    const P = Pattern(10);
    const p1 = P{ .character = Character{ .character = 'a' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("ab", result.groups[0]);
}

test "Concatenation: partial match fails" {
    const P = Pattern(10);
    const p1 = P{ .character = Character{ .character = 'a' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
    const p3 = P{ .character = Character{ .character = 'c' } };
    const patterns = [_]*const P{ &p1, &p2, &p3 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abx";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Concatenation: mixed pattern types" {
    const P = Pattern(10);
    const p1 = P{ .character = Character{ .character = 'h' } };
    const p2 = P{ .wildcard = Wildcard{} };
    const cc = CharacterClass(10).init("lmn");
    const p3 = P{ .character_class = cc };
    const patterns = [_]*const P{ &p1, &p2, &p3 };
    const concat = Concatenation(10).init(&patterns);
    const input = "hello";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups.len);
    try std.testing.expectEqualStrings("hel", result.groups[0]);
}

test "Concatenation: first pattern fails" {
    const P = Pattern(10);
    const p1 = P{ .character = Character{ .character = 'x' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Concatenation: insufficient input" {
    const P = Pattern(10);
    const p1 = P{ .character = Character{ .character = 'a' } };
    const p2 = P{ .character = Character{ .character = 'b' } };
    const p3 = P{ .character = Character{ .character = 'c' } };
    const p4 = P{ .character = Character{ .character = 'd' } };
    const patterns = [_]*const P{ &p1, &p2, &p3, &p4 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups.len);
}

test "Pattern: concatenation variant" {
    const P = Pattern(10);
    const p1 = P{ .character = Character{ .character = 'h' } };
    const p2 = P{ .character = Character{ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const pattern = P{ .concatenation = concat };
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
            const class = CharacterClass(3).init("abc");
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
            const P = Pattern(10);
            const p1 = P{ .character = Character{ .character = 'a' } };
            const p2 = P{ .character = Character{ .character = 'b' } };
            const p3 = P{ .character = Character{ .character = 'c' } };
            const patterns = [_]*const P{ &p1, &p2, &p3 };
            const concat = Concatenation(10).init(&patterns);
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
            const P = Pattern(10);
            // Test wildcard variant
            const pattern1 = P{ .wildcard = Wildcard{} };
            const result1 = pattern1.match(input);
            try std.testing.expect(result1.bytes_consumed <= input.len);

            // Test character variant
            const pattern2 = P{ .character = Character{ .character = 'x' } };
            const result2 = pattern2.match(input);
            try std.testing.expect(result2.bytes_consumed <= input.len);

            // Test character class variant
            const cc = CharacterClass(10).init("abc");
            const pattern3 = P{ .character_class = cc };
            const result3 = pattern3.match(input);
            try std.testing.expect(result3.bytes_consumed <= input.len);

            // Test concatenation variant
            const p1 = P{ .character = Character{ .character = 'a' } };
            const p2 = P{ .character = Character{ .character = 'b' } };
            const patterns = [_]*const P{ &p1, &p2 };
            const concat = Concatenation(10).init(&patterns);
            const pattern4 = P{ .concatenation = concat };
            const result4 = pattern4.match(input);
            try std.testing.expect(result4.bytes_consumed <= input.len);
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

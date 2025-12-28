//! Concatenation pattern that matches sequential patterns.

const std = @import("std");
const assert = std.debug.assert;
const MatchGroup = @import("match_group.zig").MatchGroup;
const Match = @import("match.zig").Match;

// Note: Pattern is imported from parent, creating a circular dependency
// This is intentional and necessary: Pattern contains Concatenation,
// and Concatenation contains pointers to Pattern
const Pattern = @import("../pattern.zig").Pattern;

/// Helper function to extract max_size from Pattern type at compile time.
/// Used by concatenation() to ensure type compatibility.
fn extractPatternMaxSize(comptime patterns_type: type) usize {
    const array_info = @typeInfo(patterns_type);
    const pattern_ptr_type = array_info.array.child;
    const PatternType = @typeInfo(pattern_ptr_type).pointer.child;
    
    // Pattern must be a union type
    const union_info = @typeInfo(PatternType).@"union";
    assert(union_info.fields.len > 0); // Pattern union must have at least one variant
    
    // Extract max_size from Pattern(max_size) via Match type
    // All Pattern variants have a match method that returns Match(max_size)
    const first_field_type = union_info.fields[0].type;
    const match_return_type = @typeInfo(@TypeOf(first_field_type.match)).@"fn".return_type.?;
    const match_struct_info = @typeInfo(match_return_type).@"struct";
    
    // Find groups field in Match struct and extract array length (which is max_size)
    inline for (match_struct_info.fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "groups")) {
            const field_type_info = @typeInfo(field.type);
            if (field_type_info == .array) {
                return field_type_info.array.len;
            }
        }
    }
    
    @compileError("Unable to extract max_size from Pattern type: groups field not found");
}

/// Helper function to create Concatenation with inferred size.
/// The max_size is extracted from the Pattern type to ensure type compatibility.
/// This corrects the previous implementation which used patterns.len.
pub fn concatenation(comptime patterns: anytype) Concatenation(extractPatternMaxSize(@TypeOf(patterns.*))) {
    const max_size = comptime extractPatternMaxSize(@TypeOf(patterns.*));
    return Concatenation(max_size).init(patterns);
}

test "Concatenation.init: should match sequential patterns" {
    // Expected: Match "hi" from "hi there"
    const expected_bytes: usize = 2;
    const expected_groups: usize = 1;
    const expected_match = "hi";

    // Actual: Create and use Concatenation.init (note: concatenation helper has limitations)
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'h' } };
    const p2 = P{ .character = Character(10){ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "hi there";
    const result = concat.match(input);
    const actual_match = input[result.groups[0].begin..result.groups[0].end];

    // Verify expectations
    try std.testing.expectEqual(expected_bytes, result.bytes_consumed);
    try std.testing.expectEqual(expected_groups, result.groups_matched);
    try std.testing.expectEqualStrings(expected_match, actual_match);
}

/// Concatenation pattern that matches sequential patterns.
///
/// Since patterns are defined at compile time, uses an array with a compile-time count.
/// The max_size parameter determines the maximum number of patterns that can be stored.
/// Uses pointers to Pattern to handle the circular dependency between Pattern and Concatenation.
pub fn Concatenation(comptime max_size: usize) type {
    return struct {
        patterns: [max_size]*const Pattern(max_size),
        count: usize,

        const Self = @This();

        /// Number of groups this pattern produces (always 1: the full match).
        pub const groups_count = 1;

        /// Creates a Concatenation from a pattern slice.
        /// The count is taken from the slice length.
        ///
        /// Preconditions:
        /// - patterns.len <= max_size
        /// - patterns.len > 0
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

        test init {
            const P = Pattern(10);
            const Character = @import("character.zig").Character;
            const p1 = P{ .character = Character(10){ .character = 'a' } };
            const p2 = P{ .character = Character(10){ .character = 'b' } };
            const patterns = [_]*const P{ &p1, &p2 };
            const concat = Concatenation(10).init(&patterns);

            try std.testing.expectEqual(@as(usize, 2), concat.count);

            const input = "abc";
            const result = concat.match(input);
            try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
            try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
            try std.testing.expectEqualStrings("ab", input[result.groups[0].begin..result.groups[0].end]);
        }

        test "init: should create Concatenation and match pattern sequence" {
            // Expected: Create Concatenation matching "ab" in "abc"
            const expected_count: usize = 2;
            const expected_bytes: usize = 2;
            const expected_groups: usize = 1;
            const expected_match = "ab";

            // Actual: Create and use Concatenation.init
            const P = Pattern(10);
            const Character = @import("character.zig").Character;
            const p1 = P{ .character = Character(10){ .character = 'a' } };
            const p2 = P{ .character = Character(10){ .character = 'b' } };
            const patterns = [_]*const P{ &p1, &p2 };
            const concat = Concatenation(10).init(&patterns);
            const input = "abc";
            const result = concat.match(input);
            const actual_match = input[result.groups[0].begin..result.groups[0].end];

            // Verify expectations
            try std.testing.expectEqual(expected_count, concat.count);
            try std.testing.expectEqual(expected_bytes, result.bytes_consumed);
            try std.testing.expectEqual(expected_groups, result.groups_matched);
            try std.testing.expectEqualStrings(expected_match, actual_match);
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
        /// - If all patterns match, returns Match with total bytes consumed and 1 group (the full match)
        ///
        /// Ownership:
        /// - input slice is borrowed, not owned
        ///
        /// Lifetime:
        /// - input must remain valid for lifetime of returned Match
        pub fn match(self: Self, input: []const u8) Match(max_size) {
            // Preconditions
            assert(self.count <= max_size);
            assert(self.count > 0);

            var total_consumed: usize = 0;
            var current_input = input;
            var total_groups: usize = 1; // Start with 1 for group 0 (full match)
            var all_groups = [_]MatchGroup{MatchGroup{ .begin = 0, .end = 0 }} ** max_size;

            // Loop has determinable upper bound: self.count (compile-time validated <= max_size)
            var i: usize = 0;
            while (i < self.count) : (i += 1) {
                // Loop invariant: i < self.count
                assert(i < self.count);

                const pattern_match = self.patterns[i].match(current_input);

                if (pattern_match.bytes_consumed == 0) {
                    // Pattern failed to match
                    const result = Match(max_size).empty;

                    // Postconditions
                    defer assert(result.bytes_consumed == 0);
                    defer assert(result.groups_matched == 0);

                    return result;
                }

                // Collect capture groups from this subpattern (skip group 0 which is the subpattern's full match)
                var j: usize = 1;
                while (j < pattern_match.groups_matched) : (j += 1) {
                    assert(j < pattern_match.groups_matched);
                    assert(total_groups < max_size);

                    // Adjust group positions relative to concatenation start
                    const group = pattern_match.groups[j];
                    all_groups[total_groups] = MatchGroup.init(group.begin + total_consumed, group.end + total_consumed);
                    total_groups += 1;
                }

                total_consumed += pattern_match.bytes_consumed;
                current_input = current_input[pattern_match.bytes_consumed..];
            }

            // All patterns matched successfully
            // Group 0 is the full concatenation match
            all_groups[0] = MatchGroup.init(0, total_consumed);
            const result = Match(max_size).init(total_consumed, total_groups, all_groups);

            // Postconditions
            defer assert(result.bytes_consumed == total_consumed);
            defer assert(result.groups_matched == total_groups);
            defer assert(result.groups[0].len() == total_consumed);

            return result;
        }
    };
}

test "Concatenation: match empty input" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'a' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Concatenation: match two characters" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'a' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("ab", input[result.groups[0].begin..result.groups[0].end]);
}

test "Concatenation: partial match fails" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'a' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const p3 = P{ .character = Character(10){ .character = 'c' } };
    const patterns = [_]*const P{ &p1, &p2, &p3 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abx";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Concatenation: mixed pattern types" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const Wildcard = @import("wildcard.zig").Wildcard;
    const CharacterClass = @import("character_class.zig").CharacterClass;
    const p1 = P{ .character = Character(10){ .character = 'h' } };
    const p2 = P{ .wildcard = Wildcard(10){} };
    const cc = CharacterClass(10).init("lmn");
    const p3 = P{ .character_class = cc };
    const patterns = [_]*const P{ &p1, &p2, &p3 };
    const concat = Concatenation(10).init(&patterns);
    const input = "hello";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("hel", input[result.groups[0].begin..result.groups[0].end]);
}

test "Concatenation: first pattern fails" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'x' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "Concatenation: insufficient input" {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'a' } };
    const p2 = P{ .character = Character(10){ .character = 'b' } };
    const p3 = P{ .character = Character(10){ .character = 'c' } };
    const p4 = P{ .character = Character(10){ .character = 'd' } };
    const patterns = [_]*const P{ &p1, &p2, &p3, &p4 };
    const concat = Concatenation(10).init(&patterns);
    const input = "abc";
    const result = concat.match(input);

    try std.testing.expectEqual(@as(usize, 0), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
}

test "fuzz: Concatenation never panics" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            const P = Pattern(10);
            const Character = @import("character.zig").Character;
            const p1 = P{ .character = Character(10){ .character = 'a' } };
            const p2 = P{ .character = Character(10){ .character = 'b' } };
            const p3 = P{ .character = Character(10){ .character = 'c' } };
            const patterns = [_]*const P{ &p1, &p2, &p3 };
            const concat = Concatenation(10).init(&patterns);
            const result = concat.match(input);
            // Concatenation should never panic and should consume 0 or 3 bytes
            try std.testing.expect(result.bytes_consumed == 0 or result.bytes_consumed == 3);
            if (result.bytes_consumed == 0) {
                try std.testing.expectEqual(@as(usize, 0), result.groups_matched);
            } else {
                try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
                try std.testing.expectEqual(@as(usize, 3), result.groups[0].len());
                try std.testing.expectEqualStrings("abc", input[result.groups[0].begin..result.groups[0].end]);
            }
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

test concatenation {
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const p1 = P{ .character = Character(10){ .character = 'h' } };
    const p2 = P{ .character = Character(10){ .character = 'i' } };
    const patterns = [_]*const P{ &p1, &p2 };
    const concat = Concatenation(10).init(&patterns);

    const input = "hi there";
    const result = concat.match(input);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.groups_matched);
    try std.testing.expectEqualStrings("hi", input[result.groups[0].begin..result.groups[0].end]);
}

test "concatenation: abc - convenience vs init produces identical pattern" {
    // This tests the case: "abc" - concatenation of 3 character patterns
    // Expected: 1 group total (the concatenation itself)
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const pa = P{ .character = Character(10){ .character = 'a' } };
    const pb = P{ .character = Character(10){ .character = 'b' } };
    const pc = P{ .character = Character(10){ .character = 'c' } };
    
    // Create using init
    const patterns_init = [_]*const P{ &pa, &pb, &pc };
    const concat_init = Concatenation(10).init(&patterns_init);
    
    // Create using convenience constructor
    const patterns_conv = [_]*const P{ &pa, &pb, &pc };
    const concat_conv = concatenation(&patterns_conv);
    
    // Test matching with both
    const input = "abc";
    const result_init = concat_init.match(input);
    const result_conv = concat_conv.match(input);
    
    // Both should produce identical results
    try std.testing.expectEqual(result_init.bytes_consumed, result_conv.bytes_consumed);
    try std.testing.expectEqual(result_init.groups_matched, result_conv.groups_matched);
    try std.testing.expectEqual(@as(usize, 3), result_init.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result_init.groups_matched);
}

test "concatenation: (abc) - wrapping concatenation in group" {
    // This tests the case: "(abc)" - group wrapping concatenation of 3 characters
    // Expected: 2 groups total: "(abc)" and "abc"
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const Group = @import("group.zig").Group;
    const pa = P{ .character = Character(10){ .character = 'a' } };
    const pb = P{ .character = Character(10){ .character = 'b' } };
    const pc = P{ .character = Character(10){ .character = 'c' } };
    
    // Create inner concatenation "abc"
    const abc_patterns = [_]*const P{ &pa, &pb, &pc };
    const abc_concat = P{ .concatenation = Concatenation(10).init(&abc_patterns) };
    const group = Group(10){ .pattern = &abc_concat };
    
    // Test matching
    const input = "abc";
    const result = group.match(input);
    
    // Verify expected results
    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 2), result.groups_matched);
}

test "concatenation: (abc)(xyz) - two groups in concatenation" {
    // This tests the case: "(abc)(xyz)" - concatenation of 2 groups
    // Expected: 3 groups total: "(abc)(xyz)", "abc", and "xyz"
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const Group = @import("group.zig").Group;
    
    // Build "abc" concatenation
    const pa = P{ .character = Character(10){ .character = 'a' } };
    const pb = P{ .character = Character(10){ .character = 'b' } };
    const pc = P{ .character = Character(10){ .character = 'c' } };
    const abc_patterns = [_]*const P{ &pa, &pb, &pc };
    const abc_concat = P{ .concatenation = Concatenation(10).init(&abc_patterns) };
    
    // Wrap in group: (abc)
    const group1 = P{ .group = Group(10){ .pattern = &abc_concat } };
    
    // Build "xyz" concatenation
    const px = P{ .character = Character(10){ .character = 'x' } };
    const py = P{ .character = Character(10){ .character = 'y' } };
    const pz = P{ .character = Character(10){ .character = 'z' } };
    const xyz_patterns = [_]*const P{ &px, &py, &pz };
    const xyz_concat = P{ .concatenation = Concatenation(10).init(&xyz_patterns) };
    
    // Wrap in group: (xyz)
    const group2 = P{ .group = Group(10){ .pattern = &xyz_concat } };
    
    // Create outer concatenation
    const outer_patterns = [_]*const P{ &group1, &group2 };
    const concat = Concatenation(10).init(&outer_patterns);
    
    // Test matching
    const input = "abcxyz";
    const result = concat.match(input);
    
    // Verify expected results
    try std.testing.expectEqual(@as(usize, 6), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.groups_matched);
}

test "concatenation: (a(b))c - nested groups in concatenation" {
    // This tests the case: "(a(b))c" - nested groups in concatenation
    // Expected: 3 groups total: "(a(b))c", "a(b)", "b"
    const P = Pattern(10);
    const Character = @import("character.zig").Character;
    const Group = @import("group.zig").Group;
    
    // Build innermost: "b"
    const pb = P{ .character = Character(10){ .character = 'b' } };
    
    // Wrap in inner group: (b)
    const inner_group = P{ .group = Group(10){ .pattern = &pb } };
    
    // Build "a" and "(b)" concatenation
    const pa = P{ .character = Character(10){ .character = 'a' } };
    const ab_patterns = [_]*const P{ &pa, &inner_group };
    const ab_concat = P{ .concatenation = Concatenation(10).init(&ab_patterns) };
    
    // Wrap in outer group: (a(b))
    const outer_group = P{ .group = Group(10){ .pattern = &ab_concat } };
    
    // Build final concatenation with "c"
    const pc = P{ .character = Character(10){ .character = 'c' } };
    const final_patterns = [_]*const P{ &outer_group, &pc };
    const concat = Concatenation(10).init(&final_patterns);
    
    // Test matching
    const input = "abc";
    const result = concat.match(input);
    
    // Verify expected results
    try std.testing.expectEqual(@as(usize, 3), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 3), result.groups_matched);
}

//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Error set for CNF program operations.
/// - LiteralOutOfBounds: A literal's absolute value exceeds the variable count.
/// - ClauseOutOfBounds: Attempting to add a literal when all clauses have been filled.
pub const CnfProgramError = error{
    LiteralOutOfBounds,
    ClauseOutOfBounds,
};

/// Error set for add_literal operation combining bounds checking and allocation errors.
pub const AddLiteralError = CnfProgramError || Allocator.Error;

/// Represents a CNF (Conjunctive Normal Form) program.
///
/// A CNF program is a conjunction of clauses, where each clause is a disjunction of literals.
/// Literals are represented as non-zero i32 values where the sign indicates negation.
/// Literal 0 is used as a clause terminator during construction.
///
/// Example usage:
/// ```
/// const std = @import("std");
/// const allocator = std.testing.allocator;
///
/// var program = try CnfProgram.init(allocator, 3, 2);
/// defer program.deinit();
///
/// try program.add_literal(1);   // Add literal 1 to first clause
/// try program.add_literal(-2);  // Add literal -2 to first clause
/// try program.add_literal(0);   // Terminate first clause
/// try program.add_literal(3);   // Add literal 3 to second clause
/// try program.add_literal(0);   // Terminate second clause
/// ```
pub const CnfProgram = struct {
    allocator: Allocator,
    variable_count: u31,
    clause_count: u128,
    clauses: []std.ArrayListAligned(i32, null),
    clause_active_index: u128,

    const Self = @This();

    /// Initializes a new CNF program with the specified variable and clause counts.
    ///
    /// Preconditions:
    /// - allocator must be valid
    /// - if (variable_count > 0) then clause_count > 0
    /// - if (clause_count > 0) then variable_count > 0
    /// - log2(clause_count) <= variable_count (there are only 2^variable_count possible clauses)
    ///
    /// Postconditions:
    /// - Returns initialized CnfProgram with empty clauses
    /// - All clauses are allocated and have length 0
    /// - clause_active_index is set to 0
    /// - Caller owns returned memory and must call deinit()
    ///
    /// Ownership:
    /// - Returned CnfProgram owns all allocated memory
    ///
    /// Lifetime:
    /// - Valid until deinit() is called
    pub fn init(allocator: Allocator, variable_count: u31, clause_count: u128) Allocator.Error!Self {
        // Preconditions
        if (variable_count > 0) assert(clause_count > 0);
        if (clause_count > 0) assert(variable_count > 0);
        assert(std.math.log2(clause_count) <= variable_count);

        // Check if clause_count fits in usize - if not, we can't allocate that many anyway
        if (clause_count > std.math.maxInt(usize)) {
            return error.OutOfMemory;
        }

        const clause_count_usize = @as(usize, @intCast(clause_count));
        const clauses = try allocator.alloc(std.ArrayListAligned(i32, null), clause_count_usize);
        errdefer allocator.free(clauses);

        // Initialize all clauses as empty - .empty doesn't allocate so no cleanup needed
        for (clauses) |*clause| {
            clause.* = .empty;
        }

        const result = Self{
            .allocator = allocator,
            .variable_count = variable_count,
            .clause_count = clause_count,
            .clauses = clauses,
            .clause_active_index = 0,
        };

        // Postconditions
        defer assert(result.clauses.len == clause_count_usize);
        defer assert(result.clause_active_index == 0);
        defer {
            for (result.clauses) |clause| {
                assert(clause.items.len == 0);
            }
        }

        return result;
    }

    /// Releases all memory allocated by the CNF program.
    ///
    /// Preconditions:
    /// - self must be initialized (init() was called successfully)
    /// - self must not have been deinitialized already
    ///
    /// Postconditions:
    /// - All memory is freed
    /// - self is poisoned with undefined values
    pub fn deinit(self: *Self) void {
        // Preconditions
        const clause_count_usize = @as(usize, @intCast(self.clause_count));
        assert(self.clauses.len == clause_count_usize);

        // Deinitialize all clauses
        for (self.clauses) |*clause| {
            clause.deinit(self.allocator);
        }

        self.allocator.free(self.clauses);

        // Poison memory
        self.* = undefined;

        // Postcondition: Note - cannot assert self.* == undefined in Zig
        // as comparison with undefined is not possible
    }

    /// Adds a literal to the active clause or terminates the current clause.
    ///
    /// When literal is 0, the current clause is terminated and the next clause becomes active.
    /// Non-zero literals are appended to the active clause after bounds validation.
    ///
    /// Preconditions:
    /// - self must be initialized
    ///
    /// Postconditions:
    /// - clause_active_index <= clause_count
    /// - if (literal == 0 and no error) then clause_old_index + 1 == clause_active_index
    /// - if (literal != 0 and no error) then clause_active_old_len + 1 == clauses[clause_active_index].len
    ///
    /// Returns:
    /// - AddLiteralError if bounds are violated or allocation fails
    pub fn add_literal(self: *Self, literal: i32) AddLiteralError!void {
        // Preconditions
        const clause_count_usize = @as(usize, @intCast(self.clause_count));
        assert(self.clauses.len == clause_count_usize);

        // Save old values for postconditions
        const clause_old_index = self.clause_active_index;

        // Postconditions
        defer assert(self.clause_active_index <= self.clause_count);

        if (literal == 0) {
            // Terminate current clause and move to next
            if (self.clause_active_index >= self.clause_count) {
                return CnfProgramError.ClauseOutOfBounds;
            }
            self.clause_active_index += 1;
            defer assert(clause_old_index + 1 == self.clause_active_index);
        } else {
            // Validate literal is in bounds - use i64 cast to safely handle minInt
            const abs_literal = @abs(@as(i64, literal));
            if (abs_literal > self.variable_count) {
                return CnfProgramError.LiteralOutOfBounds;
            }

            // Check active clause is valid
            if (self.clause_active_index >= self.clause_count) {
                return CnfProgramError.ClauseOutOfBounds;
            }

            // Compute index and save old length after validation
            const active_index = @as(usize, @intCast(self.clause_active_index));
            const clause_active_old_len = self.clauses[active_index].items.len;

            // Append to active clause
            try self.clauses[active_index].append(self.allocator, literal);
            defer assert(clause_active_old_len + 1 == self.clauses[active_index].items.len);
        }
    }
};

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

test "CnfProgram: init and deinit with no memory leaks" {
    const allocator = std.testing.allocator;

    var program = try CnfProgram.init(allocator, 10, 5);
    defer program.deinit();

    try std.testing.expectEqual(@as(u31, 10), program.variable_count);
    try std.testing.expectEqual(@as(u128, 5), program.clause_count);
    try std.testing.expectEqual(@as(usize, 5), program.clauses.len);
}

test "CnfProgram: add_literal with allocation failure" {
    var failing_allocator = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const allocator = failing_allocator.allocator();

    // Try to init with failing allocator - should fail on first allocation
    const result = CnfProgram.init(allocator, 10, 5);
    try std.testing.expectError(error.OutOfMemory, result);
}

test "CnfProgram: add literals and create clauses" {
    const allocator = std.testing.allocator;

    var program = try CnfProgram.init(allocator, 3, 2);
    defer program.deinit();

    // Add first clause: {1}
    try program.add_literal(1);
    try program.add_literal(0); // Terminate first clause

    // Add second clause: {-2}
    try program.add_literal(-2);

    // Verify first clause
    try std.testing.expectEqual(@as(usize, 1), program.clauses[0].items.len);
    try std.testing.expectEqual(@as(i32, 1), program.clauses[0].items[0]);

    // Verify second clause
    try std.testing.expectEqual(@as(usize, 1), program.clauses[1].items.len);
    try std.testing.expectEqual(@as(i32, -2), program.clauses[1].items[0]);
}

test "CnfProgram: literal out of bounds" {
    const allocator = std.testing.allocator;

    var program = try CnfProgram.init(allocator, 3, 2);
    defer program.deinit();

    // Try to add literal with absolute value > variable_count
    const result = program.add_literal(4);
    try std.testing.expectError(error.LiteralOutOfBounds, result);

    // Try negative literal out of bounds
    const result2 = program.add_literal(-4);
    try std.testing.expectError(error.LiteralOutOfBounds, result2);
}

test "CnfProgram: clause out of bounds" {
    const allocator = std.testing.allocator;

    var program = try CnfProgram.init(allocator, 3, 2);
    defer program.deinit();

    // Terminate first clause
    try program.add_literal(0);

    // Terminate second clause
    try program.add_literal(0);

    // Try to terminate third clause (doesn't exist)
    const result = program.add_literal(0);
    try std.testing.expectError(error.ClauseOutOfBounds, result);
}

test "CnfProgram: typical usage pattern" {
    const allocator = std.testing.allocator;

    // Create program with 3 variables and 2 clauses
    var program = try CnfProgram.init(allocator, 3, 2);
    defer program.deinit();

    // First clause: (1 OR -2)
    try program.add_literal(1);
    try program.add_literal(-2);
    try program.add_literal(0);

    // Second clause: (3)
    try program.add_literal(3);
    try program.add_literal(0);

    // Verify the structure
    try std.testing.expectEqual(@as(usize, 2), program.clauses[0].items.len);
    try std.testing.expectEqual(@as(i32, 1), program.clauses[0].items[0]);
    try std.testing.expectEqual(@as(i32, -2), program.clauses[0].items[1]);

    try std.testing.expectEqual(@as(usize, 1), program.clauses[1].items.len);
    try std.testing.expectEqual(@as(i32, 3), program.clauses[1].items[0]);
}

test "CnfProgram: handles minInt literal safely" {
    const allocator = std.testing.allocator;

    // Create program where minInt is out of bounds
    var program = try CnfProgram.init(allocator, 100, 1);
    defer program.deinit();

    // minInt absolute value exceeds u31 range, should be out of bounds
    const result = program.add_literal(std.math.minInt(i32));
    try std.testing.expectError(error.LiteralOutOfBounds, result);
}

test "CnfProgram: rejects clause_count larger than usize" {
    const allocator = std.testing.allocator;

    // Try to create program with clause_count > usize.max (if possible on this platform)
    const max_usize_as_u128: u128 = std.math.maxInt(usize);
    const too_large: u128 = max_usize_as_u128 + 1;

    // Due to precondition log2(clause_count) <= variable_count, we need a large enough variable_count
    // Calculate required bits more carefully to avoid overflow
    const required_bits = if (too_large <= 1) 0 else std.math.log2_int(u128, too_large);
    const variable_count = @as(u31, @intCast(@min(required_bits, std.math.maxInt(u31))));

    const result = CnfProgram.init(allocator, variable_count, too_large);
    try std.testing.expectError(error.OutOfMemory, result);
}

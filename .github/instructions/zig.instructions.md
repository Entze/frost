---
applyTo: "**/*.zig"
---

# Safety-Critical Zig Coding Standards

This file defines coding standards for safety-critical Zig development, synthesizing best practices from official Zig documentation (0.15.2) with NASA's Power of 10 rules and TigerBeetle's contract-based programming patterns.

## Style Guide

Follow the official Zig style guide from https://ziglang.org/documentation/0.15.2/#Style-Guide:

- **4 spaces of indentation** (not tabs)
- **camelCase for functions and variables** - `fn writeBuffer()`, `var myVariable: i32`
- **PascalCase for types** - `struct MyStruct`, `union MyUnion`, `enum MyEnum`
- **SCREAMING_SNAKE_CASE for namespaced constants** - `const MAGIC_NUMBER = 42;`
- **Open braces on same line** - `if (condition) {` not `if (condition)\n{`
- **Blank line between declarations** for visual separation
- **Names should be descriptive and unambiguous** - avoid abbreviations unless well-known
- **Files should use snake_case** - `my_module.zig`

## Rule 1: Control Flow Restrictions

**No recursion is allowed.** Recursion makes stack usage unpredictable and difficult to analyze.

**No goto equivalents.** Zig doesn't have goto, but avoid equivalent patterns:
- Don't use labeled breaks to simulate goto
- Don't use complex nested conditionals that emulate goto
- Prefer early returns over deeply nested control flow

```zig
// ✓ GOOD: Iterative solution with bounded stack
fn factorial(n: u32) u64 {
    assert(n <= 20); // Prevent overflow
    var result: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

// ✗ BAD: Recursive solution with unbounded stack
fn factorialRecursive(n: u32) u64 {
    if (n <= 1) return 1;
    return n * factorialRecursive(n - 1); // Recursion not allowed
}

// ✓ GOOD: Early return pattern
fn processValue(value: ?i32) !i32 {
    const v = value orelse return error.NullValue;
    if (v < 0) return error.NegativeValue;
    if (v > 1000) return error.ValueTooLarge;
    return v * 2;
}

// ✗ BAD: Deeply nested control flow
fn processValueBad(value: ?i32) !i32 {
    if (value) |v| {
        if (v >= 0) {
            if (v <= 1000) {
                return v * 2;
            } else {
                return error.ValueTooLarge;
            }
        } else {
            return error.NegativeValue;
        }
    } else {
        return error.NullValue;
    }
}
```

## Rule 2: Loop Bound Requirements

**All loops must have a determinable upper bound.** The bound should be known either at compile-time or provably finite at runtime.

### Compile-Time Bounds

Prefer compile-time known bounds when possible. These provide the strongest guarantees.

```zig
// ✓ GOOD: Compile-time known bound
fn processFixedArray(arr: [16]u8) u8 {
    var sum: u8 = 0;
    // Loop bound is compile-time constant
    for (arr) |item| {
        sum +%= item; // Wrapping add to prevent overflow
    }
    return sum;
}

// ✓ GOOD: Compile-time parameterized bound
fn clearBuffer(comptime size: usize) [size]u8 {
    assert(size <= 4096); // Reasonable limit
    var buffer: [size]u8 = undefined;
    for (&buffer) |*item| {
        item.* = 0;
    }
    return buffer;
}
```

### Runtime Bounds with Validation

When runtime bounds are necessary, validate them explicitly and document the maximum.

```zig
// ✓ GOOD: Runtime bound with explicit validation
fn processSlice(data: []const u8) !u32 {
    // Document and enforce maximum bound
    const MAX_ITEMS = 1024;
    assert(data.len <= MAX_ITEMS); // Runtime bound check
    
    var count: u32 = 0;
    var i: usize = 0;
    // Loop bound is runtime but validated
    while (i < data.len) : (i += 1) {
        if (data[i] != 0) count += 1;
    }
    return count;
}

// ✓ GOOD: Bounded search with early exit
fn findByte(haystack: []const u8, needle: u8) ?usize {
    const MAX_SEARCH = 1024;
    const search_len = @min(haystack.len, MAX_SEARCH);
    
    var i: usize = 0;
    while (i < search_len) : (i += 1) {
        if (haystack[i] == needle) return i;
    }
    return null;
}

// ✗ BAD: Unbounded while loop
fn waitForCondition(ptr: *volatile bool) void {
    while (!ptr.*) { // No bound, could loop forever
        // Spinning without limit
    }
}
```

**Tradeoffs:**
- **Compile-time bounds**: Strongest guarantees, zero runtime overhead, but less flexible
- **Runtime validated bounds**: More flexible, small validation overhead, requires discipline
- Document maximum bounds in function docstrings when using runtime bounds

## Rule 3: Memory Allocation Rules

**All functions requiring dynamic memory must accept an `Allocator` parameter.** Never use hidden global allocators.

```zig
const std = @import("std");

// ✓ GOOD: Explicit allocator parameter
/// Creates a buffer of specified size.
/// Caller owns returned memory and must call deinit().
fn createBuffer(allocator: std.mem.Allocator, size: usize) ![]u8 {
    assert(size > 0);
    assert(size <= 1024 * 1024); // 1MB max
    
    const buffer = try allocator.alloc(u8, size);
    @memset(buffer, 0);
    return buffer;
}

// ✓ GOOD: Struct with explicit allocator
const DataProcessor = struct {
    allocator: std.mem.Allocator,
    buffer: []u8,
    
    /// Initialize processor with given allocator.
    /// Call deinit() to free resources.
    pub fn init(allocator: std.mem.Allocator, capacity: usize) !DataProcessor {
        assert(capacity > 0);
        assert(capacity <= 4096);
        
        const buffer = try allocator.alloc(u8, capacity);
        return DataProcessor{
            .allocator = allocator,
            .buffer = buffer,
        };
    }
    
    pub fn deinit(self: *DataProcessor) void {
        self.allocator.free(self.buffer);
        self.* = undefined; // Poison after free
    }
};

// ✗ BAD: Hidden global allocator
var global_allocator: std.mem.Allocator = undefined;

fn createBufferBad(size: usize) ![]u8 {
    return global_allocator.alloc(u8, size); // Hidden dependency
}
```

**Memory Management Principles:**
- Allocation may fail; deallocation must succeed
- Document ownership in function docstrings
- Use `defer` for deterministic cleanup
- Prefer stack allocation when sizes are known at compile-time
- Poison freed memory with `undefined` assignment to catch use-after-free

## Rule 4: Pointer Lifetime Requirements

**Document pointer lifetimes in function docstrings.** Specify ownership and validity requirements for all pointer parameters and return values.

```zig
// ✓ GOOD: Documented pointer lifetimes
/// Processes data in-place.
/// Parameters:
///   - data: Non-null slice, must remain valid for duration of call
/// Returns: View into input data, valid only while input is valid
/// Lifetime: Return value borrows from input parameter
fn processInPlace(data: []u8) []const u8 {
    assert(data.len > 0);
    assert(data.len <= 4096);
    
    for (data) |*byte| {
        byte.* = byte.* ^ 0xFF; // Invert bits
    }
    return data;
}

/// Searches for a value in array.
/// Parameters:
///   - array: Non-null slice to search, borrowed for duration of call
///   - target: Value to find
/// Returns: Optional pointer into array, valid while array is valid
/// Lifetime: Return value borrows from array parameter
fn findValue(array: []const i32, target: i32) ?*const i32 {
    assert(array.len > 0);
    
    for (array) |*item| {
        if (item.* == target) return item;
    }
    return null;
}

// ✓ GOOD: Struct with documented pointer ownership
/// Buffer that borrows from external data.
/// Lifetime: Must not outlive the data it references.
const BufferView = struct {
    data: []const u8, // Borrowed, does not own
    
    /// Creates view of external data.
    /// Lifetime: Returned view is valid only while data is valid.
    pub fn init(data: []const u8) BufferView {
        assert(data.len > 0);
        return BufferView{ .data = data };
    }
    
    /// Returns borrowed view, valid only while self is valid.
    pub fn asSlice(self: BufferView) []const u8 {
        return self.data;
    }
};
```

## Rule 5: Assertion Density

**Minimum 2 assertions per function.** Assertions validate preconditions, postconditions, and invariants.

Use Zig's `assert()` for development-time checks (compiled out in release modes without safety checks) and explicit error returns for runtime validation.

```zig
const std = @import("std");

// ✓ GOOD: Adequate assertion density
fn computeAverage(values: []const i32) i32 {
    // Precondition: Input validation
    assert(values.len > 0);
    assert(values.len <= 1000);
    
    var sum: i64 = 0;
    for (values) |val| {
        sum += val;
    }
    
    const result = @as(i32, @intCast(@divTrunc(sum, @as(i64, @intCast(values.len)))));
    
    // Postcondition: Result is reasonable
    defer assert(result >= -2147483648 and result <= 2147483647);
    
    return result;
}

// ✓ GOOD: Invariant checks in loop
fn normalizeBuffer(buffer: []u8, max_val: u8) void {
    assert(buffer.len > 0);
    assert(max_val > 0);
    
    for (buffer, 0..) |*val, i| {
        // Invariant: Values stay in bounds
        assert(val.* <= 255);
        
        if (val.* > max_val) {
            val.* = max_val;
        }
        
        // Invariant: Normalization succeeded
        assert(val.* <= max_val);
        
        // Loop invariant: Index is valid
        assert(i < buffer.len);
    }
}

// ✗ BAD: No assertions
fn computeAverageBad(values: []const i32) i32 {
    var sum: i64 = 0;
    for (values) |val| {
        sum += val;
    }
    return @as(i32, @intCast(@divTrunc(sum, @as(i64, @intCast(values.len)))));
}
```

**Assertion Guidelines:**
- Assert preconditions at function entry
- Assert postconditions before return (use `defer assert()`)
- Assert invariants in loop bodies
- Minimum 2 assertions per function; more for complex logic
- Assertions document assumptions and catch logic errors early

## Rule 6: Precondition Assertions

**Use `assert()` at function start to validate preconditions.** Check all parameter constraints before processing.

```zig
// ✓ GOOD: Comprehensive precondition validation
fn writeToBuffer(buffer: []u8, offset: usize, data: []const u8) void {
    // Precondition: Parameters are valid
    assert(buffer.len > 0);
    assert(data.len > 0);
    assert(offset < buffer.len);
    assert(offset + data.len <= buffer.len); // Won't overflow
    
    @memcpy(buffer[offset..][0..data.len], data);
}

// ✓ GOOD: Range validation
fn clamp(value: i32, min_val: i32, max_val: i32) i32 {
    // Precondition: Range is valid
    assert(min_val <= max_val);
    
    if (value < min_val) return min_val;
    if (value > max_val) return max_val;
    return value;
}

// ✓ GOOD: State validation
const Connection = struct {
    is_open: bool,
    fd: i32,
    
    fn send(self: *Connection, data: []const u8) !void {
        // Precondition: Connection state is valid
        assert(self.is_open);
        assert(self.fd >= 0);
        assert(data.len > 0);
        assert(data.len <= 65536); // Max packet size
        
        // ... send implementation ...
        _ = self;
        _ = data;
    }
};
```

## Rule 7: Postcondition Assertions

**Use `defer assert()` to validate postconditions.** Check return values and side effects before function exit.

```zig
// ✓ GOOD: Postcondition validation with defer
fn allocateAligned(allocator: std.mem.Allocator, size: usize, alignment: usize) ![]u8 {
    assert(size > 0);
    assert(alignment > 0);
    assert(std.math.isPowerOfTwo(alignment));
    
    const buffer = try allocator.alignedAlloc(u8, alignment, size);
    
    // Postcondition: Allocation succeeded with correct properties
    defer {
        assert(buffer.len == size);
        assert(@intFromPtr(buffer.ptr) % alignment == 0);
    }
    
    return buffer;
}

// ✓ GOOD: Multiple postconditions
fn sortSlice(slice: []i32) void {
    assert(slice.len > 0);
    const original_len = slice.len;
    
    // ... sorting implementation ...
    std.mem.sort(i32, slice, {}, comptime std.sort.asc(i32));
    
    // Postconditions: Sort preserved length and order
    defer {
        assert(slice.len == original_len);
        // Verify sorted order
        if (slice.len > 1) {
            var i: usize = 0;
            while (i < slice.len - 1) : (i += 1) {
                assert(slice[i] <= slice[i + 1]);
            }
        }
    }
}

// ✓ GOOD: Side effect validation
fn incrementCounter(counter: *u32) void {
    assert(counter.* < std.math.maxInt(u32));
    const old_value = counter.*;
    
    counter.* += 1;
    
    // Postcondition: Counter incremented exactly once
    defer assert(counter.* == old_value + 1);
}
```

## Rule 8: Invariant Checks

**Add conditional assertions for invariants.** Check loop invariants and data structure consistency.

```zig
// ✓ GOOD: Loop invariant checks
fn reverseArray(array: []i32) void {
    assert(array.len > 0);
    
    var left: usize = 0;
    var right: usize = array.len - 1;
    
    while (left < right) {
        // Loop invariant: Indices are valid and converging
        assert(left < array.len);
        assert(right < array.len);
        assert(left < right);
        
        const temp = array[left];
        array[left] = array[right];
        array[right] = temp;
        
        left += 1;
        right -= 1;
    }
    
    // Postcondition: Indices met in middle
    defer assert(left >= right);
}

// ✓ GOOD: Data structure invariants
const RingBuffer = struct {
    buffer: []u8,
    read_pos: usize,
    write_pos: usize,
    count: usize,
    
    fn checkInvariants(self: *const RingBuffer) void {
        assert(self.read_pos < self.buffer.len);
        assert(self.write_pos < self.buffer.len);
        assert(self.count <= self.buffer.len);
        // Derived invariant
        assert((self.count == 0) or (self.read_pos != self.write_pos) or (self.count == self.buffer.len));
    }
    
    fn push(self: *RingBuffer, byte: u8) !void {
        self.checkInvariants();
        defer self.checkInvariants();
        
        if (self.count >= self.buffer.len) return error.BufferFull;
        
        self.buffer[self.write_pos] = byte;
        self.write_pos = (self.write_pos + 1) % self.buffer.len;
        self.count += 1;
    }
};

// ✓ GOOD: State machine invariants
const State = enum { Idle, Running, Stopped };

const StateMachine = struct {
    state: State,
    transition_count: u32,
    
    fn transition(self: *StateMachine, new_state: State) void {
        // Invariant: Valid state transitions
        switch (self.state) {
            .Idle => assert(new_state == .Running),
            .Running => assert(new_state == .Stopped),
            .Stopped => assert(new_state == .Idle),
        }
        
        self.state = new_state;
        self.transition_count += 1;
        
        // Invariant: Count never overflows
        defer assert(self.transition_count > 0);
    }
};
```

## Rule 9: Function Length Limit

**Maximum 60 lines per function.** Long functions are harder to verify, test, and maintain.

Count only logical lines (excluding blank lines, single-brace lines, and comments). If a function exceeds 60 lines, split it into smaller, focused functions.

```zig
// ✓ GOOD: Focused function under 60 lines
fn parseHeader(data: []const u8) !Header {
    assert(data.len >= 16);
    
    const magic = std.mem.readInt(u32, data[0..4], .little);
    assert(magic == MAGIC_NUMBER);
    
    const version = data[4];
    assert(version <= MAX_VERSION);
    
    const flags = data[5];
    const length = std.mem.readInt(u16, data[6..8], .little);
    assert(length <= MAX_LENGTH);
    
    return Header{
        .magic = magic,
        .version = version,
        .flags = flags,
        .length = length,
    };
}

// ✓ GOOD: Complex logic split into focused functions
fn processRequest(request: []const u8) !Response {
    assert(request.len > 0);
    assert(request.len <= MAX_REQUEST_SIZE);
    
    const header = try parseRequestHeader(request);
    const body = try parseRequestBody(request[header.header_size..]);
    const result = try executeRequest(header, body);
    return formatResponse(result);
}

fn parseRequestHeader(data: []const u8) !RequestHeader {
    // Header parsing logic...
    assert(data.len >= 8);
    return RequestHeader{};
}

fn parseRequestBody(data: []const u8) !RequestBody {
    // Body parsing logic...
    assert(data.len > 0);
    return RequestBody{};
}

fn executeRequest(header: RequestHeader, body: RequestBody) !RequestResult {
    // Execution logic...
    _ = header;
    _ = body;
    return RequestResult{};
}

fn formatResponse(result: RequestResult) Response {
    // Response formatting logic...
    _ = result;
    return Response{};
}

// ✗ BAD: Function too long (would exceed 60 lines with full implementation)
fn processRequestBad(request: []const u8) !Response {
    // Mixing header parsing, body parsing, execution, and formatting
    // in one long function makes it harder to test and verify
    // ... 100+ lines of mixed concerns ...
    _ = request;
    return Response{};
}

// Helper types for example
const Header = struct {
    magic: u32,
    version: u8,
    flags: u8,
    length: u16,
};
const MAGIC_NUMBER = 0x12345678;
const MAX_VERSION = 1;
const MAX_LENGTH = 1024;
const RequestHeader = struct { header_size: usize = 8 };
const RequestBody = struct {};
const RequestResult = struct {};
const Response = struct {};
const MAX_REQUEST_SIZE = 4096;
```

**Benefits of 60-line limit:**
- Easier to review and understand
- Simpler to test exhaustively
- Reduces cognitive load
- Encourages single responsibility
- Facilitates reuse

## Rule 10: Scope Minimization

**Declare data at the smallest possible scope.** Initialize variables as close to first use as possible.

```zig
// ✓ GOOD: Minimal scope, late initialization
fn processItems(items: []const Item) !ProcessResult {
    assert(items.len > 0);
    assert(items.len <= 1000);
    
    var valid_count: usize = 0;
    
    for (items) |item| {
        if (!isValid(item)) continue;
        
        // Declare in minimal scope
        const normalized = normalizeItem(item);
        const processed = try transformItem(normalized);
        
        // Only declare error when needed
        if (processed.status == .Error) {
            const error_msg = try formatError(processed);
            std.debug.print("Error: {s}\n", .{error_msg});
            continue;
        }
        
        valid_count += 1;
    }
    
    return ProcessResult{ .count = valid_count };
}

// ✗ BAD: Unnecessarily wide scope
fn processItemsBad(items: []const Item) !ProcessResult {
    var valid_count: usize = 0;
    var normalized: Item = undefined; // Declared too early
    var processed: ProcessedItem = undefined; // Declared too early
    var error_msg: []const u8 = undefined; // Declared too early
    
    for (items) |item| {
        if (!isValid(item)) continue;
        normalized = normalizeItem(item);
        processed = try transformItem(normalized);
        if (processed.status == .Error) {
            error_msg = try formatError(processed);
            std.debug.print("Error: {s}\n", .{error_msg});
            continue;
        }
        valid_count += 1;
    }
    
    return ProcessResult{ .count = valid_count };
}

// ✓ GOOD: Const by default, minimal mutation scope
fn calculateResult(inputs: []const f64) f64 {
    assert(inputs.len > 0);
    
    // Immutable values
    const first = inputs[0];
    const last = inputs[inputs.len - 1];
    const avg = calculateAverage(inputs);
    
    // Mutable only where needed
    var result = first + last;
    if (result < avg) {
        result = avg;
    }
    
    return result;
}

// Helper types and functions for examples
const Item = struct { value: i32 };
const ProcessedItem = struct { status: enum { Ok, Error } };
const ProcessResult = struct { count: usize };
fn isValid(item: Item) bool {
    return item.value >= 0;
}
fn normalizeItem(item: Item) Item {
    return item;
}
fn transformItem(item: Item) !ProcessedItem {
    _ = item;
    return ProcessedItem{ .status = .Ok };
}
fn formatError(processed: ProcessedItem) ![]const u8 {
    _ = processed;
    return "error";
}
fn calculateAverage(inputs: []const f64) f64 {
    var sum: f64 = 0;
    for (inputs) |v| sum += v;
    return sum / @as(f64, @floatFromInt(inputs.len));
}
```

**Scope Minimization Principles:**
- Declare const by default, var only when mutation needed
- Initialize at declaration when possible
- Limit variable visibility to smallest block
- Reduces cognitive load and potential for misuse

## Rule 11: Return Value Checking

**All non-void function return values must be used.** Zig enforces this at compile-time for error unions.

```zig
// ✓ GOOD: Return value explicitly used
fn saveToFile(path: []const u8, data: []const u8) !void {
    assert(path.len > 0);
    assert(data.len > 0);
    
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    
    const bytes_written = try file.writeAll(data);
    _ = bytes_written; // Explicitly acknowledged
}

// ✓ GOOD: Error explicitly handled
fn processWithFallback(data: []const u8) ![]const u8 {
    assert(data.len > 0);
    
    // Try primary method
    const result = processData(data) catch |err| {
        std.debug.print("Primary failed: {}, using fallback\n", .{err});
        // Fallback method
        return processFallback(data);
    };
    
    return result;
}

// ✓ GOOD: Intentional discard documented
fn notifyObservers(event: Event) void {
    // Explicitly ignore allocation failure for non-critical notifications
    const msg = formatMessage(event) catch {
        std.debug.print("Failed to format notification\n", .{});
        return;
    };
    defer msg.deinit();
    
    // Send best-effort
    sendNotification(msg.items) catch |err| {
        // Documented intentional discard
        std.debug.print("Notification failed: {}\n", .{err});
    };
}

// ✗ BAD: Would not compile - unused error union
// fn saveToFileBad(path: []const u8, data: []const u8) void {
//     std.fs.cwd().createFile(path, .{}); // Compile error: unused error union
// }

// Helper types and functions
const Event = struct { id: u32 };
fn processData(data: []const u8) ![]const u8 {
    return data;
}
fn processFallback(data: []const u8) ![]const u8 {
    return data;
}
const Message = struct {
    items: []const u8,
    fn deinit(self: Message) void {
        _ = self;
    }
};
fn formatMessage(event: Event) !Message {
    _ = event;
    return Message{ .items = "" };
}
fn sendNotification(msg: []const u8) !void {
    _ = msg;
}
```

**Return Value Principles:**
- Zig compiler enforces checking of error unions
- Explicitly acknowledge intentional discards with `_ = value;`
- Document why return values are ignored
- Prefer handling errors over ignoring them

## Rule 12: Parameter Validation

**Validate all function parameters.** Check preconditions for all inputs, including pointer validity, ranges, and state.

```zig
// ✓ GOOD: Comprehensive parameter validation
fn copyMemory(dest: []u8, src: []const u8, count: usize) void {
    // Validate all parameters
    assert(dest.len > 0);
    assert(src.len > 0);
    assert(count > 0);
    assert(count <= dest.len);
    assert(count <= src.len);
    // Ensure no overlap for memcpy semantics
    const dest_start = @intFromPtr(dest.ptr);
    const dest_end = dest_start + dest.len;
    const src_start = @intFromPtr(src.ptr);
    const src_end = src_start + src.len;
    assert(dest_end <= src_start or src_end <= dest_start);
    
    @memcpy(dest[0..count], src[0..count]);
}

// ✓ GOOD: Range and relationship validation
fn interpolate(start: f64, end: f64, t: f64) f64 {
    assert(std.math.isFinite(start));
    assert(std.math.isFinite(end));
    assert(std.math.isFinite(t));
    assert(t >= 0.0 and t <= 1.0);
    assert(start <= end);
    
    return start + (end - start) * t;
}

// ✓ GOOD: Optional parameter validation
fn findInArray(array: ?[]const i32, target: i32) ?usize {
    const arr = array orelse {
        assert(false); // Null not allowed in this context
        return null;
    };
    
    assert(arr.len > 0);
    assert(arr.len <= 10000);
    
    for (arr, 0..) |val, i| {
        if (val == target) return i;
    }
    return null;
}

// ✓ GOOD: State validation
const FileHandle = struct {
    fd: i32,
    is_open: bool,
    mode: enum { Read, Write },
    
    fn write(self: *FileHandle, data: []const u8) !void {
        // Validate object state
        assert(self.is_open);
        assert(self.fd >= 0);
        assert(self.mode == .Write);
        // Validate parameter
        assert(data.len > 0);
        assert(data.len <= 1024 * 1024);
        
        // ... write implementation ...
        _ = self;
        _ = data;
    }
};
```

**Parameter Validation Principles:**
- Check all parameters at function entry
- Validate ranges, null/optional values, and state
- Check relationships between parameters
- Use assertions for impossible conditions
- Return errors for recoverable validation failures

## Rule 13: Pointer Usage Restrictions

**Limit pointer dereferencing to single level.** Avoid pointers to pointers and complex pointer arithmetic.

```zig
// ✓ GOOD: Single-level pointers
fn updateValue(ptr: *i32, new_value: i32) void {
    assert(new_value >= 0);
    ptr.* = new_value; // Single dereference
}

// ✓ GOOD: Array pointer single-level access
fn fillArray(array: []i32, value: i32) void {
    assert(array.len > 0);
    assert(array.len <= 1000);
    
    for (array) |*item| { // Single-level pointer
        item.* = value;
    }
}

// ✓ GOOD: Slice instead of pointer-to-pointer
fn processMatrix(matrix: [][]const i32) i32 {
    assert(matrix.len > 0);
    assert(matrix.len <= 100);
    
    var sum: i32 = 0;
    for (matrix) |row| { // Each row is a slice
        assert(row.len > 0);
        for (row) |val| { // Single-level iteration
            sum += val;
        }
    }
    return sum;
}

// ✗ BAD: Multiple levels of indirection
// fn updatePointerBad(ptr: **i32, new_value: i32) void {
//     ptr.*.* = new_value; // Double dereference - avoid
// }

// ✓ GOOD: Use structs instead of complex pointers
const Node = struct {
    value: i32,
    next: ?*Node, // Optional single pointer
    
    fn append(self: *Node, new_value: i32, allocator: std.mem.Allocator) !void {
        assert(new_value >= 0);
        
        var current = self; // Single-level pointer
        while (current.next) |next_node| {
            current = next_node; // Single-level assignment
        }
        
        const new_node = try allocator.create(Node);
        new_node.* = Node{
            .value = new_value,
            .next = null,
        };
        current.next = new_node;
    }
};
```

**Pointer Usage Principles:**
- Prefer slices `[]T` over raw pointers `[*]T`
- Avoid pointer arithmetic; use slicing instead
- Single-level dereference only
- Use structs to organize related pointers
- Prefer stack allocation when possible

## Rule 14: Function Pointer Prohibition

**Do not use function pointers.** Function pointers make control flow analysis difficult and can hide recursion.

```zig
// ✗ BAD: Function pointer
// const Operation = *const fn (i32, i32) i32;
// 
// fn applyOperation(a: i32, b: i32, op: Operation) i32 {
//     return op(a, b); // Control flow not statically analyzable
// }

// ✓ GOOD: Use tagged unions for type-safe dispatch
const Operation = enum {
    Add,
    Subtract,
    Multiply,
    Divide,
};

fn applyOperation(a: i32, b: i32, op: Operation) !i32 {
    assert(a >= 0 and a <= 10000);
    assert(b >= 0 and b <= 10000);
    
    // Explicit, analyzable control flow
    return switch (op) {
        .Add => a + b,
        .Subtract => a - b,
        .Multiply => a * b,
        .Divide => blk: {
            if (b == 0) return error.DivisionByZero;
            break :blk @divTrunc(a, b);
        },
    };
}

// ✓ GOOD: Use comptime for type-safe polymorphism
fn processWithStrategy(comptime strategy: type, data: []const u8) !void {
    assert(data.len > 0);
    assert(data.len <= 4096);
    
    // Strategy is a type, checked at compile-time
    const processor = strategy{};
    try processor.process(data);
}

// Example strategy types
const FastStrategy = struct {
    fn process(self: FastStrategy, data: []const u8) !void {
        _ = self;
        assert(data.len > 0);
        // Fast processing
    }
};

const SafeStrategy = struct {
    fn process(self: SafeStrategy, data: []const u8) !void {
        _ = self;
        assert(data.len > 0);
        // Safe processing with extra checks
    }
};

// ✓ GOOD: Use interfaces with comptime for dynamic dispatch
fn processWithInterface(processor: anytype, data: []const u8) !void {
    assert(data.len > 0);
    // Type is checked at compile-time, but allows different implementations
    try processor.process(data);
}
```

**Rationale for Function Pointer Prohibition:**
- Makes static analysis difficult
- Can hide recursion and unbounded calls
- Control flow becomes unpredictable
- Zig's comptime provides better alternatives
- Tagged unions give type-safe, analyzable dispatch

**Alternatives to Function Pointers:**
- Tagged unions for enumerated operations
- Comptime type parameters for compile-time polymorphism
- `anytype` parameters with comptime interface checking
- Explicit switch statements for dispatch

## Compile-Time vs Runtime Bounds: Tradeoffs

Understanding when to use compile-time vs runtime bounds is crucial for balancing safety with flexibility.

### Compile-Time Bounds

**Advantages:**
- Strongest safety guarantees
- Zero runtime overhead
- Verified by compiler
- No need for runtime checks
- Optimal code generation

**Disadvantages:**
- Less flexible
- Requires size known at compile-time
- Can lead to code bloat with many sizes
- May require separate functions for different sizes

**Use When:**
- Size is fixed by design (e.g., cryptographic block size)
- Buffer sizes are known constants
- Working with fixed-size protocols
- Maximum performance is critical

```zig
// Compile-time bounds example
fn sha256Block(input: [64]u8) [32]u8 {
    assert(input.len == 64); // Redundant but documents requirement
    var output: [32]u8 = undefined;
    // Process fixed 512-bit block
    // Compiler knows exact size, can optimize aggressively
    _ = input;
    return output;
}
```

### Runtime Bounds with Validation

**Advantages:**
- More flexible
- Handles dynamic sizes
- Single function for multiple sizes
- More reusable code

**Disadvantages:**
- Requires runtime validation
- Small overhead for bounds checks
- Must document maximum limits
- Can fail at runtime

**Use When:**
- Size comes from user input or external source
- Need to handle variable-length data
- Writing library code with flexible APIs
- Size is data-dependent

```zig
// Runtime bounds with validation
fn hashData(input: []const u8, output: []u8) !void {
    // Document and enforce maximum
    const MAX_INPUT = 1024 * 1024; // 1MB
    assert(input.len <= MAX_INPUT);
    assert(output.len >= 32); // Minimum output size
    
    // Process with runtime-known size
    // Slightly more overhead but much more flexible
    _ = input;
    _ = output;
}
```

### Hybrid Approach

**Best practice:** Use compile-time bounds for internal implementation, runtime bounds for public APIs.

```zig
// Public API: Runtime bounds for flexibility
pub fn processData(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const MAX_SIZE = 4096;
    assert(data.len <= MAX_SIZE);
    
    // Use compile-time sized buffer internally
    var buffer: [4096]u8 = undefined;
    const result_len = processInternal(&buffer, data);
    
    // Return dynamically sized result
    const result = try allocator.alloc(u8, result_len);
    @memcpy(result, buffer[0..result_len]);
    return result;
}

// Internal: Compile-time bounds for safety and performance
fn processInternal(buffer: []u8, data: []const u8) usize {
    assert(buffer.len == 4096); // Known size
    assert(data.len <= buffer.len);
    
    // Fast processing with compile-time known buffer
    @memcpy(buffer[0..data.len], data);
    return data.len;
}
```

**Guidelines:**
- Start with compile-time bounds when possible
- Document maximum limits for runtime bounds
- Use hybrid approach for library APIs
- Prefer stack allocation with compile-time sizes
- Validate runtime bounds at API boundaries

## Complete Examples

### Example 1: Safe Buffer Management

```zig
const std = @import("std");

/// Ring buffer with fixed capacity.
/// Thread-safe for single producer, single consumer.
pub const RingBuffer = struct {
    const Self = @This();
    const CAPACITY = 256; // Compile-time capacity
    
    buffer: [CAPACITY]u8,
    read_idx: usize,
    write_idx: usize,
    count: usize,
    
    /// Initialize empty ring buffer.
    pub fn init() Self {
        return Self{
            .buffer = undefined,
            .read_idx = 0,
            .write_idx = 0,
            .count = 0,
        };
    }
    
    /// Push byte into buffer.
    /// Returns error if buffer is full.
    pub fn push(self: *Self, byte: u8) !void {
        // Preconditions
        assert(self.read_idx < CAPACITY);
        assert(self.write_idx < CAPACITY);
        assert(self.count <= CAPACITY);
        
        if (self.count >= CAPACITY) {
            return error.BufferFull;
        }
        
        // Perform operation
        self.buffer[self.write_idx] = byte;
        self.write_idx = (self.write_idx + 1) % CAPACITY;
        self.count += 1;
        
        // Postconditions
        defer {
            assert(self.count > 0);
            assert(self.count <= CAPACITY);
            assert(self.write_idx < CAPACITY);
        }
    }
    
    /// Pop byte from buffer.
    /// Returns null if buffer is empty.
    pub fn pop(self: *Self) ?u8 {
        // Preconditions
        assert(self.read_idx < CAPACITY);
        assert(self.write_idx < CAPACITY);
        assert(self.count <= CAPACITY);
        
        if (self.count == 0) {
            return null;
        }
        
        // Perform operation
        const byte = self.buffer[self.read_idx];
        self.read_idx = (self.read_idx + 1) % CAPACITY;
        self.count -= 1;
        
        // Postconditions
        defer {
            assert(self.count < CAPACITY);
            assert(self.read_idx < CAPACITY);
        }
        
        return byte;
    }
    
    /// Returns current number of bytes in buffer.
    pub fn len(self: *const Self) usize {
        assert(self.count <= CAPACITY);
        return self.count;
    }
    
    /// Returns true if buffer is empty.
    pub fn isEmpty(self: *const Self) bool {
        return self.count == 0;
    }
    
    /// Returns true if buffer is full.
    pub fn isFull(self: *const Self) bool {
        return self.count >= CAPACITY;
    }
};
```

### Example 2: Safe Array Processing

```zig
const std = @import("std");

/// Computes statistics for an array of values.
/// Maximum array size: 10000 elements.
pub fn computeStats(values: []const i32) !Stats {
    // Preconditions: Validate input
    assert(values.len > 0);
    const MAX_SIZE = 10000;
    assert(values.len <= MAX_SIZE);
    
    var min_val = values[0];
    var max_val = values[0];
    var sum: i64 = 0;
    
    // Process with bounded loop
    for (values, 0..) |val, i| {
        // Loop invariants
        assert(i < values.len);
        assert(i < MAX_SIZE);
        
        // Update statistics
        if (val < min_val) min_val = val;
        if (val > max_val) max_val = val;
        sum += val;
    }
    
    const mean = @divTrunc(sum, @as(i64, @intCast(values.len)));
    
    // Postconditions: Validate results
    defer {
        assert(min_val <= max_val);
        assert(mean >= min_val);
        assert(mean <= max_val);
    }
    
    return Stats{
        .min = min_val,
        .max = max_val,
        .mean = @as(i32, @intCast(mean)),
        .count = values.len,
    };
}

pub const Stats = struct {
    min: i32,
    max: i32,
    mean: i32,
    count: usize,
};
```

### Example 3: Safe Memory Pool

```zig
const std = @import("std");

/// Fixed-size memory pool for allocations.
/// Allocates from pre-allocated buffer, no dynamic allocation.
pub const MemoryPool = struct {
    const Self = @This();
    const POOL_SIZE = 4096;
    const MAX_ALLOCATIONS = 64;
    
    buffer: [POOL_SIZE]u8,
    used: usize,
    allocation_count: usize,
    
    /// Initialize empty pool.
    pub fn init() Self {
        return Self{
            .buffer = undefined,
            .used = 0,
            .allocation_count = 0,
        };
    }
    
    /// Allocate aligned memory from pool.
    /// Parameters:
    ///   - size: Bytes to allocate, must be > 0 and <= remaining space
    ///   - alignment: Must be power of 2
    /// Returns: Slice of allocated memory, valid until reset() is called
    /// Lifetime: Returned slice is valid until pool is reset
    pub fn alloc(self: *Self, size: usize, alignment: usize) ![]u8 {
        // Preconditions
        assert(size > 0);
        assert(size <= POOL_SIZE);
        assert(std.math.isPowerOfTwo(alignment));
        assert(alignment <= 16);
        assert(self.used <= POOL_SIZE);
        assert(self.allocation_count <= MAX_ALLOCATIONS);
        
        if (self.allocation_count >= MAX_ALLOCATIONS) {
            return error.TooManyAllocations;
        }
        
        // Align current position
        const aligned_used = std.mem.alignForward(usize, self.used, alignment);
        const new_used = aligned_used + size;
        
        if (new_used > POOL_SIZE) {
            return error.OutOfMemory;
        }
        
        // Perform allocation
        const slice = self.buffer[aligned_used..new_used];
        self.used = new_used;
        self.allocation_count += 1;
        
        // Postconditions
        defer {
            assert(self.used > 0);
            assert(self.used <= POOL_SIZE);
            assert(slice.len == size);
            assert(@intFromPtr(slice.ptr) % alignment == 0);
        }
        
        return slice;
    }
    
    /// Reset pool, invalidating all allocations.
    pub fn reset(self: *Self) void {
        // Preconditions
        assert(self.used <= POOL_SIZE);
        
        self.used = 0;
        self.allocation_count = 0;
        
        // Postconditions
        defer {
            assert(self.used == 0);
            assert(self.allocation_count == 0);
        }
    }
    
    /// Returns bytes available for allocation.
    pub fn available(self: *const Self) usize {
        assert(self.used <= POOL_SIZE);
        return POOL_SIZE - self.used;
    }
};
```

## Counter-Examples: Rule Violations

### Violation 1: Unbounded Loop

```zig
// ✗ BAD: No upper bound
fn findValueBad(list: *Node, target: i32) ?*Node {
    var current = list;
    while (current.next) |next| { // Could loop forever
        if (next.value == target) return next;
        current = next;
    }
    return null;
}

// ✓ GOOD: Bounded iteration
fn findValueGood(list: *Node, target: i32) ?*Node {
    assert(list.value >= 0);
    
    const MAX_ITERATIONS = 1000;
    var current = list;
    var iterations: usize = 0;
    
    while (current.next) |next| {
        assert(iterations < MAX_ITERATIONS); // Enforced bound
        if (next.value == target) return next;
        current = next;
        iterations += 1;
    }
    return null;
}
```

### Violation 2: Hidden Allocator

```zig
// ✗ BAD: Hidden global allocator
var g_allocator: std.mem.Allocator = undefined;

fn createListBad(size: usize) ![]i32 {
    return g_allocator.alloc(i32, size); // Hidden dependency
}

// ✓ GOOD: Explicit allocator parameter
fn createListGood(allocator: std.mem.Allocator, size: usize) ![]i32 {
    assert(size > 0);
    assert(size <= 10000);
    return allocator.alloc(i32, size);
}
```

### Violation 3: Missing Assertions

```zig
// ✗ BAD: No validation
fn divideBad(a: i32, b: i32) i32 {
    return @divTrunc(a, b); // Could crash on division by zero
}

// ✓ GOOD: Proper validation
fn divideGood(a: i32, b: i32) i32 {
    // Preconditions
    assert(b != 0); // Prevent division by zero
    assert(a >= 0 and a <= 1000000);
    assert(b >= -1000000 and b <= 1000000);
    
    const result = @divTrunc(a, b);
    
    // Postcondition
    defer assert(result * b <= a + @abs(b));
    
    return result;
}
```

### Violation 4: Wide Scope

```zig
// ✗ BAD: Variables declared at function scope
fn processBad(items: []Item) void {
    var i: usize = 0;
    var temp: Item = undefined;
    var sum: i32 = 0;
    
    // ... many lines later ...
    while (i < items.len) : (i += 1) {
        temp = items[i];
        sum += temp.value;
    }
}

// ✓ GOOD: Minimal scope
fn processGood(items: []const Item) i32 {
    assert(items.len > 0);
    assert(items.len <= 1000);
    
    var sum: i32 = 0;
    
    for (items) |item| { // Loop variable in minimal scope
        sum += item.value;
    }
    
    defer assert(sum >= 0); // Reasonable postcondition
    
    return sum;
}
```

### Violation 5: Function Too Long

```zig
// ✗ BAD: Function exceeds 60 lines (abbreviated here)
fn processRequestBad(data: []const u8) !Response {
    // Parse header (20 lines)
    // Validate header (15 lines)
    // Parse body (25 lines)
    // Validate body (15 lines)
    // Process data (20 lines)
    // Format response (15 lines)
    // Total: 110 lines - too long!
    _ = data;
    return Response{};
}

// ✓ GOOD: Split into focused functions
fn processRequestGood(data: []const u8) !Response {
    assert(data.len > 0);
    assert(data.len <= 65536);
    
    const header = try parseAndValidateHeader(data);
    const body_start = header.size;
    const body = try parseAndValidateBody(data[body_start..]);
    const result = try processData(body);
    return formatResponse(result);
}
// Each helper function < 60 lines
```

## References

This document synthesizes guidelines from:

- **Zig Official Documentation (0.15.2)**
  - https://ziglang.org/documentation/0.15.2/
  - https://ziglang.org/documentation/0.15.2/#Style-Guide
  - https://ziglang.org/documentation/0.15.2/std/
  
- **Zig Learning Resources**
  - https://ziglang.org/learn/
  - https://ziglang.org/learn/overview/
  - https://ziglang.org/learn/samples/

- **TigerBeetle Safety & Contract Programming**
  - https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md#safety
  - https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md#developer-experience
  - https://tigerbeetle.com/blog/2023-12-27-it-takes-two-to-contract/
  - https://tigerbeetle.com/blog/2025-05-26-asserting-implications/

- **NASA Power of 10 Rules for Safety-Critical Code**
  - Adapted for Zig's compile-time capabilities and memory model

---

**Note:** These guidelines prioritize safety, verifiability, and maintainability for critical systems. Apply proportionally based on your project's safety requirements. For non-critical code, some rules may be relaxed, but the assertion and validation principles remain valuable.

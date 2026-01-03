---
applyTo: "**/*.zig"
---
# Zig Development Guidelines

## Purpose & Scope

This file defines Zig coding conventions combining TigerBeetle's TigerStyle philosophy with official Zig style guide recommendations. These guidelines prioritize **safety, performance, and developer experience** (in that order) for building reliable, high-performance Zig libraries and applications.

When TigerStyle and Zig documentation conflict, **Zig documentation takes precedence** for naming and formatting conventions.

---

## Naming Conventions

### General Rules
- **Types**: `TitleCase` (e.g., `ArrayList`, `XmlParser`)
  - Exception: Namespace structs (0 fields, never instantiated) use `snake_case`
- **Functions**: `camelCase` (e.g., `readFile`, `parseJson`, `readU32Be`)
  - Exception: Functions returning `type` use `TitleCase` (e.g., `ArrayList`, `ShortList`)
- **Variables, constants, fields**: `snake_case` (e.g., `user_count`, `max_retries`, `field_name`)
- **Files**:
  - Types (structs with fields): `TitleCase.zig`
  - Namespaces (no fields): `snake_case.zig`
- **Directories**: Always `snake_case`

### Specific Rules
- **No abbreviations** except single-letter variables for primitives in math/sort functions
- **Acronyms follow naming rules**: `XmlParser` not `XMLParser`, `readU32Be` not `readU32BE`
  - Two-letter acronyms also follow rules: `Be` in `readU32Be`
- **Units/qualifiers last, descending significance**: `latency_ms_max` not `max_latency_ms`
- **Match character length for related names**: `source`/`target` not `src`/`dest`
- **Meaningful names**: `gpa: Allocator`, `arena: Allocator` not just `allocator: Allocator`
- **Helper functions prefixed with parent name**: `readSector()` → `readSectorCallback()`

### Avoid Redundancy
- **Never use these in type names**: Value, Data, Context, Manager, utils, misc, or initials
- **Consider full namespace**: Use `json.Value` not `json.JsonValue`
- **Don't duplicate namespace segments** in fully-qualified names

---

## Code Style

### Formatting
- **Indentation**: 4 spaces (never tabs)
- **Line length**: Aim for 100 columns, use common sense
- **Braces**: Open on same line unless wrapping is needed
- **Lists**: If >2 items, put each on own line with trailing comma
- **Always run `mise run fix`** before committing

### Control Flow
- **No recursion** - use loops with fixed upper bounds
- **All loops must have bounded iterations**
- **Split compound conditions** into nested `if/else` - avoid complex boolean expressions
- **Split `else if` chains** into `else { if { } }` trees
- **State invariants positively**: `if (index < length)` not `if (index >= length)`
- **Add braces** unless statement fits on single line

### Functions
- **70-line hard limit per function** - no exceptions
- **Centralize control flow** - keep all `switch`/`if` in parent, move logic to helpers
- **Centralize state** - parent holds state, helpers compute changes (keep helpers pure)
- **Callbacks go last** in parameter lists
- **Simpler return types preferred**: `void` > `bool` > `u64` > `?u64` > `!u64`
- **Extract hot loops** into standalone functions with primitive arguments (no `self`)

### Variables
- **Declare at smallest possible scope**
- **Don't introduce before needed** - declare close to use
- **Use explicit integer types**: `u32`, `i64` not `usize`, `isize`
- **Don't alias or duplicate variables** - prevents state sync bugs
- **Large structs (>16 bytes)**: Pass as `*const` to catch accidental copies
- **Initialize large structs in-place** via out pointers

### Struct Organization
- **Order: fields → types → methods**
- Fields listed first
- Nested types next, concluding with `const Self = @This();`
- Methods last

### Memory Management
- **All memory statically allocated at startup** - no dynamic allocation after init
- **Zero buffers** to prevent buffer bleeds (uninitialized padding)
- **Group resource allocation/deallocation** with newlines (before alloc, after defer)

---

## Assertions & Safety

### Assertion Requirements
- **Minimum 2 assertions per function** - directly measurable metric
  - The 2 usually means: one for preconditions, one for postconditions
- **Assert all function arguments** (preconditions) at entry
- **Assert postconditions with `defer`** before function can return:
  ```zig
  pub fn addFunds(self: *Self, amount_cents: i64) void {
      assert(amount_cents >= 0); // Precondition
      defer assert(self.balance_cents >= 0); // Postcondition

      self.balance_cents += amount_cents;
  }
  ```
- **Pair assertions** - assert same property in 2+ locations (e.g., before disk write AND after disk read)

### Assertion Patterns
- **Split compound assertions**: `assert(a); assert(b);` not `assert(a and b);`
- **Use implications**: `if (a) assert(b);` for single-line conditional assertions
- **Assert compile-time constants** for design integrity
- **Assert positive AND negative space** - both expected and unexpected states

### Safety Rules
- **All errors must be handled** - no ignored error unions
- **Show division intent**: Use `@divExact()`, `@divFloor()`, or `div_ceil()`
- **Explicit library options** at call sites - never rely on defaults
- **Functions run to completion** - no suspending (keeps assertions valid)

---

## Error Handling

- **All errors must be handled** - never ignore error unions
- **Handle expected vs unexpected failures differently**:
  - Expected (operating errors): Handle gracefully with error unions
  - Unexpected (programmer errors): Use assertions, crash on violation
- **Show error semantics clearly** in code

---

## Comments & Documentation

### Comment Style
- **Comments are sentences**: Space after `//`, capital letter, period/colon
- **Always explain WHY**, not just what the code does
- **Show your workings** - explain approach and methodology

### Doc Comments
- **Omit redundant information** already clear from the name
- **Duplicate across similar functions** - helps IDEs provide better context
- **Use "assume"** for invariants causing unchecked Illegal Behavior when violated
- **Use "assert"** for invariants causing safety-checked Illegal Behavior when violated

---

## Testing

### Doctest Requirements
- **Every public method needs a doctest** - test immediately following the declaration:
  ```zig
  pub fn calculateSum(a: i32, b: i32) i32 {
      return a + b;
  }

  test calculateSum {
      const result = calculateSum(5, 3);
      try std.testing.expectEqual(8, result);
  }
  ```
- **Test exhaustively** with both valid AND invalid data
- **Test boundary transitions** where data moves between valid/invalid
- **Write test methodology at top** to explain goal and approach
- **Assertions in tests encode expectations** - they are documentation

---

## Performance

### Implementation Patterns
- **Batch operations** to amortize costs across all resources
- **Be explicit** - don't rely on compiler optimization
- **Extract hot loops** into standalone functions with primitive arguments
- **Give CPU large chunks of work** - be predictable, minimize branching
- **Optimize slowest resources first**: Network → Disk → Memory → CPU (adjusted for frequency)

---

## Code Examples

### Naming Conventions
```zig
// Good
const json_parser = @import("parsers/json_parser.zig");
const XmlDocument = @import("parsers/XmlDocument.zig");

fn parseJsonValue(input: []const u8) !json_parser.Value { ... }
fn readU32Be(buffer: []const u8) u32 { ... }

// Bad
const JsonParser = @import("parsers/json.zig"); // Redundant "Json"
fn ParseJsonValue(input: []const u8) !Value { ... } // Should be camelCase
```

### Preconditions and Postconditions
```zig
pub fn divide(numerator: i64, denominator: i64) i64 {
    assert(denominator != 0); // Precondition
    defer assert(result * denominator == numerator); // Postcondition

    const result = @divExact(numerator, denominator);
    return result;
}

test divide {
    try std.testing.expectEqual(5, divide(15, 3));
    try std.testing.expectEqual(-4, divide(-12, 3));
}
```

### Control Flow
```zig
// Good - Simple conditions, clear structure
if (index < buffer.len) {
    if (buffer[index] > threshold) {
        // Handle above threshold
    } else {
        // Handle at or below threshold
    }
} else {
    return error.IndexOutOfBounds;
}

// Bad - Compound conditions
if (index < buffer.len and buffer[index] > threshold) {
    // Hard to verify all cases handled
}
```

### Struct with Doctest
```zig
const UserAccount = struct {
    user_id: u64,
    balance_cents: i64,

    const Self = @This();

    pub fn init(user_id: u64) Self {
        return .{
            .user_id = user_id,
            .balance_cents = 0,
        };
    }

    pub fn addFunds(self: *Self, amount_cents: i64) void {
        assert(amount_cents >= 0);
        defer assert(self.balance_cents >= 0);

        self.balance_cents += amount_cents;
    }
};

test init {
    const account = UserAccount.init(123);
    try std.testing.expectEqual(123, account.user_id);
    try std.testing.expectEqual(0, account.balance_cents);
}

test addFunds {
    var account = UserAccount.init(123);
    account.addFunds(1000);
    try std.testing.expectEqual(1000, account.balance_cents);
}
```

---

## Advanced Tips & Edge Cases

### When to Break Rules

- **Line length**: Use common sense - occasionally going to 110 columns for readability is fine
- **Function length**: If a function is naturally 75 lines and splitting would harm clarity, document why
- **Established conventions**: Follow them (e.g., `ENOENT` over `enoent`)

### Safety Edge Cases

- **Blatantly true assertions**: Use occasionally as strong documentation for critical invariants
- **Assertion density**: Aim for minimum 2 per function (precondition + postcondition), but complex functions may need 5-10+
- **Control plane vs data plane**: High assertion density in control plane, minimal in hot data plane paths

## References

- [Zig documentation](https://ziglang.org/documentation/0.15.2/)
- [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md)

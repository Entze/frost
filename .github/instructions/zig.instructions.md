---
applyTo: "**/*.zig"
---

# Safety-Critical Zig Coding Standards

Coding standards for safety-critical Zig development, synthesizing official Zig documentation (0.15.2), NASA's Power of 10 rules, and TigerBeetle's contract-based programming patterns.

## Style Guide

- Use **4 spaces** for indentation (not tabs)
- Use **camelCase** for functions and variables
- Use **PascalCase** for types (structs, unions, enums)
- Use **SCREAMING_SNAKE_CASE** for namespaced constants
- Open braces on same line
- Blank line between declarations
- Descriptive names, avoid abbreviations
- Files use snake_case

## Rule 1: Control Flow Restrictions

- **No recursion** - makes stack usage unpredictable
- **No goto equivalents** - no labeled breaks to simulate goto
- **No complex nested conditionals** that emulate goto
- **Prefer early returns** over deeply nested control flow
- Use iterative solutions with bounded stack

## Rule 2: Loop Bound Requirements

- **All loops must have determinable upper bound** - compile-time or runtime validated
- **Prefer compile-time bounds** - strongest guarantees, zero runtime overhead
- **Runtime bounds must be validated** - assert with explicit max value, document in docstring
- **Never unbounded loops** - no infinite while loops without max iterations

**Tradeoffs:**
- Compile-time: Strongest safety, no overhead, less flexible
- Runtime validated: More flexible, small overhead, requires discipline
- Document maximum bounds in function docstrings

## Rule 3: Memory Allocation Rules

- **All functions requiring dynamic memory must accept `Allocator` parameter**
- **Never use hidden global allocators**
- **Document ownership in function docstrings** - who owns returned memory
- **Use `defer` for deterministic cleanup**
- **Prefer stack allocation** when sizes known at compile-time
- **Poison freed memory** with `undefined` assignment to catch use-after-free
- Remember: Allocation may fail; deallocation must succeed

## Rule 4: Pointer Lifetime Requirements

- **Document pointer lifetimes in function docstrings**
- **Specify ownership** for all pointer parameters and return values
- **Document validity requirements** - how long pointers remain valid
- **Use "Lifetime:" section** in docstrings to explain borrowing relationships
- **Mark borrowed vs owned** pointers clearly in documentation

## Rule 5: Assertion Density

- **Minimum 2 assertions per function**
- **Validate preconditions, postconditions, and invariants**
- Use `assert()` for development-time checks
- Use explicit error returns for runtime validation
- Assert preconditions at function entry
- Assert postconditions before return with `defer assert()`
- Assert invariants in loop bodies
- More assertions for complex logic

## Rule 6: Precondition Assertions

- **Use `assert()` at function start** to validate all preconditions
- **Check all parameter constraints** before processing
- **Validate ranges, null/optional values, and state**
- **Check relationships between parameters**
- Examples: buffer lengths, numeric ranges, pointer validity, state consistency

## Rule 7: Postcondition Assertions

- **Use `defer assert()` to validate postconditions**
- **Check return values and side effects** before function exit
- **Verify operation succeeded** with expected results
- **Check data structure consistency** after modifications
- **Validate state transitions** completed correctly

## Rule 8: Invariant Checks

- **Add conditional assertions for invariants**
- **Check loop invariants** - indices valid, convergence properties
- **Verify data structure consistency** - ring buffer positions, counts
- **State machine invariants** - valid transitions, state consistency
- Call invariant check methods at function entry and exit with `defer`

## Rule 9: Function Length Limit

- **Maximum 60 lines per function** (logical lines, excluding blank/comment/brace-only)
- **Split long functions** into smaller, focused functions
- Benefits: Easier review, simpler testing, reduces cognitive load, encourages single responsibility
- Each function should have one clear purpose

## Rule 10: Scope Minimization

- **Declare data at smallest possible scope**
- **Initialize variables close to first use**
- **Declare const by default**, var only when mutation needed
- **Initialize at declaration** when possible
- **Limit variable visibility** to smallest block
- Reduces cognitive load and potential for misuse

## Rule 11: Return Value Checking

- **All non-void return values must be used** (Zig enforces for error unions)
- **Explicitly acknowledge intentional discards** with `_ = value;`
- **Document why return values are ignored** in comments
- **Prefer handling errors** over ignoring them
- Use `catch` for error handling or propagate with `try`

## Rule 12: Parameter Validation

- **Validate all function parameters** at function entry
- **Check preconditions for all inputs** - pointer validity, ranges, state
- **Validate ranges** for numeric parameters
- **Check null/optional values**
- **Verify relationships between parameters**
- **Use assertions for impossible conditions**
- **Return errors for recoverable validation failures**

## Rule 13: Pointer Usage Restrictions

- **Limit to single-level pointer dereferencing**
- **Avoid pointers to pointers** and complex pointer arithmetic
- **Prefer slices `[]T`** over raw pointers `[*]T`
- **Avoid pointer arithmetic** - use slicing instead
- **Use structs** to organize related pointers
- **Prefer stack allocation** when possible

## Rule 14: Function Pointer Prohibition

- **Do not use function pointers** - makes control flow analysis difficult
- **Can hide recursion** and unbounded calls
- **Use tagged unions** for type-safe dispatch instead
- **Use comptime type parameters** for compile-time polymorphism
- **Use `anytype` parameters** with comptime interface checking
- **Explicit switch statements** for dispatch
- Zig's comptime provides better alternatives than function pointers

## Compile-Time vs Runtime Bounds

### When to Use Compile-Time Bounds

- Size is fixed by design (e.g., cryptographic block size)
- Buffer sizes are known constants
- Working with fixed-size protocols
- Maximum performance is critical
- **Advantages:** Strongest safety, verified by compiler, zero overhead, optimal codegen
- **Disadvantages:** Less flexible, requires size known at compile-time, potential code bloat

### When to Use Runtime Bounds

- Size comes from user input or external source
- Need to handle variable-length data
- Writing library code with flexible APIs
- Size is data-dependent
- **Advantages:** More flexible, handles dynamic sizes, more reusable
- **Disadvantages:** Requires validation, small overhead, must document max limits

### Hybrid Approach (Recommended)

- **Public APIs:** Runtime bounds for flexibility
- **Internal implementation:** Compile-time bounds for safety and performance
- **Document maximum limits** for runtime bounds
- **Validate at API boundaries**
- **Use compile-time sized buffers internally** when possible

## References

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

**Note:** These guidelines prioritize safety, verifiability, and maintainability for critical systems. Apply proportionally based on your project's safety requirements.

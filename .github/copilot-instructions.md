# Copilot Instructions for Frost

## Project Overview

Frost is a library and application for converting from and to Conjunctive Normal Form (CNF, sometimes also Clausal Normal Form) and SAT formats.

**Zig Version:** 0.15.2

## Build Commands

- `mise run build` - Build the project
- `mise run test` - Run tests
- `mise run check` - Run checks (required before each commit)
- `mise run fix --all` - Fix formatting (required before each commit)

## Zig Zen Principles

Follow the Zig zen philosophy in all code:

- Communicate intent precisely
- Edge cases matter
- Favor reading code over writing code
- Only one obvious way to do things
- Runtime crashes are better than bugs
- Compile errors are better than runtime crashes
- Incremental improvements
- Avoid local maximums
- Reduce the amount one must remember
- Focus on code rather than style
- Resource allocation may fail; resource deallocation must succeed
- Memory is a resource
- Together we serve the users

## References

- https://ziglang.org/learn/
- https://ziglang.org/documentation/0.15.2/

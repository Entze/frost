# Copilot Instructions for Frost

## Project Overview

Frost is a library and application for converting from and to Conjunctive Normal Form (CNF, sometimes also Clausal Normal Form) and SAT formats.

**Zig Version:** 0.15.2

## Build Commands

- `mise run build` - Build the project
- `mise run test` - Run tests
- `mise run check` - Run checks (required before each commit)
- `mise run fix --all` - Fix formatting (required before each commit)

## Release Process

**IMPORTANT**: When creating a pull request that should trigger a release, you MUST include a `RELEASE.txt` file in the repository root.

### RELEASE.txt Format

1. **First line**: Must be exactly one of: `MAJOR`, `MINOR`, or `PATCH`
   - `MAJOR` - Breaking changes (reserved for 1.0.0+)
   - `MINOR` - New features or significant changes (use pre-1.0.0)
   - `PATCH` - Bug fixes or minor improvements

2. **Subsequent lines**: Short, precise plain-text description of changes
   - Start each item with action verbs: "Added", "Introduced", "Deprecated", "Removed", "Changed", "Improved", "Reworked"
   - Focus on user-facing changes
   - Be concise but descriptive

### Example RELEASE.txt

```
MINOR
- Introduced continuous delivery pipeline
- Added automated version management
```

See [CONTRIBUTING.md](../CONTRIBUTING.md) for complete release process details.

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

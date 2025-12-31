---
applyTo: "**/build.zig"
---

# Zig Build System Documentation

Guidelines for editing and reviewing `build.zig` files, combining official Zig build system concepts with Frost project conventions.

## Overview

The Zig build system is a **declarative DSL** (Domain Specific Language) embedded in Zig code. Unlike imperative build scripts, `build.zig` does not directly execute build actions. Instead, it constructs a **build graph** that an external runner executes, enabling automatic parallelization and intelligent caching.

**Official Reference:** https://ziglang.org/learn/build-system

## Core Concepts

### Build Graph and Declarative Nature

The `build()` function receives a `*std.Build` pointer and uses it to declare build steps and their dependencies. The build runner then executes this graph:

- **Steps** represent units of work (compile, test, run, install)
- **Dependencies** express relationships between steps
- **Parallel execution** happens automatically when steps are independent
- **Caching** prevents re-running unchanged steps

**Key insight:** Functions like `b.addExecutable()`, `b.addTest()`, and `b.step()` mutate the build graph rather than performing immediate actions.

**Reference:** https://ziglang.org/learn/build-system/#build-graph

### Modules

Modules are collections of source files with associated compilation options. Zig uses modules (not individual files) as the compilation unit:

- **`b.addModule(name, options)`** - Exposes a module to package consumers
- **`b.createModule(options)`** - Creates an internal module (not exposed)
- **Root source file** - Entry point defining the module's public API
- **Target and optimization** - Must be explicitly specified for executables/libraries

Modules support imports, allowing code reuse and dependency management.

**Reference:** https://ziglang.org/learn/build-system/#modules

### Standard Options

These functions provide common configuration flags automatically added to `zig build --help`:

- **`b.standardTargetOptions()`** - Target architecture/OS selection
- **`b.standardOptimizeOption()`** - Debug, ReleaseSafe, ReleaseFast, ReleaseSmall
- **`b.option()`** - Custom boolean, string, enum, or list options

Options allow users to customize builds without modifying `build.zig`.

**Reference:** https://ziglang.org/learn/build-system/#standard-configuration-options

### Top-Level Steps

Top-level steps are user-invokable commands via `zig build <step-name>`:

- **`b.step(name, description)`** - Creates a named step
- **`step.dependOn(&other_step.step)`** - Establishes dependency relationships
- **Default step** - Runs when invoking `zig build` without arguments (install step)

Steps only execute when invoked by the user or depended upon by an invoked step.

**Reference:** https://ziglang.org/learn/build-system/#top-level-steps

### Artifacts and Installation

Artifacts are compiled outputs (executables, libraries, tests):

- **`b.addExecutable()`** - Defines an executable artifact
- **`b.addStaticLibrary()`/`b.addSharedLibrary()`** - Defines library artifacts
- **`b.addTest()`** - Creates a test executable
- **`b.installArtifact(artifact)`** - Marks artifact for installation to `zig-out/`

The install prefix defaults to `zig-out/` but can be overridden with `--prefix` or `-p`.

**Reference:** https://ziglang.org/learn/build-system/#artifacts

### Run Steps

Run steps execute compiled artifacts:

- **`b.addRunArtifact(artifact)`** - Creates a step to run an artifact
- **`run_cmd.addArgs(args)`** - Passes command-line arguments
- **`b.args`** - Captures arguments after `--` in `zig build run -- arg1 arg2`

Run steps typically depend on the install step to run from `zig-out/` rather than the cache.

**Reference:** https://ziglang.org/learn/build-system/#run-steps

## Analogies to Familiar Tools

### Comparison to `mise tasks`

If you're familiar with `mise.toml`, think of `build.zig` similarly:

| mise tasks | Zig Build System |
|------------|------------------|
| `[tasks.build]` | `b.step("build", "...")` |
| `depends = ["task1", "task2"]` | `step.dependOn(&other.step)` |
| `run = "command"` | `b.addRunArtifact()` or `b.addSystemCommand()` |
| Task invocation: `mise run build` | Step invocation: `zig build build` |

**Key difference:** `build.zig` constructs a graph before execution, enabling parallelization and caching that `mise` cannot achieve.

### Comparison to `Makefile`

If you're familiar with `make`, here's the mapping:

| Makefile | Zig Build System |
|----------|------------------|
| `target: dependencies` | `step.dependOn(&dependency.step)` |
| `.PHONY: target` | `b.step(name, description)` |
| `$(CC) $(CFLAGS)` | `b.addExecutable(.{ .optimize = optimize })` |
| `make target` | `zig build target` |
| Variables (`CC`, `CFLAGS`) | Options (`b.option()`, `b.standardOptimizeOption()`) |

**Key difference:** Zig's build system is **type-safe**, **cross-platform by default**, and **integrated with the compiler** rather than shelling out to external tools.

## Project Conventions

### Auxiliary Method Requirements

**All auxiliary methods** (helper functions in `build.zig` beyond the main `build()` function) must follow these conventions:

#### 1. Documentation Requirements

Every auxiliary method must have a **docstring** documenting:

- **Purpose** - What the method does
- **Parameters** - Description of each parameter
- **Returns** - What the method returns (if applicable)
- **Preconditions** - Assumptions about inputs (validated with assertions)
- **Postconditions** - Guarantees about outputs (validated with assertions when feasible)
- **Ownership** - Who owns allocated memory (if applicable)
- **Lifetime** - How long pointers/references remain valid (if applicable)

**Example:**

```zig
/// Creates a test step for a specific module with custom configuration.
///
/// Parameters:
/// - b: Build context pointer (borrowed)
/// - name: Test step name (borrowed, must outlive function call)
/// - root_source: Path to test root file
/// - target: Compilation target
///
/// Returns:
/// - Test artifact ready to be added to a run step
///
/// Preconditions:
/// - root_source must point to a valid .zig file
/// - target must be a valid compilation target
///
/// Ownership:
/// - Returned artifact is owned by the build graph
fn createCustomTest(
    b: *std.Build,
    name: []const u8,
    root_source: []const u8,
    target: std.Build.ResolvedTarget,
) *std.Build.Step.Compile {
    assert(name.len > 0); // Validate precondition
    assert(root_source.len > 0); // Validate precondition

    const test_artifact = b.addTest(.{
        .name = name,
        .root_source_file = b.path(root_source),
        .target = target,
    });

    return test_artifact;
}
```

#### 2. Test Coverage Requirements

Auxiliary methods should have tests **when prudent**:

- **Simple wrappers** (thin delegation to stdlib) may not need tests
- **Logic-containing methods** (conditionals, loops, transformations) need tests
- **Complex methods** need comprehensive test coverage

**When to write tests:**

✅ **Do test:**
- Methods with conditional logic
- Methods with loops or iterations
- Methods transforming data structures
- Methods with complex parameter interactions
- Methods performing validation or assertions

❌ **May skip tests:**
- Trivial wrappers around single stdlib calls
- Methods only calling `b.addExecutable()` with fixed parameters
- Simple accessors or property getters

**Example test structure:**

```zig
test "createCustomTest: creates test artifact with correct name" {
    const b = try std.Build.create(
        std.testing.allocator,
        "test",
        .{},
    );
    defer b.destroy();

    const target = b.standardTargetOptions(.{});
    const test_artifact = createCustomTest(
        b,
        "my_test",
        "src/test.zig",
        target,
    );

    try std.testing.expectEqualStrings("my_test", test_artifact.name);
}

test "createCustomTest: handles valid paths" {
    // Test that valid paths are accepted
    const b = try std.Build.create(
        std.testing.allocator,
        "test",
        .{},
    );
    defer b.destroy();

    const target = b.standardTargetOptions(.{});
    const test_artifact = createCustomTest(
        b,
        "test",
        "src/root.zig",
        target,
    );

    try std.testing.expect(test_artifact != null);
}
```

**Note:** Testing build.zig functions can be challenging since they interact with the build system. Focus on testable logic and use assertions for preconditions.

### Documentation Examples from Existing Code

Frost's `src/pattern.zig` demonstrates excellent documentation practices applicable to `build.zig`:

```zig
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
///
/// Lifetime:
/// - input must remain valid for lifetime of returned Match
pub fn match(self: Self, input: []const u8) Match(max_size) {
    return switch (self) {
        .wildcard => |w| w.match(input),
        .character => |c| c.match(input),
        // ... other cases
    };
}
```

Apply this style to `build.zig` auxiliary methods:
- Clear purpose statement
- Explicit preconditions and postconditions
- Ownership and lifetime documentation
- Assertion validation of preconditions

## Review Checklist for build.zig Changes

When reviewing pull requests that modify `build.zig`, verify:

### Correctness
- [ ] **Build graph structure** - Steps correctly depend on their prerequisites
- [ ] **Module configuration** - Target and optimization properly propagated
- [ ] **Artifact installation** - Necessary artifacts marked with `b.installArtifact()`
- [ ] **Top-level steps** - New steps have clear, descriptive names and descriptions
- [ ] **Options** - Custom options have appropriate types and help text

### Code Quality
- [ ] **Auxiliary methods** - All helper functions have complete docstrings
- [ ] **Preconditions** - Input validation with assertions at function entry
- [ ] **Postconditions** - Assertions validate outputs where feasible
- [ ] **Test coverage** - Logic-containing auxiliary methods have tests
- [ ] **Naming conventions** - Follow Zig style guide (camelCase for functions)

### Documentation
- [ ] **Comments** - Complex build logic explained with inline comments
- [ ] **Help text** - Steps and options have descriptive help strings
- [ ] **Examples** - Non-obvious usage patterns documented with examples
- [ ] **References** - Links to official docs for advanced features

### Build System Usage
- [ ] **No shell commands** - Avoid `b.addSystemCommand()` when Zig APIs exist
- [ ] **Cross-platform** - Build works on Linux, macOS, and Windows
- [ ] **Reproducible** - No reliance on environment variables or system state
- [ ] **Cacheable** - Steps properly declare their inputs/outputs for caching

### Testing
- [ ] **Build succeeds** - `zig build` completes without errors
- [ ] **Tests pass** - `zig build test` executes successfully
- [ ] **New steps work** - Custom steps run correctly with `zig build <step-name>`
- [ ] **Options work** - Custom options properly affect build behavior

## Additional Resources

- **Official Zig Build System Guide:** https://ziglang.org/learn/build-system
- **Zig Standard Library Build Module:** https://ziglang.org/documentation/0.15.2/std/#std.Build
- **Zig Style Guide:** https://ziglang.org/documentation/0.15.2/#Style-Guide
- **Frost Safety-Critical Zig Standards:** `.github/instructions/zig.instructions.md`

## Summary

The Zig build system is a powerful, declarative tool for managing compilation. When working with `build.zig`:

1. **Think declaratively** - You're building a graph, not executing commands
2. **Document thoroughly** - Auxiliary methods need complete docstrings
3. **Test wisely** - Cover logic-containing methods, skip trivial wrappers
4. **Review carefully** - Use the checklist to ensure quality and correctness
5. **Reference officially** - Link to https://ziglang.org/learn/build-system when in doubt

By following these conventions, we ensure `build.zig` remains maintainable, understandable, and reliable.

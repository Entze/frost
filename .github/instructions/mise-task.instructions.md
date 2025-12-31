# Mise Task Instructions

---
applyTo: "mise.toml,.mise/tasks/**/*"
---

When generating or improving mise tasks for this project:

## Task Types Overview

Mise supports two types of tasks:

1. **TOML-based tasks** - Defined in `mise.toml` using declarative syntax
2. **File-based tasks** - Defined as executable scripts in `.mise/tasks/` directory

Choose based on complexity:
- **Use TOML tasks** for simple commands, task dependencies, and parameterized tasks
- **Use file-based tasks** for complex logic, multi-step processes, and bash scripting

## TOML-Based Tasks

### Basic Task Structure

```toml
[tasks.task-name]
run = "command to execute"
```

### Task with Dependencies

```toml
[tasks.test]
depends = ["test:*"]  # Run all tasks matching pattern test:*

[tasks."test:zig"]
depends = ["test:zig:*"]  # Run all tasks matching pattern test:zig:*

[tasks."test:zig:root"]
run = "zig test src/root.zig"
```

**Key patterns:**
- Use `:` (colon) for task namespacing (e.g., `test:zig:root`)
- Use `*` (wildcard) in dependencies to match task patterns
- Tasks with dependencies don't need a `run` key - they orchestrate other tasks

### Task with Usage Arguments

For tasks that accept command-line arguments, use the `usage` block:

```toml
[tasks.check]
usage = '''
arg "[paths]" var=#true
flag "--all"
'''
run = '''
{% if usage.all %}
hk check --all
{% else %}
hk check ${usage_paths}
{% endif %}
'''
```

**Usage syntax:**
- `arg "[paths]"` - Define a positional argument (square brackets indicate optional)
- `var=#true` - Allow multiple values (variable length argument list)
- `flag "--all"` - Define a boolean flag
- Use Jinja2-style templating (`{% if %}`, `{{ variable }}`) in `run` block
- Access arguments: `usage.flag_name` for flags, `usage_argument_name` for arguments

**Invocation examples:**
- `mise run check --all` - Runs `hk check --all`
- `mise run check src/main.zig` - Runs `hk check src/main.zig`
- `mise run check src/*.zig` - Runs `hk check src/file1.zig src/file2.zig`

## File-Based Tasks

### Basic File Task Structure

File-based tasks are executable scripts located in `.mise/tasks/` directory. The directory structure creates namespaces:

```
.mise/tasks/
├── ci/
│   └── validate-release-file    # Task name: ci:validate-release-file
├── cd/
│   └── check-release-file        # Task name: cd:check-release-file
└── release/
    ├── do-release                # Task name: release:do-release
    └── organize-artifacts        # Task name: release:organize-artifacts
```

### File Task Template

```bash
#!/usr/bin/env bash
#MISE description="Short description of what this task does"
set -euo pipefail

# Your task implementation here
```

**Required elements:**
- Shebang: `#!/usr/bin/env bash` (first line)
- Description comment: `#MISE description="..."` (second line)
- Error handling: `set -euo pipefail`
  - `-e` - Exit on error
  - `-u` - Exit on undefined variable
  - `-o pipefail` - Exit on pipe failure

### File Task with GitHub Actions Integration

For tasks used in GitHub Actions workflows, use `$GITHUB_OUTPUT` to pass data:

```bash
#!/usr/bin/env bash
#MISE description="Check if RELEASE.txt exists for CD workflow"
set -euo pipefail

if [ -f RELEASE.txt ]; then
  echo "exists=true" >> "$GITHUB_OUTPUT"
  echo "RELEASE.txt found - will trigger release"
else
  echo "exists=false" >> "$GITHUB_OUTPUT"
  echo "RELEASE.txt not found - skipping release"
fi
```

**Pattern:**
- Write outputs to `$GITHUB_OUTPUT` for workflow job outputs
- Always provide user-friendly console messages for debugging

### File Task with Validation

For tasks that validate input or configuration:

```bash
#!/usr/bin/env bash
#MISE description="Validate RELEASE.txt format and content"
set -euo pipefail

if [ ! -f RELEASE.txt ]; then
  echo "ERROR: RELEASE.txt not found"
  exit 1
fi

# Check if file is empty
if [ ! -s RELEASE.txt ]; then
  echo "ERROR: RELEASE.txt exists but is empty"
  exit 1
fi

# Check if first line is MAJOR, MINOR, or PATCH
first_line=$(head --lines=1 RELEASE.txt)
if [[ "$first_line" != "MAJOR" && "$first_line" != "MINOR" && "$first_line" != "PATCH" ]]; then
  echo "ERROR: First line of RELEASE.txt must be exactly one of: MAJOR, MINOR, PATCH"
  echo "Found: $first_line"
  exit 1
fi

echo "RELEASE.txt validation passed"
```

**Validation patterns:**
- Check file existence: `[ -f filename ]`
- Check non-empty file: `[ -s filename ]`
- Read first line: `head --lines=1 filename`
- Provide detailed error messages
- Exit with non-zero status on validation failure

### File Task with Orchestration

For tasks that run multiple other tasks:

```bash
#!/usr/bin/env bash
#MISE description="Orchestrate full release: bump version, update changelog, and clean up"
set -euo pipefail

# Read the bump type from RELEASE.txt and convert to lowercase
bump_type=$(head --lines=1 RELEASE.txt | tr '[:upper:]' '[:lower:]')

# Run bump
bump-my-version bump "$bump_type"

# Run changelog tasks
mise run release:changelog-version-new
mise run release:changelog-release-copy

# Run release-clear
mise run release:release-clear
```

**Orchestration patterns:**
- Call external tools directly (e.g., `bump-my-version`)
- Call other mise tasks with `mise run task:name`
- Process input files to determine behavior
- Execute tasks in sequence for complex workflows

## Project-Specific Patterns

### Tool Usage

This project uses specific tools managed by mise:

- **hk** - Code checker and formatter (custom tool for this project)
  - `hk check --all` - Check all files
  - `hk fix --all` - Fix all files
  - `hk check ${files}` - Check specific files
- **zig** - Programming language and build system
  - `zig build` - Build the project
  - `zig test src/file.zig` - Run tests for a file
- **bump-my-version** - Version management tool
  - `bump-my-version bump major|minor|patch` - Bump version
  - `bump-my-version show current_version` - Get current version

### Task Naming Conventions

Follow these conventions for task names:

- **Top-level tasks** - Single word, no namespace (e.g., `build`, `test`, `check`, `fix`)
- **Category tasks** - Category prefix with colon (e.g., `test:zig`, `test:python`)
- **Specific tasks** - Full path with colons (e.g., `test:zig:root`, `ci:validate-release-file`)
- **Wildcard dependencies** - Use `*` to match patterns (e.g., `test:*` matches all test tasks)

### Common Task Patterns

**Build task:**
```toml
[tasks.build]
run = "zig build"
```

**Test orchestration:**
```toml
[tasks.test]
depends = ["test:*"]

[tasks."test:zig"]
depends = ["test:zig:*"]

[tasks."test:zig:root"]
run = "zig test src/root.zig"
```

**Parameterized task with flags:**
```toml
[tasks.check]
usage = '''
arg "[paths]" var=#true
flag "--all"
'''
run = '''
{% if usage.all %}
hk check --all
{% else %}
hk check ${usage_paths}
{% endif %}
'''
```

## Example Tasks

### Example 1: Simple TOML Build Task

```toml
[tasks.build]
run = "zig build"
```

Invocation: `mise run build`

### Example 2: TOML Task with Dependencies and Wildcards

```toml
[tasks.test]
depends = ["test:*"]

[tasks."test:zig"]
depends = ["test:zig:*"]

[tasks."test:zig:root"]
run = "zig test src/root.zig"

[tasks."test:zig:main"]
run = "zig test src/main.zig"

[tasks."test:zig:pattern"]
run = "zig test src/pattern.zig"
```

Invocation: `mise run test` runs all test tasks in order

### Example 3: TOML Task with Usage Arguments

```toml
[tasks.check]
usage = '''
arg "[paths]" var=#true
flag "--all"
'''
run = '''
{% if usage.all %}
hk check --all
{% else %}
hk check ${usage_paths}
{% endif %}
'''
```

Invocations:
- `mise run check --all`
- `mise run check src/main.zig src/pattern.zig`

### Example 4: File-Based Task with Validation

```bash
#!/usr/bin/env bash
#MISE description="Validate RELEASE.txt format and content"
set -euo pipefail

if [ ! -f RELEASE.txt ]; then
  echo "ERROR: RELEASE.txt not found"
  exit 1
fi

if [ ! -s RELEASE.txt ]; then
  echo "ERROR: RELEASE.txt exists but is empty"
  exit 1
fi

first_line=$(head --lines=1 RELEASE.txt)
if [[ "$first_line" != "MAJOR" && "$first_line" != "MINOR" && "$first_line" != "PATCH" ]]; then
  echo "ERROR: First line must be MAJOR, MINOR, or PATCH"
  echo "Found: $first_line"
  exit 1
fi

echo "RELEASE.txt validation passed"
```

Location: `.mise/tasks/ci/validate-release-file`
Invocation: `mise run ci:validate-release-file`

### Example 5: File-Based Task with GitHub Actions Output

```bash
#!/usr/bin/env bash
#MISE description="Check if RELEASE.txt exists for CD workflow"
set -euo pipefail

if [ -f RELEASE.txt ]; then
  echo "exists=true" >> "$GITHUB_OUTPUT"
  echo "RELEASE.txt found - will trigger release"
else
  echo "exists=false" >> "$GITHUB_OUTPUT"
  echo "RELEASE.txt not found - skipping release"
fi
```

Location: `.mise/tasks/cd/check-release-file`
Invocation: `mise run cd:check-release-file` (typically in GitHub Actions)

### Example 6: File-Based Task with Orchestration

```bash
#!/usr/bin/env bash
#MISE description="Orchestrate full release: bump version, update changelog, and clean up"
set -euo pipefail

# Read the bump type from RELEASE.txt
bump_type=$(head --lines=1 RELEASE.txt | tr '[:upper:]' '[:lower:]')

# Run version bump
bump-my-version bump "$bump_type"

# Run changelog tasks
mise run release:changelog-version-new
mise run release:changelog-release-copy

# Clean up release file
mise run release:release-clear
```

Location: `.mise/tasks/release/do-release`
Invocation: `mise run release:do-release`

## Testing Tasks

To test a mise task:

```bash
# Test TOML task
mise run task-name

# Test file-based task
mise run category:task-name

# Test with arguments
mise run task-name --flag arg1 arg2

# Dry-run to see what would be executed
mise run --dry-run task-name
```

## Best Practices

- **Keep tasks focused** - Each task should do one thing well
- **Use descriptive names** - Task names should clearly indicate purpose
- **Document with descriptions** - Use `#MISE description="..."` for file tasks
- **Handle errors explicitly** - Use `set -euo pipefail` in bash scripts
- **Provide helpful output** - Echo messages to show progress and errors
- **Use dependencies wisely** - Chain tasks with `depends` for complex workflows
- **Test tasks independently** - Each task should be runnable on its own
- **Use wildcards for groups** - Simplify task orchestration with pattern matching

## References

- **Mise Task Documentation**
  - [Task configuration](https://mise.jdx.dev/tasks/task-configuration.html)
  - [TOML-based tasks](https://mise.jdx.dev/tasks/toml-tasks.html)
  - [File-based tasks](https://mise.jdx.dev/tasks/file-tasks.html)
  - [Task arguments and usage](https://mise.jdx.dev/tasks/task-arguments.html)

- **Project Documentation**
  - [mise.toml](../../mise.toml) - TOML-based task definitions
  - [.mise/tasks/](../../.mise/tasks/) - File-based task scripts
  - [CONTRIBUTING.md](../../CONTRIBUTING.md) - Development workflow and conventions

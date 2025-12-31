# Mise Task Instructions

---
applyTo: "mise.toml,.mise/tasks/**/*"
---

When generating or improving mise tasks for this project:

## Task Types Overview

Choose based on complexity:
- **3 lines or less** → Use TOML-based tasks in `mise.toml`
- **More than 3 lines** → Use file-based tasks in `.mise/tasks/`

## TOML-Based Tasks

For simple commands, use TOML syntax in `mise.toml`:

```toml
[tasks.build]
run = "zig build"

[tasks.test]
depends = ["test:*"]  # Run all matching tasks

[tasks."test:zig:root"]
run = "zig test src/root.zig"
```

### Task Properties

TOML tasks support various properties beyond `run`:

```toml
[tasks.example]
description = "Human-readable description shown in mise tasks"
alias = "ex"                    # Short alias: mise run ex
depends = ["build", "test"]     # Run these tasks first
env = { DEBUG = "1" }          # Environment variables
dir = "subdir"                 # Run in this directory
hide = true                    # Hide from mise tasks list
raw = true                     # Pass stdin/stdout directly (for interactive tasks)
sources = ["src/**/*.zig"]     # Re-run if these files change
outputs = ["zig-out/bin/*"]    # Skip if outputs are newer than sources
```

See [task configuration docs](https://mise.jdx.dev/tasks/task-configuration.html) for full details.

### Task with Arguments

For tasks accepting command-line arguments, use the `usage` block with Jinja2 templating:

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

**Complex usage patterns** (see [task arguments docs](https://mise.jdx.dev/tasks/task-arguments.html)):

```toml
[tasks.deploy]
usage = '''
arg "<environment>"              # Required positional arg
arg "[region]" default="us-west" # Optional with default
flag "-f --force"                # Boolean flag with short/long form
flag "--dry-run"                 # Long-form only flag
option "--timeout <seconds>"     # Option requiring a value
'''
run = '''
{% if usage.force %}
echo "Force deploying to {{ usage.environment }}"
{% else %}
echo "Deploying to {{ usage.environment }} in {{ usage.region }}"
{% endif %}
{% if usage.timeout %}
echo "Timeout: {{ usage.timeout }}s"
{% endif %}
'''
```

Access arguments as:
- `{{ usage.environment }}` - Required positional
- `{{ usage.region }}` - Optional positional (defaults handled in usage)
- `{% if usage.force %}` - Boolean flags
- `{{ usage.timeout }}` - Options with values

## File-Based Tasks

For complex logic, create executable bash scripts in `.mise/tasks/`:

```bash
#!/usr/bin/env bash
#MISE description="Short description of what this task does"
#MISE depends=["build", "test"]
#MISE sources=["src/**/*.zig"]
#MISE outputs=["zig-out/bin/*"]
#MISE env={DEBUG="1", VERBOSE="true"}
set -euo pipefail

# Your task implementation here
```

**File task properties** (use `#MISE key=value` comments):
- `description` - Human-readable description
- `depends` - Array of task dependencies
- `sources` - Glob patterns for input files
- `outputs` - Glob patterns for output files (skip if newer than sources)
- `env` - Environment variables as inline table
- `dir` - Working directory for the task

**Usage configuration in file tasks** (see [task arguments docs](https://mise.jdx.dev/tasks/task-arguments.html)):

```bash
#!/usr/bin/env bash
#MISE description="Deploy with arguments"
#MISE usage=<<EOF
arg "<environment>"
flag "--dry-run"
option "--timeout <seconds>" default="300"
EOF
set -euo pipefail

# Access via environment variables:
# - $1, $2, etc. for positional args
# - $USAGE_DRY_RUN for flags (true/false)
# - $USAGE_TIMEOUT for options

if [ "${USAGE_DRY_RUN:-false}" = "true" ]; then
  echo "Dry run mode"
fi
echo "Deploying to $1 with timeout ${USAGE_TIMEOUT}s"
```

**Directory structure creates namespaces:**
- `.mise/tasks/ci/validate-release-file` → `mise run ci:validate-release-file`
- `.mise/tasks/release/do-release` → `mise run release:do-release`

### GitHub Actions Integration

Use `$GITHUB_OUTPUT` for workflow outputs:

```bash
if [ -f RELEASE.txt ]; then
  echo "exists=true" >> "$GITHUB_OUTPUT"
fi
```

## Project Tools

- **hk** - Code checker/formatter: `hk check --all`, `hk fix --all`
- **zig** - Build system: `zig build`, `zig test src/file.zig`
- **bump-my-version** - Version management: `bump-my-version bump patch`

## References

- [Task configuration](https://mise.jdx.dev/tasks/task-configuration.html)
- [TOML-based tasks](https://mise.jdx.dev/tasks/toml-tasks.html)
- [File-based tasks](https://mise.jdx.dev/tasks/file-tasks.html)
- [Task arguments](https://mise.jdx.dev/tasks/task-arguments.html)

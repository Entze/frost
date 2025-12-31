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

### Task with Arguments

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

## File-Based Tasks

For complex logic, create executable bash scripts in `.mise/tasks/`:

```bash
#!/usr/bin/env bash
#MISE description="Short description of what this task does"
set -euo pipefail

# Your task implementation here
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

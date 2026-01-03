# Contributing to Frost

Thank you for your interest in contributing to Frost! This document provides guidelines and information about our development process.

## Development Setup

### Requirements

- Zig 0.15.2
- [mise](https://mise.jdx.dev/) (for task running and dev-dependency management)

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/Entze/frost.git
   cd frost
   ```

2. Install dependencies (mise will handle this automatically):
   ```bash
   mise install
   ```

3. Build the project:
   ```bash
   mise run build
   ```

4. Run tests:
   ```bash
   mise run test
   ```

## Building

### Building Executables

Build the executable (output: `frost-{os}-{arch}[-{abi}]`):

```bash
zig build              # Default: build and install executable
zig build exe          # Explicitly build executable
# or using mise
mise run build:exe
mise run build:exe -- --optimize ReleaseFast
```

Configure target and optimization:

```bash
# Using zig build directly
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSmall
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast

# Using mise tasks with options
mise run build:exe -- --optimize ReleaseSmall --target x86_64-linux-musl
```

### Building Libraries

Build libraries (output: `libfrost-{os}-{arch}[-{abi}].{a|so|dylib}` or `frost-{os}-{arch}[-{abi}].{lib|dll}` on Windows):

```bash
zig build lib-static   # Build static library
zig build lib-dynamic  # Build dynamic/shared library
# or using mise
mise run build:lib-static
mise run build:lib-dynamic
mise run build:lib-static -- --optimize ReleaseFast --target aarch64-macos
```

### Release Builds

Build for release (all supported targets: Linux x86_64/aarch64 musl/gnu, macOS x86_64/aarch64, Windows x86_64/aarch64 gnu):

```bash
zig build release                           # Build for all supported targets (ReleaseFast)
zig build release -Drelease-profile=Debug   # Use Debug profile
# or using mise
mise run release
```

### Build Options

Available options for build commands:

- `--optimize <mode>`: Optimization profile
  - `Debug` (default)
  - `ReleaseSafe`
  - `ReleaseFast`
  - `ReleaseSmall`
- `--target <triple>`: Target platform (e.g., `x86_64-linux-musl`, `aarch64-macos`)
- `--cpu <features>`: CPU feature flags

### Other Build Tasks

```bash
# Generate documentation
mise run docs
```

## Testing

Run the test suite:

```bash
zig build test         # Run all tests
mise run test          # Alternative using mise
```

### Incremental Testing with mise

Mise tasks support incremental execution through `sources` and `outputs` metadata. When sources haven't changed, tasks are automatically skipped:

```bash
mise run test:zig:pattern  # First run: executes tests (625ms)
mise run test:zig:pattern  # Second run: skipped (21ms) - 30x faster!
```

This dramatically speeds up development workflows. To force a fresh run, modify a source file or clear the cache:

```bash
touch src/pattern.zig       # Trigger rebuild for specific module
rm -rf ~/.local/state/mise/task-auto-outputs/*  # Clear all caches
```

## Code Quality

### Formatting and Checks

Before committing, always run:

```bash
# Run checks
mise run check --all

# Fix formatting and style issues
mise run fix --all
```

### Code Style

- Follow the Zig zen principles
- Use descriptive variable and function names
- Write clear comments for complex logic
- Ensure all tests pass before submitting

## Mise Task Guidelines

When creating or modifying mise tasks, follow these metadata standards:

### Required Metadata

All tasks must have:
- **`description`** - Clear, concise explanation of what the task does

### Optional Metadata (when applicable)

Add these fields based on task functionality:

- **`sources`** - Input files that trigger task re-execution when modified
  - Use for: build tasks, test tasks, format/check tasks
  - Example: `sources = ["src/**/*.zig", "build.zig"]`
  - **Do not use** for tasks with dynamic input paths (via arguments)

- **`outputs`** - Generated files that indicate task completion
  - Use for: build tasks, documentation generation
  - Example: `outputs = ["zig-out/bin/*"]`
  - Mise auto-generates outputs for tasks with sources but no outputs

- **`usage`** - CLI argument specification for parameterized tasks
  - Use for: tasks accepting flags, options, or positional arguments
  - Provides `--help` text and type-safe argument parsing
  - Example:
    ```toml
    usage = '''
    arg "[paths]" var=#true
    flag "--all"
    '''
    ```

### Task Caching Benefits

Properly configured `sources` and `outputs` enable:
- **Incremental builds** - Skip unchanged tasks automatically
- **Faster iteration** - 10-30x speedup for cached tasks
- **Smart rebuilds** - Only rerun when inputs actually change

### Examples

**TOML Task with Full Metadata:**
```toml
[tasks."build:exe"]
description = "Build the executable"
sources = ["src/**/*.zig", "build.zig", "build.zig.zon"]
outputs = ["zig-out/bin/frost-*"]
usage = '''
flag "--optimize <mode>" help="Optimization profile" {
  choices "Debug" "ReleaseSafe" "ReleaseFast" "ReleaseSmall"
}
'''
run = "zig build exe --summary all{% if usage.optimize %} -Doptimize={{ usage.optimize }}{% endif %}"
```

**File Task with Metadata:**
```bash
#!/usr/bin/env bash
#MISE description="Generate SHA256 checksums for all release artifacts"
#MISE sources=["release-artifacts/*"]
#MISE outputs=["release-artifacts/CHECKSUMS.txt"]
set -euo pipefail
# ... task implementation
```

See [.github/instructions/mise-task.instructions.md](.github/instructions/mise-task.instructions.md) for comprehensive documentation.

## Release Process

Frost uses an automated continuous delivery (CD) pipeline inspired by [Hypothesis's continuous release strategy](https://hypothesis.works/articles/continuous-releases/).

### Signaling Release Intent

To trigger a release, add a `RELEASE.txt` file to your pull request:

1. **Create the file** in the repository root: `RELEASE.txt`

2. **First line**: Specify the version bump type (one of):
   - `MAJOR` - For breaking changes (currently not used pre-1.0.0)
   - `MINOR` - For new features or significant changes
   - `PATCH` - For bug fixes or minor improvements

3. **Subsequent lines**: Provide a short but precise plain-text description of changes
   - Each item typically begins with: "Added", "Introduced", "Deprecated", "Removed", "Changed", "Improved", "Reworked", or similar action verbs
   - Be concise but descriptive
   - Focus on user-facing changes

### Example RELEASE.txt

```
MINOR
- Introduced continuous delivery pipeline
- Added automated version management
- Improved changelog generation
```

or

```
PATCH
- Fixed memory leak in CNF parser
- Improved error messages for invalid input
```

### What Happens After Merge

When your pull request with `RELEASE.txt` is merged to `main`:

1. **CD Pipeline Triggers**: The `cd.yaml` workflow detects the `RELEASE.txt` file
2. **Version Bump**: The version in `build.zig.zon` is automatically incremented
3. **Changelog Update**: Release notes from `RELEASE.txt` are added to `CHANGELOG.md`
4. **Git Tag**: A version tag (e.g., `v0.1.0`) is created and pushed
5. **Release Build**: Artifacts are built for Linux, macOS, and Windows
6. **GitHub Release**: A release is created with artifacts, checksums, and changelog notes

### CI Validation

During pull request review, CI automatically validates your `RELEASE.txt`:
- Ensures the file is not empty
- Verifies the first line is exactly `MAJOR`, `MINOR`, or `PATCH`
- Checks formatting

If validation fails, fix the issues and push an update.

### Pre-1.0.0 Versioning Note

While Frost is pre-1.0.0, we use `MINOR` for significant changes and `PATCH` for bug fixes. `MAJOR` is reserved for the 1.0.0 release.

## Pull Request Guidelines

1. **Create a feature branch** from `main`
2. **Make focused changes** - one feature or fix per PR
3. **Add tests** for new functionality
4. **Update documentation** if needed
5. **Run checks** before submitting: `mise run check --all && mise run fix --all`
6. **Add RELEASE.txt** if your changes should trigger a release
7. **Write clear PR descriptions** explaining what and why

## Project Documentation

- **[ROADMAP.md](ROADMAP.md)** - Strategic direction and planned features
- **[CHANGELOG.md](CHANGELOG.md)** - History of changes and releases

## Questions or Issues?

If you have questions or run into issues:
- Open an issue on GitHub
- Check existing issues for similar problems
- Review the [README.md](README.md) for basic usage information

## License

By contributing to Frost, you agree that your contributions will be licensed under the GPL-3.0 license.

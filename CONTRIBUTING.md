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

### Available Build Tasks

Frost exposes Zig build steps as mise tasks with configurable options:

#### Building Executables

```bash
# Build executable with default settings (Debug)
mise run build:exe

# Build with specific optimization profile
mise run build:exe -- --optimize ReleaseFast

# Build for specific target
mise run build:exe -- --target x86_64-linux-musl

# Combine multiple options
mise run build:exe -- --optimize ReleaseSafe --target aarch64-macos
```

#### Building Libraries

```bash
# Build static library
mise run build:lib-static

# Build dynamic/shared library
mise run build:lib-dynamic

# Build with custom options
mise run build:lib-static -- --optimize ReleaseFast --target x86_64-windows-gnu
```

#### Other Build Tasks

```bash
# Generate documentation
mise run docs

# Run all tests
mise run test

# Build release artifacts for all supported platforms
mise run release
```

#### Build Options

- `--optimize <mode>`: Optimization profile
  - `Debug` (default)
  - `ReleaseSafe`
  - `ReleaseFast`
  - `ReleaseSmall`
- `--target <triple>`: Target platform (e.g., `x86_64-linux-musl`, `aarch64-macos`)
- `--cpu <features>`: CPU feature flags

## Development Workflow

### Before Committing

Always run these commands before committing:

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

## Questions or Issues?

If you have questions or run into issues:
- Open an issue on GitHub
- Check existing issues for similar problems
- Review the [README.md](README.md) for basic usage information

## License

By contributing to Frost, you agree that your contributions will be licensed under the GPL-3.0 license.

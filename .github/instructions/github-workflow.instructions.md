# GitHub Actions Workflow Instructions

---
applyTo: ".github/workflows/**/*.yml,.github/workflows/**/*.yaml"
---

When generating or improving GitHub Actions workflows for this project:

## Security First

- **Use GitHub secrets for sensitive data** - Never hardcode credentials or tokens
- **Pin third-party actions to specific commits** - Use the full SHA value (40 characters) for security and reproducibility
  - Example: `uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11` (not `@v4`)
  - Exception: First-party GitHub actions (e.g., `actions/*`) may use semantic versioning tags
- **Configure minimal permissions for GITHUB_TOKEN** - Explicitly declare only the permissions required for each job
  - Default to `contents: read` for most jobs
  - Add `contents: write` only when pushing commits or creating releases
  - Add `actions: write` only when managing workflow runs or cache

## Performance Essentials

- **Add timeout-minutes to all jobs** - Prevent hung workflows from consuming runner resources
  - Typical timeouts: 5 minutes for checks, 10 minutes for builds/tests, 15 minutes for releases
  - Example: `timeout-minutes: 10`
- **Cache dependencies with mise-action** - This project uses mise for tool management
  - Enable caching with `cache: true` in `jdx/mise-action@v3`
  - Disable caching with `cache: false` for jobs that don't need tools
- **Use matrix strategies for multi-environment testing** - Test on multiple OS platforms
  - Common matrix: `os: [ubuntu-latest, macos-latest, windows-latest]`
  - Include OS-specific configuration when needed (see artifact naming example below)

## Best Practices

- **Use descriptive names** - Name workflows, jobs, and steps clearly
  - Workflow name: `name: CI` (top-level, appears in GitHub UI)
  - Job name: `name: Build` (describes what the job does)
  - Step name: `name: Run tests` (describes the action being performed)
- **Include appropriate triggers** - Use relevant event types
  - `push: branches: [main]` - Run on direct pushes to main (CD workflows)
  - `pull_request: branches: [main]` - Run on PRs targeting main (CI workflows)
  - `workflow_dispatch` - Allow manual triggering for maintenance tasks
  - `schedule: cron: "0 3 * * *"` - Run on a schedule (daily maintenance)
- **Use conditional execution** - Control when jobs or steps run
  - `if: needs.job-name.outputs.value == 'true'` - Run job based on previous job output
  - `if: always()` - Always run cleanup steps, even if previous steps fail
  - `continue-on-error: true` - Allow step to fail without failing the entire job
- **Manage dependencies between jobs** - Use `needs` to establish execution order
  - Example: `needs: check` - Job waits for "check" job to complete
  - Multiple dependencies: `needs: [release, build]`

## Project-Specific Patterns

### Mise Integration

This project uses [mise](https://mise.jdx.dev/) for tool version management. Always include the mise setup step:

```yaml
- uses: jdx/mise-action@v3
  with:
    install: true        # Install tools defined in .mise.toml
    cache: true          # Cache mise tools for faster workflows
    experimental: true   # Enable experimental features
```

Set `install: false` and `cache: false` for jobs that only need to run mise tasks without tool dependencies.

### Checkout Configuration

For release workflows that need full git history:

```yaml
- uses: actions/checkout@v6
  with:
    fetch-depth: 0  # Fetch all history for versioning tools
```

For most CI jobs, use the default shallow clone:

```yaml
- uses: actions/checkout@v6
```

### Release Automation

This project uses a `RELEASE.txt` file to trigger releases. The CD workflow:

1. Checks for `RELEASE.txt` existence
2. Validates its format (first line must be `MAJOR`, `MINOR`, or `PATCH`)
3. Runs release tasks via mise (`mise run release:do-release`)
4. Commits version bumps and tags the release
5. Builds artifacts for multiple platforms
6. Creates a GitHub release with artifacts and checksums

Key patterns:
- Use job outputs to pass data between jobs: `outputs: version: ${{ steps.version.outputs.version }}`
- Use `ref: "v${{ needs.release.outputs.version }}"` to checkout the tagged release
- Use matrix includes for OS-specific artifact naming

## Example Workflows

### Example 1: CI Workflow with Multi-OS Matrix Testing

```yaml
name: CI
on:
  pull_request:
    branches:
      - main

jobs:
  check:
    name: Check
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
      - uses: jdx/mise-action@v3
        with:
          install: true
          cache: true
          experimental: true

      - name: Run check
        run: mise run check --all

  build:
    name: Build
    needs: check
    runs-on: ${{ matrix.os }}
    timeout-minutes: 10
    permissions:
      contents: read
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:
      - uses: actions/checkout@v6
      - uses: jdx/mise-action@v3
        with:
          install: true
          cache: true
          experimental: true

      - name: Run build
        run: mise run build

  test:
    name: Test
    needs: build
    runs-on: ${{ matrix.os }}
    timeout-minutes: 10
    permissions:
      contents: read
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:
      - uses: actions/checkout@v6
      - uses: jdx/mise-action@v3
        with:
          install: true
          cache: true
          experimental: true

      - name: Run tests
        run: mise run test
```

### Example 2: Conditional Release with Artifact Upload

```yaml
name: CD

on:
  push:
    branches:
      - main

jobs:
  check-release:
    name: Check for RELEASE.txt
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
    outputs:
      should-release: ${{ steps.check.outputs.exists }}
    steps:
      - uses: actions/checkout@v6

      - uses: jdx/mise-action@v3
        with:
          install: false
          cache: false
          experimental: true

      - name: Check if RELEASE.txt exists
        id: check
        run: mise run cd:check-release-file

  release:
    name: Release
    needs: check-release
    if: needs.check-release.outputs.should-release == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: write
    outputs:
      version: ${{ steps.version.outputs.version }}
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - uses: jdx/mise-action@v3
        with:
          install: true
          cache: true
          experimental: true

      - name: Run release task
        run: mise run release:do-release

      - name: Get new version
        id: version
        run: |
          version=$(bump-my-version show current_version)
          echo "version=$version" >> "$GITHUB_OUTPUT"

      - name: Commit and push changes
        uses: EndBug/add-and-commit@v9
        with:
          message: "Bump version to ${{ steps.version.outputs.version }}"
          default_author: github_actions
          github_token: ${{ secrets.GITHUB_TOKEN }}
          push: true
          tag: "v${{ steps.version.outputs.version }}"

  build:
    name: Build on ${{ matrix.os }}
    needs: release
    runs-on: ${{ matrix.os }}
    timeout-minutes: 15
    permissions:
      contents: read
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        include:
          - os: ubuntu-latest
            artifact_name: frost-linux
            artifact_path: zig-out/bin/frost
          - os: macos-latest
            artifact_name: frost-macos
            artifact_path: zig-out/bin/frost
          - os: windows-latest
            artifact_name: frost-windows.exe
            artifact_path: zig-out/bin/frost.exe
    steps:
      - uses: actions/checkout@v6
        with:
          ref: "v${{ needs.release.outputs.version }}"

      - uses: jdx/mise-action@v3
        with:
          install: true
          cache: true
          experimental: true

      - name: Build
        run: mise run build

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact_name }}
          path: ${{ matrix.artifact_path }}
          if-no-files-found: error
```

### Example 3: Manual Workflow Dispatch with Auto-Commit

```yaml
name: Fix
on: workflow_dispatch

permissions:
  actions: write
  contents: write

jobs:
  fix:
    name: Fix
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v6
      - uses: jdx/mise-action@v3
        with:
          install: true
          cache: true
          experimental: true

      - name: Run fix
        run: mise run fix --all

      - name: Commit
        uses: EndBug/add-and-commit@v9
        with:
          message: "Apply 'mise run fix --all'"
          github_token: ${{ secrets.GITHUB_TOKEN }}
          push: true
```

## References

- **GitHub Actions Documentation**
  - [Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
  - [Security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
  - [Using jobs](https://docs.github.com/en/actions/using-jobs)
  - [Caching dependencies](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)

- **Third-Party Actions**
  - [jdx/mise-action](https://github.com/jdx/mise-action) - Mise tool version manager
  - [EndBug/add-and-commit](https://github.com/EndBug/add-and-commit) - Automated git commits
  - [softprops/action-gh-release](https://github.com/softprops/action-gh-release) - GitHub release creation

- **Project Documentation**
  - [CONTRIBUTING.md](../../CONTRIBUTING.md) - Release process and version management

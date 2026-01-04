# Mise Task Behavior Specification

This document describes the current behavior of each mise task script that will be migrated to Zig.

## Overview

The project currently has 11 Unix-based shell scripts for release management and CI/CD automation. These scripts handle:
- RELEASE.txt file validation and checking
- Version bumping and changelog management
- Release orchestration
- Artifact organization and checksum generation

## Task Specifications

### 1. cd:check-release-file

**Purpose**: Check if RELEASE.txt exists for CD workflow

**Inputs**:
- Checks for existence of `RELEASE.txt` file in current directory

**Outputs**:
- Sets `exists=true` or `exists=false` in `$GITHUB_OUTPUT`
- Prints message to stdout indicating whether file was found

**Behavior**:
- If RELEASE.txt exists: output `exists=true` to GITHUB_OUTPUT, print "RELEASE.txt found - will trigger release"
- If RELEASE.txt does not exist: output `exists=false` to GITHUB_OUTPUT, print "RELEASE.txt not found - skipping release"
- Always exits with code 0 (success)

**Error Handling**:
- No error cases (always succeeds)

---

### 2. ci:validate-release-file

**Purpose**: Validate RELEASE.txt format and content for CI

**Inputs**:
- Reads `RELEASE.txt` file in current directory

**Outputs**:
- Prints validation messages to stdout
- Exits with code 0 on success, code 1 on validation failure

**Behavior**:
1. Check if RELEASE.txt exists
   - If missing: print "ERROR: RELEASE.txt not found", exit 1
2. Check if file is empty
   - If empty: print "ERROR: RELEASE.txt exists but is empty", exit 1
3. Check if first line is exactly one of: MAJOR, MINOR, PATCH
   - If invalid: print "ERROR: First line of RELEASE.txt must be exactly one of: MAJOR, MINOR, PATCH" and "Found: {first_line}", exit 1
4. If all checks pass: print "RELEASE.txt validation passed", exit 0

**Error Handling**:
- File not found: ERROR message, exit 1
- File empty: ERROR message, exit 1
- Invalid first line: ERROR message with details, exit 1

---

### 3. release:changelog-release-copy

**Purpose**: Copy release notes from RELEASE.txt to CHANGELOG.md

**Inputs**:
- `RELEASE.txt` (lines 2+)
- `CHANGELOG.md` (existing changelog)

**Outputs**:
- Modified `CHANGELOG.md` with release notes inserted

**Behavior**:
1. Extract lines 2+ from RELEASE.txt (skipping first line which is bump type)
2. Find the first `## ` heading in CHANGELOG.md
3. Insert release notes after that heading with blank line before
4. Write back to CHANGELOG.md

**Implementation Details**:
- Uses temporary files for safe manipulation
- Inserts content between first version header and subsequent content
- Preserves all existing changelog content

**Error Handling**:
- Uses `set -euo pipefail` to exit on errors
- Cleans up temporary files on exit via trap

---

### 4. release:changelog-version-new

**Purpose**: Insert new version header with current date into CHANGELOG.md

**Inputs**:
- `CHANGELOG.md` (existing changelog)
- `.bumpversion.toml` (to get current version via bump-my-version)

**Outputs**:
- Modified `CHANGELOG.md` with new version header inserted

**Behavior**:
1. Get current version from `bump-my-version show current_version`
2. Generate header in format: `## {version} ({YYYY-MM-DD})`
3. Insert header before first existing version header (## heading)
4. Ensure exactly one blank line between abstract and first version header
5. If no version headers exist, append at end

**Implementation Details**:
- Uses AWK script to manage whitespace precisely
- Buffers content before first version header
- Removes trailing blank lines from buffer
- Adds exactly one blank line before new header
- Complex logic to prevent whitespace accumulation

**Error Handling**:
- Uses `set -euo pipefail` to exit on errors
- Cleans up temporary file on exit via trap

---

### 5. release:do-release

**Purpose**: Orchestrate full release process

**Inputs**:
- `RELEASE.txt` (first line for bump type)
- `CHANGELOG.md`
- `.bumpversion.toml`
- `build.zig.zon`

**Outputs**:
- Modified `CHANGELOG.md` (via delegated tasks)
- Modified `build.zig.zon` (via bump-my-version)
- Deleted `RELEASE.txt` (via release-clear)

**Behavior**:
1. Read first line of RELEASE.txt
2. Convert to lowercase (MAJOR -> major, MINOR -> minor, PATCH -> patch)
3. Run `bump-my-version bump {bump_type}`
4. Run `mise run release:changelog-version-new`
5. Run `mise run release:changelog-release-copy`
6. Run `mise run release:release-clear`

**Implementation Details**:
- Sequential orchestration of multiple tasks
- Uses tr command for case conversion

**Error Handling**:
- Uses `set -euo pipefail` to exit on any sub-task failure

---

### 6. release:extract-changelog

**Purpose**: Extract changelog section for specific release version

**Inputs**:
- Command-line argument: path to changelog file (default: "CHANGELOG.md")
- Environment variable `VERSION` (preferred) or `GITHUB_REF` (fallback)
- Changelog file content

**Outputs**:
- `release_notes.txt` file with extracted section
- Prints extracted section to stdout

**Behavior**:
1. Determine version:
   - If VERSION env var is set, use it
   - Else if GITHUB_REF is set, extract version from tag (refs/tags/v{version})
   - Else error: "Error: VERSION environment variable or GITHUB_REF must be set"
2. Print: "Extracting changelog for version {version}"
3. Use AWK to extract section:
   - Find line matching `## ` and containing version
   - Collect all lines until next `## ` heading
   - Stop at next heading or end of file
4. If extracted section is empty, write "Release v{version}" as default
5. Write to release_notes.txt
6. Print content to stdout

**Implementation Details**:
- Uses AWK with version variable to find matching section
- Handles case where version section is empty
- Explicit VERSION takes priority over GITHUB_REF (for CI scenarios)

**Error Handling**:
- Missing VERSION and GITHUB_REF: error message to stderr, exit 1
- Uses `set -euo pipefail` for other errors
- Cleans up temporary file on exit via trap

---

### 7. release:generate-checksums

**Purpose**: Generate SHA256 checksums for all release artifacts

**Inputs**:
- `release-artifacts/` directory containing artifact files

**Outputs**:
- `release-artifacts/CHECKSUMS.txt` with SHA256 checksums
- Prints checksums to stdout

**Behavior**:
1. Change to release-artifacts directory
2. Check if directory has files (using `ls --almost-all`)
3. If files exist:
   - Generate SHA256 checksums for all files: `sha256sum -- * > CHECKSUMS.txt`
   - Print CHECKSUMS.txt to stdout
4. If no files:
   - Print "Warning: No artifacts found to generate checksums"
   - Exit 1

**Implementation Details**:
- Uses `sha256sum` command with `-- *` to handle all files
- Works in release-artifacts directory

**Error Handling**:
- No artifacts: warning message, exit 1
- Uses `set -euo pipefail` for command errors

---

### 8. release:organize-artifacts

**Purpose**: Organize downloaded artifacts into release-artifacts directory

**Inputs**:
- `artifacts/` directory tree with artifact files

**Outputs**:
- `release-artifacts/` directory with flattened artifact files
- Prints ls output showing organized artifacts

**Behavior**:
1. Create release-artifacts directory (with parents if needed)
2. Find all files in artifacts tree and copy to release-artifacts (flattening structure)
3. List all files in release-artifacts with details

**Implementation Details**:
- Uses `find artifacts -type f -exec cp --verbose {} release-artifacts/ \;`
- Flattens directory structure (all files moved to single level)
- Uses `ls --all -l --human-readable` for final listing

**Error Handling**:
- Uses `set -euo pipefail` to exit on errors

---

### 9. release:release-clear

**Purpose**: Delete RELEASE.txt file

**Inputs**:
- `RELEASE.txt` file (if exists)

**Outputs**:
- Deleted RELEASE.txt file

**Behavior**:
- Run `rm --force RELEASE.txt` to delete file
- Force flag ensures no error if file doesn't exist

**Implementation Details**:
- Simple cleanup task
- Idempotent (safe to run multiple times)

**Error Handling**:
- Uses `set -euo pipefail`
- Force flag prevents errors on missing file

---

### 10. release:test-changelog-version-new

**Purpose**: Test that changelog-version-new correctly manages whitespace

**Inputs**:
- None (creates test environment)

**Outputs**:
- Test result messages to stdout
- Exit 0 on success, exit 1 on failure

**Behavior**:
1. Create test directory with mock CHANGELOG.md and .bumpversion.toml
2. Run changelog-version-new task
3. Verify exactly 1 blank line between abstract and first version header
4. Verify new version header was inserted correctly
5. Run again with updated version
6. Verify whitespace doesn't accumulate after second run

**Test Cases**:
- Initial insertion preserves exactly 1 blank line
- New version header has correct format
- Multiple runs don't accumulate whitespace

**Implementation Details**:
- Uses AWK to count blank lines precisely
- Uses grep with date to verify header format
- Creates isolated test environment

**Error Handling**:
- Fails on any test assertion failure
- Cleans up test directory on exit via trap

---

### 11. release:test-extract-changelog

**Purpose**: Test that extract-changelog correctly extracts version sections

**Inputs**:
- None (creates test environment)

**Outputs**:
- Test result messages to stdout
- Exit 0 on success, exit 1 on failure

**Behavior**:
1. Create test CHANGELOG.md with multiple versions
2. Test extraction of version 0.2.0 via GITHUB_REF
3. Verify correct lines extracted and others excluded
4. Test extraction of version 0.1.9 via GITHUB_REF
5. Test extraction with explicit VERSION env var (simulating CI)
6. Test extraction of version 0.1.8 with explicit VERSION

**Test Cases**:
- GITHUB_REF-based extraction works correctly
- VERSION-based extraction works correctly (CI scenario)
- Only target version's content is extracted
- Other versions' content is excluded

**Implementation Details**:
- Creates mock changelog with known content
- Tests multiple extraction scenarios
- Uses grep to verify presence/absence of expected content

**Error Handling**:
- Fails on any test assertion failure
- Cleans up test directory on exit via trap

---

## Common Patterns Identified

### Pattern 1: File Existence Checking
- Tasks: cd:check-release-file, ci:validate-release-file
- Common need: Check if RELEASE.txt exists
- Difference: cd outputs to GITHUB_OUTPUT, ci validates content

### Pattern 2: Changelog Manipulation
- Tasks: release:changelog-version-new, release:changelog-release-copy, release:extract-changelog
- Common need: Read, parse, and modify CHANGELOG.md
- Operations: Insert headers, copy sections, extract sections

### Pattern 3: Release Orchestration
- Task: release:do-release
- Pattern: Sequential execution of multiple sub-tasks
- Coordinates: version bump, changelog updates, cleanup

### Pattern 4: Artifact Management
- Tasks: release:organize-artifacts, release:generate-checksums
- Common need: Work with release artifact files
- Operations: Copy/organize files, generate checksums

### Pattern 5: Testing
- Tasks: release:test-changelog-version-new, release:test-extract-changelog
- Pattern: Create isolated test environment, run operations, verify results
- Can be replaced with Zig's built-in testing framework

---

## API Design Considerations

### Functional Decomposition

1. **ReleaseType**: Enum for MAJOR/MINOR/PATCH
2. **RELEASE.txt Operations**:
   - Check existence
   - Validate format
   - Read bump type
   - Read release notes
   - Delete file

3. **Changelog Operations**:
   - Parse structure (find headers, extract sections)
   - Insert version header
   - Insert release notes
   - Extract version section

4. **Artifact Operations**:
   - Organize files (flatten directory structure)
   - Generate checksums

5. **Version Operations**:
   - Get current version (from bump-my-version or .bumpversion.toml)
   - Format version header

6. **GitHub Integration**:
   - Write to GITHUB_OUTPUT
   - Parse GITHUB_REF

### Opportunities for Merging

1. **Merge cd:check-release-file and ci:validate-release-file**:
   - Both work with RELEASE.txt
   - Can be single API with different output modes
   - Function: `validateReleaseFile(mode: ValidationMode)`
   - ValidationMode: `.check_only` (for CD), `.full_validate` (for CI)

2. **Merge test tasks into main functions**:
   - Use Zig's built-in test framework
   - Tests live alongside function implementations
   - No need for separate test scripts

3. **Changelog operations can share parsing logic**:
   - Single parser for changelog structure
   - Multiple operations on parsed structure
   - Functions: `parseChangelog()`, `insertVersionHeader()`, `insertReleaseNotes()`, `extractVersionSection()`

### Error Handling Strategy

- Use Zig error unions for expected failures
- Use assertions for programmer errors
- Return descriptive error types:
  - `ReleaseFileError`: file not found, empty, invalid format
  - `ChangelogError`: parse errors, version not found
  - `ArtifactError`: no files, checksum generation failed

### Cross-Platform Considerations

- Avoid shell-specific features
- Use Zig's std.fs for file operations
- Use Zig's std.process for environment variables
- Handle path separators correctly
- Support Windows, Linux, and macOS

---

## Migration Priority

### Phase 1: Core Validation (This Issue)
- Define API signatures
- Document behavior
- Stub implementations

### Phase 2: Implementation (Future Issues)
- Implement RELEASE.txt operations
- Implement changelog operations
- Implement artifact operations

### Phase 3: Testing (Future Issues)
- Comprehensive test suites
- Integration tests
- Cross-platform validation

### Phase 4: Integration (Future Issues)
- Replace mise tasks with Zig scripts
- Update workflows
- Delete old shell scripts

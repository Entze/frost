# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.12 (2026-01-03)

Overhauled zig.instructions.md to be more coherent and hopefully more effective

## 0.1.11 (2026-01-01)

- Fixed changelog extraction in CD workflow to display correct release descriptions
- Changed extract-changelog script to prioritize VERSION environment variable over GITHUB_REF

## 0.1.10 (2026-01-01)

- Added ROADMAP.md documenting strategic direction and planned features
- Added links to ROADMAP.md and CHANGELOG.md in CONTRIBUTING.md
- Added links to ROADMAP.md and CHANGELOG.md in README.md

## 0.1.9 (2026-01-01)

- Restructured README.md to focus on user-facing content
- Moved development workflows to CONTRIBUTING.md
- Added comprehensive project description
- Added Authors, Support, and Project Status sections

## 0.1.8 (2026-01-01)

- Introduced automated documentation generation and GitHub Pages publishing
- Implemented docs step in build.zig
- Added CI job to verify documentation builds on pull requests
- Added CD job to publish documentation to GitHub Pages on releases

## 0.1.7 (2026-01-01)

- Refactored CD workflow to use cross-compilation instead of OS matrix
- Consolidated build job from 3 OS runners to single ubuntu runner
- Expanded platform support from 3 to 8 target configurations
- Added test task hierarchy for better organization
- Improved extract-changelog with optional changelog path argument
- Fixed macOS compatibility in extract-changelog script

## 0.1.6 (2026-01-01)

- Added mise tasks for Zig build steps with configurable options
- Introduced build:exe, build:lib-static, and build:lib-dynamic tasks
- Added --optimize, --target, and --cpu flags with mise argument parsing
- Improved build transparency with --summary all flag

## 0.1.5 (2025-12-31)

- Introduced GitHub Actions workflow instruction file for AI assistants
- Added mise task instruction file documenting TOML and file-based patterns

## 0.1.4 (2025-12-31)

- Reworked build.zig to expose explicit build steps with target-specific naming
- Implemented multi-target release builds for 8 platforms

## 0.1.3 (2025-12-31)

- Added Zig build system documentation guide

## 0.1.2 (2025-12-31)

- Fixed mise-action configuration to explicitly disable install and cache for task-runner-only jobs

## 0.1.1 (2025-12-31)

- Merged release.yaml into cd.yaml to fix workflow triggering issue
- Fixed GitHub Actions workflow triggering limitations

## 0.1.0 (2025-12-30)

- Introduced continuous delivery pipeline with automated version management
- Drafted alpha version of CNF program


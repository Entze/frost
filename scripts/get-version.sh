#!/usr/bin/env bash
set -euo pipefail

version=$(bump-my-version show current_version)
echo "version=$version" >> "$GITHUB_OUTPUT"

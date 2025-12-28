#!/usr/bin/env bash
set -euo pipefail

if [ -f RELEASE.txt ]; then
  echo "exists=true" >> "$GITHUB_OUTPUT"
  echo "RELEASE.txt found - will trigger release"
else
  echo "exists=false" >> "$GITHUB_OUTPUT"
  echo "RELEASE.txt not found - skipping release"
fi

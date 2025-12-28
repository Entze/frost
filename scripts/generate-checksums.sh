#!/usr/bin/env bash
set -euo pipefail

cd release-artifacts

# Check if directory has files
if [ -n "$(ls -A)" ]; then
  sha256sum -- * > CHECKSUMS.txt
  cat CHECKSUMS.txt
else
  echo "Warning: No artifacts found to generate checksums"
  exit 1
fi

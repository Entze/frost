#!/usr/bin/env bash
set -euo pipefail

version="${GITHUB_REF#refs/tags/v}"
echo "Extracting changelog for version $version"

# Extract the section for this version from CHANGELOG.md
awk -v version="$version" '
  /^## / {
    if (found) exit;
    if ($0 ~ version) {
      found=1;
      next;
    }
  }
  found && /^## / { exit }
  found { print }
' CHANGELOG.md > release_notes.txt

if [ ! -s release_notes.txt ]; then
  echo "Release v$version" > release_notes.txt
fi

cat release_notes.txt

#!/usr/bin/env bash
set -euo pipefail

mkdir -p release-artifacts
find artifacts -type f -exec cp {} release-artifacts/ \;
ls -la release-artifacts/

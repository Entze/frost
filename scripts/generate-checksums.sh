#!/usr/bin/env bash
set -euo pipefail

cd release-artifacts
sha256sum -- * > CHECKSUMS.txt
cat CHECKSUMS.txt

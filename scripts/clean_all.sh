#!/usr/bin/env bash
set -Eeuo pipefail
rm -rf build .west .west_modules /tmp/build
echo "Removed build artifacts and west state."

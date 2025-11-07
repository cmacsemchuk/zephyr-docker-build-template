#!/usr/bin/env bash
set -Eeuo pipefail
if [ ! -x build/zephyr/zephyr.exe ]; then
  echo "ERROR: build/zephyr/zephyr.exe not found. Build with BOARD=native_sim first."
  echo "Hint: docker compose run --rm build-native"
  exit 2
fi
exec ./build/zephyr/zephyr.exe

#!/usr/bin/env bash
set -Eeuo pipefail

# Project caches
: "${XDG_CACHE_HOME:=/work/var/cache}"
: "${PIP_CACHE_DIR:=${XDG_CACHE_HOME}/pip}"
: "${CCACHE_DIR:=/work/var/ccache}"
: "${CCACHE_BASEDIR:=/work}"
: "${CCACHE_COMPRESS:=1}"
: "${CCACHE_MAXSIZE:=5G}"

# Ensure cache dirs exist
mkdir -p "${XDG_CACHE_HOME}" "${PIP_CACHE_DIR}" "${CCACHE_DIR}"

# Fetch Zephyr via west
[ -f manifest/west.yml ] || { echo "manifest/west.yml missing"; exit 2; }
[ -d .west ] || west init -l manifest
west update

echo "[bootstrap] done"

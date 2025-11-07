#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nocasematch

# Load project config if present
if [ -f ".zephyr-build.env" ]; then
  # shellcheck disable=SC2046
  export $(grep -Ev '^(#|\s*$)' .zephyr-build.env | xargs -I{} echo {})
fi

# Defaults
: "${BOARD="${BOARD:-${BOARD_DEFAULT:-native_sim}}"}"
: "${APP_PATH:=auto}"
: "${pristine:=always}"
: "${FETCH:=auto}"                  # auto|always|never
: "${GENERATOR:=Ninja}"             # force Ninja
: "${BUILD_DIR:=/tmp/build}"        # build in-container to avoid mtime issues
: "${COPY_OUT:=1}"                  # copy artifacts back to ./build
: "${DO_ELF_LINK:=1}"               # make ./build/zephyr/output.elf

# Caches + ccache tuning
: "${XDG_CACHE_HOME:=/work/var/cache}"
: "${PIP_CACHE_DIR:=${XDG_CACHE_HOME}/pip}"
: "${CCACHE_DIR:=/work/var/ccache}"
: "${CCACHE_BASEDIR:=/work}"
: "${CCACHE_COMPRESS:=1}"
: "${CCACHE_MAXSIZE:=5G}"
mkdir -p "${XDG_CACHE_HOME}" "${PIP_CACHE_DIR}" "${CCACHE_DIR}" || true

# if ccache exists, wire it as compiler launcher
CC_LAUNCHER_ARGS=""
if command -v ccache >/dev/null 2>&1; then
  export CCACHE_DIR CCACHE_BASEDIR CCACHE_COMPRESS CCACHE_MAXSIZE
  export CCACHE_SLOPPINESS="${CCACHE_SLOPPINESS:-time_macros,include_file_mtime,include_file_ctime}"
  CC_LAUNCHER_ARGS="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_ASM_COMPILER_LAUNCHER=ccache"
  echo "[ccache] enabled at ${CCACHE_DIR} (max ${CCACHE_MAXSIZE}, compress=${CCACHE_COMPRESS})"
else
  echo "[ccache] not found; proceeding without compiler cache"
fi

echo "== Zephyr build =="
echo "BOARD=${BOARD}"
echo "APP_PATH=${APP_PATH}"
echo "GENERATOR=${GENERATOR}"
echo "FETCH=${FETCH}"
echo "BUILD_DIR=${BUILD_DIR}"
echo "XDG_CACHE_HOME=${XDG_CACHE_HOME}"
echo "CCACHE_DIR=${CCACHE_DIR}"

# Determine app path if 'auto': prefer current directory if it looks like a Zephyr app
detect_app() {
  if [ -f "CMakeLists.txt" ] && grep -qi 'find_package\(Zephyr' CMakeLists.txt && [ -f "prj.conf" ]; then
    echo "."
  elif [ -d "app" ] && [ -f "app/CMakeLists.txt" ]; then
    echo "app"
  else
    echo "app"
  fi
}

if [ "${APP_PATH}" = "auto" ]; then
  APP_PATH="$(detect_app)"
fi
echo "Resolved APP_PATH=${APP_PATH}"

# Bootstrap project if it hasn't been already
if [ "${FETCH}" = "always" ] || [ ! -d "zephyr" ]; then
  bash ./scripts/bootstrap.sh
fi

# Toolchain: host for native, Zephyr SDK for MCUs
if [[ "${BOARD}" == native_* || "${BOARD}" == qemu_* || "${BOARD}" == *"_native" ]]; then
  export ZEPHYR_TOOLCHAIN_VARIANT=host
  echo "[build] toolchain: host"
else
  export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
  if [ -z "${ZEPHYR_SDK_INSTALL_DIR:-}" ]; then
    for d in /opt/toolchains/zephyr-sdk-0.17.4 /opt/toolchains/zephyr-sdk /opt/zephyr-sdk; do
      [ -d "$d" ] && export ZEPHYR_SDK_INSTALL_DIR="$d" && break
    done
  fi
  if [ -z "${ZEPHYR_SDK_INSTALL_DIR:-}" ]; then
    echo "ERROR: Zephyr SDK not found. Set ZEPHYR_SDK_INSTALL_DIR"; exit 3; fi
  export CMAKE_PREFIX_PATH="${ZEPHYR_SDK_INSTALL_DIR}/cmake:${CMAKE_PREFIX_PATH:-}"
  echo "[build] toolchain: zephyr (SDK=${ZEPHYR_SDK_INSTALL_DIR})"
fi

# Point CMake straight at Zephyr; disable package registries
export ZEPHYR_BASE="$(pwd)/zephyr"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
echo "[build] west build -G ${GENERATOR} -b ${BOARD} -d ${BUILD_DIR} ${APP_PATH}"
west build -p "${pristine}" -b "${BOARD}" -d "${BUILD_DIR}" "${APP_PATH}" -- \
  -G "${GENERATOR}" \
  -DZEPHYR_BASE="${ZEPHYR_BASE}" \
  -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
  -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF \
  ${CC_LAUNCHER_ARGS}

if [ "${COPY_OUT}" = "1" ]; then
  echo "[build] copying artifacts to ./build"
  rm -rf build
  mkdir -p build
  cp -a "${BUILD_DIR}/." build/
fi

# Uniform output (create output.elf)
if [ "${DO_ELF_LINK}" = "1" ]; then
  if [ -f "build/zephyr/zephyr.elf" ]; then
    ln -sf "zephyr.elf" "build/zephyr/output.elf"
  elif [ -f "build/zephyr/zephyr.exe" ]; then
    ln -sf "zephyr.exe" "build/zephyr/output.elf"
  fi
fi

echo "[build] done. See ./build/zephyr/ (output.elf link provided)"

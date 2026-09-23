#!/usr/bin/env bash
#
# Stock kernel build — Samsung SM-G550T1 (on5ltetmo), Exynos 7570 / universal3475
# Kernel 3.10.9, ARCH=arm (32-bit), defconfig: on5ltetmo_00_defconfig
#
# Verified facts this script relies on (checked 2026-09-23):
#   * Stock /proc/version: "3.10.9-13870322 ... gcc version 4.8"  (via adb)
#   * README_Kernel.txt: toolchain arm-eabi-4.8/4.9, make ARCH=arm <defconfig>
#   * CONFIG_BUILD_ARM_APPENDED_DTB_IMAGE=y + DTB name exynos3475-universal3475
#     -> KBUILD_IMAGE = zImage-dtb (arch/arm/Makefile)
#   * Host gcc >= 10 fails at scripts/dtc link: duplicate `yylloc`
#     (-fno-common default). Reproduced locally on gcc 14.2, fix verified.
#   * CONFIG_MODULES is not set -> no .ko, single image.
#   * AOSP arm-eabi-4.8 marshmallow-release = 110 MB, ELF x86-64 (native on
#     ubuntu runners). Fallback: burstlam/arm-eabi-4.9 on GitHub.
#
set -euo pipefail
cd "$(dirname "$0")"

ARCH=arm
DEFCONFIG=o5lteswa_00_defconfig
LOCALVER="-13870322"                       # reproduces stock utsrelease
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$HOME/toolchains/arm-eabi-4.8}"
AOSP_URL="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8"
AOSP_BRANCH="marshmallow-release"
FALLBACK_URL="https://github.com/burstlam/arm-eabi-4.9"

export ARCH
export LOCALVERSION="$LOCALVER"

log() { echo "[kernel-build] $*"; }

# ---------------------------------------------------------------- sanity ----
if [ ! -f "arch/arm/configs/$DEFCONFIG" ]; then
  log "ERROR: arch/arm/configs/$DEFCONFIG not found"
  exit 1
fi

# ------------------------------------------------------------- toolchain ----
if [ ! -x "$TOOLCHAIN_DIR/bin/arm-eabi-gcc" ]; then
  log "fetching toolchain -> $TOOLCHAIN_DIR"
  mkdir -p "$(dirname "$TOOLCHAIN_DIR")"
  rm -rf "$TOOLCHAIN_DIR"
  if ! git clone --depth 1 -b "$AOSP_BRANCH" "$AOSP_URL" "$TOOLCHAIN_DIR"; then
    log "AOSP clone failed — fallback: $FALLBACK_URL"
    rm -rf "$TOOLCHAIN_DIR"
    git clone --depth 1 "$FALLBACK_URL" "$TOOLCHAIN_DIR"
  fi
fi

CROSS="$TOOLCHAIN_DIR/bin/arm-eabi-"
if ! "${CROSS}gcc" --version >/dev/null 2>&1; then
  log "ERROR: ${CROSS}gcc is not executable on this host"
  exit 1
fi
log "compiler: $("${CROSS}gcc" --version | head -1)"
export CROSS_COMPILE="$CROSS"
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-builder}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-$(hostname)}"

# ----------------------------------------- host-tool fix: dtc yylloc --------
# gcc >= 10 defaults to -fno-common -> bison+lex both define yylloc -> link
# error "multiple definition of `yylloc'". Fix = extern the parser copy.
if grep -q '^YYLTYPE yylloc;$' scripts/dtc/dtc-parser.tab.c_shipped; then
  sed -i 's/^YYLTYPE yylloc;$/extern YYLTYPE yylloc;/' scripts/dtc/dtc-parser.tab.c_shipped
  if grep -q '^YYLTYPE yylloc;$' scripts/dtc/dtc-parser.y; then
    sed -i 's/^YYLTYPE yylloc;$/extern YYLTYPE yylloc;/' scripts/dtc/dtc-parser.y
  fi
  log "applied dtc yylloc extern fix"
fi

# ----------------------------------------------------------- configure ------
log "make $DEFCONFIG"
make "$DEFCONFIG"

# Reproduce the stock release string exactly. AUTO would append a git hash.
if grep -q '^CONFIG_LOCALVERSION_AUTO=y' .config; then
  sed -i 's/^CONFIG_LOCALVERSION_AUTO=y/# CONFIG_LOCALVERSION_AUTO is not set/' .config
  log "disabled CONFIG_LOCALVERSION_AUTO"
fi

# ---------------------------------------------------------------- build -----
J="$(nproc)"
log "make -j$J zImage-dtb   (KBUILD_IMAGE for this config)"
make -j"$J" zImage-dtb 2>&1 | tee build.log     # pipefail propagates errors

IMG="arch/arm/boot/zImage-dtb"
if [ ! -s "$IMG" ]; then
  log "ERROR: $IMG missing or empty"
  exit 1
fi

RELEASE="$(cat include/config/kernel.release)"
EXPECTED="3.10.9${LOCALVER}"
if [ "$RELEASE" != "$EXPECTED" ]; then
  log "ERROR: kernel.release='$RELEASE' expected '$EXPECTED'"
  exit 1
fi
log "kernel.release = $RELEASE  (matches stock) OK"

# -------------------------------------------------------------- package ------
mkdir -p dist
cp "$IMG"          dist/zImage-dtb
cp .config         dist/kernel.config
cp System.map      dist/System.map

GIT_REV="$(git rev-parse --short HEAD 2>/dev/null || echo no-git)"
{
  echo "device      : SM-G550T1 (on5ltetmo) / universal3475"
  echo "kernel      : $RELEASE"
  echo "defconfig   : $DEFCONFIG"
  echo "compiler    : $("${CROSS}gcc" --version | head -1)"
  echo "source-git  : $GIT_REV"
  echo "built-utc   : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "runner      : ${GITHUB_RUN_ID:-local}/${GITHUB_RUN_ATTEMPT:-0}"
  echo "image-sha256: $(sha256sum "$IMG" | cut -d' ' -f1)"
} > dist/build-info.txt

( cd dist && sha256sum zImage-dtb kernel.config System.map > SHA256SUMS )

log "done:"
ls -la dist/
log "artifacts staged in dist/"

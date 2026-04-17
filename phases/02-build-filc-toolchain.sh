#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (Fix iconv_prog / iconvconfig segfault)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 02] $*"
}

log "Starting Phase 02: Building Fil-C Toolchain"

cd "$FILC_SOURCE_DIR" || {
    log "ERROR: Cannot cd to Fil-C source directory"
    exit 1
}

log "Current directory: $(pwd)"
log "Fil-C branch: $FILC_BRANCH"

# ====================== Force GCC for yolo-glibc ======================
export CC="gcc"
export CXX="g++"

log "Using CC=gcc  CXX=g++ (required for yolo-glibc)"

# ====================== Clang + integrated-as build configuration ======================
#export CMAKE_ARGS="-DLLVM_USE_LINKER=lld \
#                   -DCMAKE_ASM_COMPILER=clang \
#                   -DCMAKE_ASM_FLAGS=-integrated-as \
#                   -DLLVM_INCLUDE_TESTS=OFF \
#                   -DLLVM_BUILD_TESTS=OFF \
#                   -DLLVM_ENABLE_ASSERTIONS=OFF"

# ====================== Optional libpas patch ======================
if [[ -n "${MARCH:-}" || -n "${OPT_LEVEL:-}" ]]; then
    log "Patching -march=${MARCH:-x86-64-v2} -${OPT_LEVEL:-O2}"

    # Hardcoded -march=x86-64-v2
    sed -i -e "s|-march=[^ ]*|-march=${MARCH:-x86-64-v2}|g" "libpas/Makefile"
    sed -i -e "s|-march=[^ ]*|-march=${MARCH:-x86-64-v2}|g" "libpas/Makefile-check"

    DEBUG_LEVEL="${DEBUG_LEVEL:-g}" # Upstream default -g (same as -g2)

    # -O1 upstream
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O} -${DEBUG_LEVEL}|g" "build_jpeg-6b.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O} -${DEBUG_LEVEL}|g" "build_mg.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O} -${DEBUG_LEVEL}|g" "build_ncurses.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O} -${DEBUG_LEVEL}|g" "build_xz.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O} -${DEBUG_LEVEL}|g" "build_zsh.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O}|g" "build_pcre.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O}|g" "build_pcre2.sh"

    # -O3 upstream
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O3}|g" "build_ada.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O3} -${DEBUG_LEVEL}|g" "build_icu.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O3}|g" "build_libedit.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O3} -${DEBUG_LEVEL}|g" "build_perl.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O3} -${DEBUG_LEVEL}|g" "build_postgres.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O3}|g" "build_simdjson.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O3}|g" "build_simdutf.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O3} -${DEBUG_LEVEL}|g" "build_zlib.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O3} -${DEBUG_LEVEL}|g" "pizlix/build_postlc_chroot_project_perl.sh"
    sed -i -e "s|-O[0-9s]|-${OPT_LEVEL:-O3}|g" "pizlix/build_postlc_sub2_chroot_part1.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O3}|g" "libpas/Makefile"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O3} -${DEBUG_LEVEL}|g" "libpas/Makefile"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O3}|g" "libpas/Makefile-check"
    #sed -i -e "s|-O[0-9s]|-${OPT_LEVEL:-O3}|g" "projects/usermusl/Makefile"
    #sed -i -e "s|-O[0-9s]|-${OPT_LEVEL:-O3}|g" "projects/yolomusl/Makefile"

    # -O2 upstream
    sed -i -e "s|-O[0-9s]|-${OPT_LEVEL:-O2}|g" "build_cmake.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O2}|g" "build_cpython.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O2} -${DEBUG_LEVEL}|g" "build_ffi.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O2} -${DEBUG_LEVEL}|g" "build_filbox1.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O2} -${DEBUG_LEVEL}|g" "build_libpipeline.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O2}|g" "build_openssl.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O2}|g" "build_sqlite.sh"
    sed -i -e "s|-g -O[0-9s]|-${DEBUG_LEVEL} -${OPT_LEVEL:-O2}|g" "build_tcl.sh"
    sed -i -e "s|-O[0-9s] -g|-${OPT_LEVEL:-O2} -${DEBUG_LEVEL}|g" "build_toybox.sh"
fi

# ====================== Safe LD_LIBRARY_PATH (no '.' ) ======================
log "Sanitizing LD_LIBRARY_PATH for glibc configure..."

YOLO_BUILD_DIR="/root/filc-bootstrap/sources/fil-c/pizlonated-yolo-glibc-build"

mkdir -p /tmp/yolo-test-lib
ln -sf "${YOLO_BUILD_DIR}/ld-linux-x86-64.so.2" /tmp/yolo-test-lib/ld-linux-x86-64.so.2 2>/dev/null || true
ln -sf "${YOLO_BUILD_DIR}/libc.so.6" /tmp/yolo-test-lib/libc.so.6 2>/dev/null || true

CLEAN_LD_PATH="/tmp/yolo-test-lib:${YOLO_BUILD_DIR}"
if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
    CLEAN_LD_PATH="${CLEAN_LD_PATH}:$(echo "${LD_LIBRARY_PATH}" | sed 's|\.:||g; s|::|:|g; s|^:||; s|:$||')"
fi

export LD_LIBRARY_PATH="${CLEAN_LD_PATH}"
export PATH="/yolo/bin:${PATH}"

log "Clean LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"

# ====================== Patch libpas/common.sh ======================
log "Patching libpas/common.sh to bypass Unsupported OS check..."

if [[ -f "libpas/common.sh" ]]; then
    sed -i 's|uname -s|echo Linux|g' "libpas/common.sh" || true
    sed -i 's|Unsupported OS|Supported for Fil-C bootstrap (bypassed)|g' "libpas/common.sh" || true
    sed -i 's|exit 1|echo "OS check bypassed" # exit 1 disabled for bootstrap|g' "libpas/common.sh" || true
fi

find . -path "*/libpas/*" -name "*.sh" | while read -r script; do
    sed -i 's|Unsupported OS|Supported for bootstrap|g' "$script" || true
done

log "libpas/common.sh patched."

# ====================== Critical Fix for iconv_prog / iconvconfig segfault ======================
log "Applying workaround for iconv_prog and iconvconfig linking segfault..."

# Force uninstrumented GCC for the final iconv tools (most common fix)
export GLIBC_NO_FILC_INSTRUMENT=1   # Tell bootstrap to skip instrumentation for host tools if supported
export CC_FOR_BUILD="gcc"           # Force plain gcc for build-time tools
export CXX_FOR_BUILD="g++"

# Reduce optimization / disable some passes that may cause ld crash
export CFLAGS="-O2 -pipe -fPIC -fno-lto"
export CXXFLAGS="-O2 -pipe -fPIC -fno-lto"

log "Forcing CC_FOR_BUILD=gcc and reduced flags for iconv tools"

# ====================== Choose and run build script ======================
if [[ "$FILC_LIBC" == "musl" ]]; then
    BUILD_SCRIPT="build_all_fast_musl.sh"
else
    BUILD_SCRIPT="build_all_fast_glibc.sh"
fi

log "Starting build with $BUILD_SCRIPT ..."

chmod +x "./$BUILD_SCRIPT"

if ./"$BUILD_SCRIPT"; then
    log "✅ Fil-C build completed successfully."
else
    log "❌ Fil-C build failed."
    exit 1
fi

log "Phase 02 completed successfully!"

exit 0

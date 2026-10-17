#!/bin/bash
# Build libclash.so for OpenHarmony (arm64-v8a)
# Requires: Go with openharmony support, OHOS NDK
# Usage: ./build_libclash.sh [output_dir]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$PROJECT_DIR/core"
OUTPUT_DIR="${1:-$PROJECT_DIR/ohos/core/libs/arm64-v8a}"
INCLUDE_DIR="$PROJECT_DIR/ohos/core/src/main/cpp/includes/arm64-v8a"

if [ -z "$OHOS_NDK_HOME" ]; then
    echo "Error: OHOS_NDK_HOME not set"
    exit 1
fi

mkdir -p "$OUTPUT_DIR" "$INCLUDE_DIR"

echo "Building libclash.so for OpenHarmony arm64-v8a..."

cd "$CORE_DIR"

NDK_LLVM_BIN="$OHOS_NDK_HOME/native/llvm/bin"
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
    OHOS_SYSROOT="$OHOS_NDK_HOME/native/sysroot"
    TARGET_FLAGS="--target=aarch64-linux-ohos --sysroot=$OHOS_SYSROOT -D__MUSL__"
    CC="$NDK_LLVM_BIN/clang.exe"
    CXX="$NDK_LLVM_BIN/clang++.exe"
    CGO_CFLAGS="${CGO_CFLAGS:+$CGO_CFLAGS }$TARGET_FLAGS"
    CGO_CXXFLAGS="${CGO_CXXFLAGS:+$CGO_CXXFLAGS }$TARGET_FLAGS"
    CGO_LDFLAGS="${CGO_LDFLAGS:+$CGO_LDFLAGS }$TARGET_FLAGS"
    CGO_CFLAGS_ALLOW="${CGO_CFLAGS_ALLOW:---target=.*|--sysroot=.*|-D__MUSL__}"
    CGO_CXXFLAGS_ALLOW="${CGO_CXXFLAGS_ALLOW:---target=.*|--sysroot=.*|-D__MUSL__}"
    CGO_LDFLAGS_ALLOW="${CGO_LDFLAGS_ALLOW:---target=.*|--sysroot=.*|-D__MUSL__}"
else
    CC="$NDK_LLVM_BIN/aarch64-unknown-linux-ohos-clang"
    CXX="$NDK_LLVM_BIN/aarch64-unknown-linux-ohos-clang++"
fi

CGO_ENABLED=1 \
GOOS=linux \
GOARCH=arm64 \
CC="$CC" \
CXX="$CXX" \
CGO_CFLAGS="$CGO_CFLAGS" \
CGO_CXXFLAGS="$CGO_CXXFLAGS" \
CGO_LDFLAGS="$CGO_LDFLAGS" \
CGO_CFLAGS_ALLOW="$CGO_CFLAGS_ALLOW" \
CGO_CXXFLAGS_ALLOW="$CGO_CXXFLAGS_ALLOW" \
CGO_LDFLAGS_ALLOW="$CGO_LDFLAGS_ALLOW" \
go build -tags openharmony -buildmode=c-shared \
    -o "$OUTPUT_DIR/libclash.so" \
    ./ohos

# The generated header is at $OUTPUT_DIR/libclash.h, copy it to includes
cp "$OUTPUT_DIR/libclash.h" "$INCLUDE_DIR/libclash.h"

echo "Built: $OUTPUT_DIR/libclash.so"
echo "Header: $INCLUDE_DIR/libclash.h"

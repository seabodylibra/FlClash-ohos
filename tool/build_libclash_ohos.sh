#!/bin/bash
# Build libclash.so for OpenHarmony (arm64-v8a)
# Requires: Go with openharmony support, OHOS NDK
# Usage: ./build_libclash.sh [output_dir]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/../../core"
OUTPUT_DIR="${1:-$SCRIPT_DIR/../../ohos/entry/libs/arm64-v8a}"
INCLUDE_DIR="$SCRIPT_DIR/../../ohos/core/src/main/cpp/includes/arm64-v8a"

if [ -z "$OHOS_NDK_HOME" ]; then
    echo "Error: OHOS_NDK_HOME not set"
    exit 1
fi

mkdir -p "$OUTPUT_DIR" "$INCLUDE_DIR"

echo "Building libclash.so for OpenHarmony arm64-v8a..."

cd "$CORE_DIR"

CGO_ENABLED=1 \
GOOS=linux \
GOARCH=arm64 \
CC="$OHOS_NDK_HOME/native/llvm/bin/aarch64-unknown-linux-ohos-clang" \
CXX="$OHOS_NDK_HOME/native/llvm/bin/aarch64-unknown-linux-ohos-clang++" \
go build -tags openharmony -buildmode=c-shared \
    -o "$OUTPUT_DIR/libclash.so" \
    ./ohos

# The generated header is at $OUTPUT_DIR/libclash.h, copy it to includes
cp "$OUTPUT_DIR/libclash.h" "$INCLUDE_DIR/libclash.h"

echo "Built: $OUTPUT_DIR/libclash.so"
echo "Header: $INCLUDE_DIR/libclash.h"

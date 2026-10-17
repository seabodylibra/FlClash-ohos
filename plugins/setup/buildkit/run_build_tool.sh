#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "ohos" || "${2:-}" != "--arch" || "${3:-}" != "arm64" ]]; then
  echo 'Usage: run_build_tool.sh ohos --arch arm64' >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [[ -z "${OHOS_NDK_HOME:-}" ]]; then
  for SDK_ROOT in "${HOS_SDK_HOME:-}" "${DEVECO_SDK_HOME:-}" "${DEVECO_SDK_HOME:+$DEVECO_SDK_HOME/sdk}"; do
    if [[ -n "$SDK_ROOT" && -d "$SDK_ROOT/default/openharmony/native" ]]; then
      export OHOS_NDK_HOME="$SDK_ROOT/default/openharmony"
      break
    fi
  done
fi

exec bash "$PROJECT_ROOT/tool/build_libclash_ohos.sh"

#!/usr/bin/env bash
# Build the project and (if a watch is plugged in) copy the .prg to it.
#
# Usage:  ./deploy.sh [device-id]
#         device-id defaults to fenix7pronowifi
#
# Exits non-zero on build failure. If no watch is mounted, exits 0 after
# build with a notice — useful for build-only sanity checks.
set -euo pipefail

DEVICE="${1:-fenix7pronowifi}"
SDK_GLOB="$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-*"
KEY="$HOME/.Garmin/developer_key"
APP_NAME="bms"

SDK="$(ls -d $SDK_GLOB 2>/dev/null | sort -V | tail -n1)"
if [[ -z "$SDK" ]]; then
    echo "error: no Connect IQ SDK found under $SDK_GLOB" >&2
    exit 1
fi

PRG="$(pwd)/bin/${APP_NAME}.prg"
mkdir -p "$(dirname "$PRG")"

echo "▸ building ${APP_NAME}.prg for $DEVICE (sdk: $(basename "$SDK"))"
"$SDK/bin/monkeyc" \
    -f monkey.jungle \
    -o "$PRG" \
    -d "$DEVICE" \
    -y "$KEY" \
    -w

# Locate watch mount. Garmin watches expose a FAT volume labeled GARMIN.
WATCH_MOUNT=""
for base in "/run/media/$USER" "/media/$USER"; do
    if [[ -d "$base/GARMIN" ]]; then
        WATCH_MOUNT="$base/GARMIN"
        break
    fi
done

if [[ -z "$WATCH_MOUNT" ]]; then
    echo "✓ build ok — no watch mounted, skipping deploy"
    exit 0
fi

APPS_DIR="$WATCH_MOUNT/GARMIN/Apps"
if [[ ! -d "$APPS_DIR" ]]; then
    if [[ -d "$WATCH_MOUNT/Apps" ]]; then
        APPS_DIR="$WATCH_MOUNT/Apps"
    else
        echo "error: $WATCH_MOUNT does not contain an Apps directory" >&2
        exit 3
    fi
fi

echo "▸ copying $PRG -> $APPS_DIR/"
cp "$PRG" "$APPS_DIR/"
sync

echo "✓ deployed. unplug the watch to finalize install."

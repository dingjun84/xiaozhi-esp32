#!/usr/bin/env bash
# Build the AtomS3R + Echo Pyramid firmware with the “你好房保保” wake word.
set -e

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'HELP'
Usage: bash scripts/build_fangbaobao.sh

Builds the Chinese AtomS3R + Echo Pyramid “你好房保保” firmware and ZIP.
OTA: https://agent.fangbaobaochina.com/xiaozhi/ota/

ESP-IDF: release/v6.1 recommended; minimum v6.0.1.
Uses IDF_PATH/export.sh if IDF_PATH is set, otherwise looks for:
  ~/esp/activate-xiaozhi.sh
  ~/esp/esp-idf/export.sh
  ~/esp-idf/export.sh

Example with another SDK installation:
  IDF_PATH=/path/to/esp-idf bash scripts/build_fangbaobao.sh

Output: releases/v<version>_m5stack-atoms3r-echo-pyramid-fangbaobao.zip
First installation requires USB flashing of the full image, including
the partition table and assets. This script only builds; it does not flash.
HELP
    exit 0
fi
if [[ $# -ne 0 ]]; then
    echo "Unknown argument: $1. Use --help for usage." >&2
    exit 2
fi

if [[ -n "${IDF_PATH:-}" ]]; then
    if [[ ! -f "$IDF_PATH/export.sh" ]]; then
        echo "Cannot find ESP-IDF export.sh in IDF_PATH: $IDF_PATH" >&2
        exit 1
    fi
    source "$IDF_PATH/export.sh"
elif [[ -f "$HOME/esp/activate-xiaozhi.sh" ]]; then
    source "$HOME/esp/activate-xiaozhi.sh"
elif [[ -f "$HOME/esp/esp-idf/export.sh" ]]; then
    source "$HOME/esp/esp-idf/export.sh"
elif [[ -f "$HOME/esp-idf/export.sh" ]]; then
    source "$HOME/esp-idf/export.sh"
else
    echo "ESP-IDF not found. Set IDF_PATH to your SDK installation and retry." >&2
    exit 1
fi

cd "$PROJECT_DIR"
idf.py --version
python scripts/build.py m5stack/atoms3r-echo-pyramid \
    --name atoms3r-echo-pyramid-fangbaobao \
    --language zh-CN \
    --zip

echo "Build completed. Firmware ZIP is in: $PROJECT_DIR/releases/"
echo "First installation: flash the complete image over USB."

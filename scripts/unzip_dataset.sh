#!/usr/bin/env bash
# Unzips the Brazilian E-Commerce Public Dataset into a target directory.
# Usage: ./unzip_dataset.sh [path_to_zip] [output_dir]
# Defaults: databaseinput/Brazilian E-Commerce Public Dataset.zip, ./dataset

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ZIP_PATH="${1:-$REPO_ROOT/databaseinput/Brazilian E-Commerce Public Dataset.zip}"
OUTPUT_DIR="${2:-$REPO_ROOT/dataset}"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Error: ZIP file not found: $ZIP_PATH" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
echo "Extracting $ZIP_PATH into $OUTPUT_DIR ..."
unzip -o -q "$ZIP_PATH" -d "$OUTPUT_DIR"
echo "Done. Contents:"
ls -la "$OUTPUT_DIR"

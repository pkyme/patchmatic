#!/usr/bin/env bash
# Downloads the control detection model into the app's resources.
# The model is published as a GitHub release asset because it is too large for git.
# Without it the app builds and runs, but importing a panel photo detects no controls.
set -euo pipefail

TAG="model-v1"
URL="https://github.com/pkyme/patchmatic/releases/download/${TAG}/eurorack-controls.onnx"
SHA256="7d31091212b48f56d98439b0af31a5baf88ba81107d98386dc54427543c728d2"

cd "$(dirname "$0")/.."
DEST="Patchmatic/Models/eurorack-controls.onnx"

if [ -f "$DEST" ] && echo "$SHA256  $DEST" | shasum -a 256 -c --status; then
    echo "Model already present: $DEST"
    exit 0
fi

mkdir -p "$(dirname "$DEST")"
echo "Downloading $URL"
curl -fL --progress-bar -o "$DEST.download" "$URL"
echo "$SHA256  $DEST.download" | shasum -a 256 -c --status || {
    rm -f "$DEST.download"
    echo "Error: checksum mismatch for the downloaded model" >&2
    exit 1
}
mv "$DEST.download" "$DEST"
echo "Model saved to $DEST"

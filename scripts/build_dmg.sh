#!/usr/bin/env bash
# build_dmg.sh — creates a styled Patchmatic installer DMG
# Usage: ./build_dmg.sh [version] [/path/to/Patchmatic.app]
# Requires Python 3 with Pillow (pip install pillow) to draw the window background.
# Set RESTART_FINDER=1 to restart Finder afterwards, which clears its icon cache so
# the DMG's custom view shows correctly on this Mac.
set -euo pipefail

if ! python3 -c "import PIL" 2>/dev/null; then
    echo "Error: Pillow is required to draw the DMG background. Install it with: pip install pillow"
    exit 1
fi

APP_NAME="Patchmatic"
VERSION="${1:-0.1}"
DMG_OUT="${APP_NAME}-${VERSION}.dmg"
DMG_TMP="/tmp/${APP_NAME}_build_$$.dmg"
MOUNT_VOL="${APP_NAME}"
MOUNT_POINT="/Volumes/${MOUNT_VOL}"

# Resolve .app path
if [ -n "${2:-}" ]; then
    APP_PATH="$2"
else
    APP_PATH=$(ls -td \
        ~/Library/Developer/Xcode/DerivedData/Patchmatic-*/Build/Products/Release/Patchmatic.app \
        2>/dev/null | head -1 || true)
fi

if [ ! -d "${APP_PATH:-}" ]; then
    echo "Error: Patchmatic.app not found."
    echo "Build a Release in Xcode, or pass the .app path as the second argument."
    exit 1
fi

echo "Source app : $APP_PATH"
echo "Output DMG : $DMG_OUT"

# ── Background image ───────────────────────────────────────────────────────────
# Window: 540×340. App icon center (150,165), Applications center (390,165).
# Arrow sits between the two icon bounding boxes; text sits below both icons.
BG_IMAGE="/tmp/dmg_bg_$$.png"

python3 - "$BG_IMAGE" <<'PYEOF'
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 540, 340
img = Image.new("RGB", (W, H), (245, 245, 245))
draw = ImageDraw.Draw(img)

# Icon size 128, centers at x=150 and x=390, y=142.
# Right edge of left icon:  150+64 = 214
# Left edge of right icon:  390-64 = 326
# Gap center x: 270   Gap width: 112px
# Arrow shaft with 12px padding from each icon edge: x=226..302, tip at 302+12=314
# Arrow y: 142 (same as icon centers)
ax1, ax2, ay = 226, 302, 142
draw.line([(ax1, ay), (ax2, ay)], fill=(120, 120, 120), width=3)
draw.polygon(
    [(ax2, ay - 9), (ax2 + 12, ay), (ax2, ay + 9)],
    fill=(120, 120, 120),
)

try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
except Exception:
    font = ImageFont.load_default()

# Finder places the filename label ~5px below icon bottom (y=229), ~15px tall.
# Place instruction text below that label area.
text = "Drag to Applications to install"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, 247), text, fill=(100, 100, 100), font=font)

img.save(sys.argv[1])
print(f"Background written to {sys.argv[1]}")
PYEOF

# ── Create writable DMG ────────────────────────────────────────────────────────
hdiutil create \
    -size 300m \
    -volname "$MOUNT_VOL" \
    -fs HFS+ \
    "$DMG_TMP" \
    >/dev/null

hdiutil attach "$DMG_TMP" \
    -readwrite \
    -noverify \
    -noautoopen \
    -mountpoint "$MOUNT_POINT" \
    >/dev/null

# Copy app bundle
cp -r "$APP_PATH" "${MOUNT_POINT}/"

# Create a proper Finder alias to /Applications. Unlike a Unix symlink, a
# Finder alias stores a bookmark to the target and renders its icon natively.
osascript - "$MOUNT_POINT" <<'ASEOF'
on run argv
    tell application "Finder"
        set mountFolder to POSIX file (item 1 of argv) as alias
        set appsTarget to POSIX file "/Applications" as alias
        make new alias file at mountFolder to appsTarget
    end tell
end run
ASEOF

# Background folder (leading dot keeps it hidden from Finder)
mkdir -p "${MOUNT_POINT}/.background"
cp "$BG_IMAGE" "${MOUNT_POINT}/.background/background.png"
rm "$BG_IMAGE"

# ── Configure window via AppleScript ──────────────────────────────────────────
# Wait for Finder to register the newly mounted volume before scripting it.
echo "Waiting for Finder to register volume..."
sleep 5

# Volume name and app name are passed as argv to avoid interpolation issues
# with the heredoc. The close→open→bounds-nudge dance forces Finder to flush
# .DS_Store twice, which is required for settings to survive compression.
# The polling loop then blocks until .DS_Store is confirmed on disk.
/usr/bin/osascript - "$MOUNT_VOL" "${APP_NAME}.app" <<'ASEOF'
on run argv
    set volName to item 1 of argv
    set appName to item 2 of argv
    set dsStorePath to "/Volumes/" & volName & "/.DS_Store"

    tell application "Finder"
        tell disk volName
            open
            tell container window
                set current view to icon view
                set toolbar visible to false
                set statusbar visible to false
                -- {left, top, right, bottom} → 540 × 340 window
                set the bounds to {100, 100, 640, 440}
            end tell
            set opts to icon view options of container window
            tell opts
                set arrangement to not arranged
                set icon size to 128
                set text size to 13
            end tell
            set background picture of opts to file ".background:background.png"
            set position of item appName of container window to {150, 142}
            set position of item "Applications" of container window to {390, 142}

            -- Stamp the /Applications folder icon onto the symlink explicitly
            -- First flush: close and reopen
            close
            open
            delay 1

            -- Bounds nudge forces a second .DS_Store write
            tell container window
                set the bounds to {100, 100, 630, 430}
            end tell
        end tell

        delay 1

        tell disk volName
            tell container window
                set the bounds to {100, 100, 640, 440}
            end tell
        end tell

        -- Poll until .DS_Store is confirmed written
        delay 3
        set isReady to false
        repeat while isReady is false
            delay 1
            if (do shell script "[ -f " & quoted form of dsStorePath & " ] && echo 1 || echo 0") = "1" then
                set isReady to true
            end if
        end repeat
    end tell
end run
ASEOF

# Extra buffer for Finder to finish any pending writes
sleep 4

chflags hidden "${MOUNT_POINT}/.background"
rm -rf "${MOUNT_POINT}/.fseventsd" 2>/dev/null || true
sync

# ── Eject (with retry) and compress ───────────────────────────────────────────
echo "Ejecting..."
for i in 1 2 3 4 5; do
    hdiutil detach "$MOUNT_POINT" -quiet && break || sleep $(( 2 ** i ))
done

rm -f "$DMG_OUT"
hdiutil convert "$DMG_TMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_OUT" \
    >/dev/null
rm "$DMG_TMP"

echo "Done: $DMG_OUT"

# Restarting Finder clears its icon cache so the DMG displays correctly when opened
# on this machine. Opt-in, since it closes every Finder window.
if [ "${RESTART_FINDER:-0}" = "1" ]; then
    echo "Restarting Finder to clear icon cache..."
    killall Finder
fi

#!/usr/bin/env bash
#
# Turn a raw screen recording into showcase-ready media:
#   1. A web-optimized MP4  (good for native LinkedIn upload / GitHub release)
#   2. A short, palette-optimized GIF (good for embedding in the README)
#
# The GIF is generated from a TRIMMED segment (a full 2-minute GIF would be huge),
# so pass a start time and duration for the GIF clip.
#
# Usage:
#   scripts/make-demo-media.sh [SOURCE] [GIF_START] [GIF_DURATION]
#
# Examples:
#   scripts/make-demo-media.sh                                  # defaults below
#   scripts/make-demo-media.sh assets/pangolock_userflow.mp4 0:10 20
#       -> MP4 from the whole recording + a 20s GIF starting at 0:10
#
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="${1:-assets/pangolock_userflow.mp4}"
GIF_START="${2:-0}"        # where the GIF clip begins (e.g. 0:10 or 12)
GIF_DUR="${3:-20}"         # GIF clip length in seconds

OUT_MP4="assets/pangolock_demo.mp4"
OUT_GIF="assets/pangolock_demo.gif"
SCALE_W=720                # downscale width for both outputs (keeps files small)
FPS_MP4=30
FPS_GIF=15                 # 15fps is plenty for a UI demo GIF

if [[ ! -f "$SRC" ]]; then
  echo "error: source not found: $SRC" >&2
  exit 1
fi
command -v ffmpeg >/dev/null || { echo "error: ffmpeg not installed (brew install ffmpeg)" >&2; exit 1; }

echo "Source:      $SRC"
echo "MP4 out:     $OUT_MP4  (${FPS_MP4}fps, ${SCALE_W}px wide)"
echo "GIF out:     $OUT_GIF  (${FPS_GIF}fps, ${GIF_DUR}s from $GIF_START)"
echo

# --- 1. Web-optimized MP4 (whole recording) -----------------------------------
echo "==> Encoding optimized MP4 ..."
ffmpeg -y -i "$SRC" \
  -vf "fps=${FPS_MP4},scale=${SCALE_W}:-2:flags=lanczos" \
  -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 24 -preset slow \
  -movflags +faststart -an \
  "$OUT_MP4"

# --- 2. Palette-optimized GIF (trimmed segment) -------------------------------
echo "==> Building GIF palette ..."
PALETTE="$(mktemp -t pango_palette).png"
ffmpeg -y -ss "$GIF_START" -t "$GIF_DUR" -i "$SRC" \
  -vf "fps=${FPS_GIF},scale=${SCALE_W}:-2:flags=lanczos,palettegen=stats_mode=diff" \
  "$PALETTE"

echo "==> Encoding GIF ..."
ffmpeg -y -ss "$GIF_START" -t "$GIF_DUR" -i "$SRC" -i "$PALETTE" \
  -lavfi "fps=${FPS_GIF},scale=${SCALE_W}:-2:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
  "$OUT_GIF"
rm -f "$PALETTE"

echo
echo "Done:"
ls -lh "$OUT_MP4" "$OUT_GIF"

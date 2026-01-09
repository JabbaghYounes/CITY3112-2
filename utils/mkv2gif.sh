#!/usr/bin/env bash

set -e

# ⚙ Settings
FPS=20         # Higher FPS = smoother motion (10-25 is reasonable)
WIDTH=720      # Width in pixels, height auto (-1 preserves aspect ratio)
GIF_DIR="gifs" # Output folder
DITHER="bayer" # Dithering for smooth gradients: none, bayer, floyd_steinberg

# Create output directory
mkdir -p "$GIF_DIR"

shopt -s nullglob

for file in *.mkv; do
  base_name="${file%.mkv}"
  palette="/tmp/${base_name}_palette.png"
  output="${GIF_DIR}/${base_name}.gif"

  echo "🔹 Converting full-length MKV: $file → $output"

  # Step 1: Generate optimized palette for colors
  ffmpeg -y -i "$file" \
    -vf "fps=${FPS},scale=${WIDTH}:-1:flags=lanczos,palettegen" \
    "$palette"

  # Step 2: Convert full video to GIF using palette, with dithering
  ffmpeg -y -i "$file" -i "$palette" \
    -filter_complex "fps=${FPS},scale=${WIDTH}:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=${DITHER}" \
    -loop 0 \
    "$output"

  # Cleanup palette file
  rm -f "$palette"

  echo "✅ Done: $output"
done

echo "🎉 All MKV files converted in high quality. GIFs are in '${GIF_DIR}' folder."

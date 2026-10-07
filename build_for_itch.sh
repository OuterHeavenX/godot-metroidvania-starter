#!/bin/bash
# Build Metroidvania Starter for itch.io distribution
# Supports Steam Deck (Linux) and web exports

set -euo pipefail

GODOT="${GODOT:-godot}"
OUTPUT_DIR="${OUTPUT_DIR:-build/itch}"

echo "🎮 Building Metroidvania Starter for itch.io"
echo "  Godot: $GODOT"
echo "  Output: $OUTPUT_DIR"
echo ""

# Clean previous builds
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Import resources
echo "📦 Importing resources..."
"$GODOT" --headless --import .

# Build Linux export (for Steam Deck)
echo "🐧 Building Linux export..."
mkdir -p "$OUTPUT_DIR/linux"
"$GODOT" --headless --export-release "Linux" "$OUTPUT_DIR/linux/metroidvania"
chmod +x "$OUTPUT_DIR/linux/metroidvania"
echo "✓ Linux export complete: $OUTPUT_DIR/linux/"

# Build web export
echo "🌐 Building web export..."
mkdir -p "$OUTPUT_DIR/web"
"$GODOT" --headless --export-release "Web" "$OUTPUT_DIR/web/index.html"
echo "✓ Web export complete: $OUTPUT_DIR/web/"

# Create metadata for itch.io
echo "📝 Creating itch.io metadata..."
cat > "$OUTPUT_DIR/linux/itch_metadata.json" <<'EOF'
{
  "name": "Metroidvania Starter",
  "description": "A tight 2D metroidvania starter: run, coyote-time jumps, wall-jump shaft, dash, and a double-jump ability gate.",
  "kind": "game",
  "platforms": {
    "linux": "metroidvania"
  },
  "launch_targets": {
    "linux": {
      "script": "metroidvania",
      "primary": true
    }
  }
}
EOF

cat > "$OUTPUT_DIR/web/README.md" <<'EOF'
# Metroidvania Starter - Web Version

Open `index.html` in a web browser to play.

## Controls
- **A/D or Arrow Keys**: Move left/right
- **Space**: Jump
- **Shift**: Dash
- **J or X**: Attack
- **S or Down Arrow**: Pound
- **K or C**: Throw

## Browser Compatibility
Works best in modern browsers with WebGL support.
EOF

echo ""
echo "✨ Build complete!"
echo ""
echo "📦 Next steps for itch.io:"
echo "  1. Go to https://itch.io/dashboard"
echo "  2. Create a new game"
echo "  3. Upload the Linux build from: $OUTPUT_DIR/linux/"
echo "  4. (Optional) Upload the web build from: $OUTPUT_DIR/web/"
echo ""
echo "🎮 For Steam Deck:"
echo "  - Use the Linux build"
echo "  - It will work natively without Proton"
echo ""

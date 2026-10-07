#!/bin/bash
# Upload Winter Warrior to itch.io
# Requires butler (itch.io's command-line tool) and an API token

set -euo pipefail

# Configuration - update these
ITCH_USER="${ITCH_USER:-}"
ITCH_GAME="${ITCH_GAME:-winter-warrior}"
ITCH_TOKEN="${ITCH_TOKEN:-}"
BUILD_DIR="build/itch"

echo "🎮 Uploading Winter Warrior to itch.io"
echo ""

# Check configuration
if [ -z "$ITCH_USER" ]; then
    echo "❌ Error: ITCH_USER not set"
    echo "   Set it with: export ITCH_USER=your_username"
    exit 1
fi

if [ -z "$ITCH_TOKEN" ]; then
    echo "❌ Error: ITCH_TOKEN not set"
    echo "   Set it with: export ITCH_TOKEN=your_api_token"
    echo ""
    echo "To get your API token:"
    echo "  1. Go to https://itch.io/user/settings/api-keys"
    echo "  2. Click 'Generate new API token'"
    echo "  3. Copy the token"
    echo "  4. Run: export ITCH_TOKEN='<your_token>'"
    exit 1
fi

# Check if butler is installed
if ! command -v butler &> /dev/null; then
    echo "❌ butler is not installed"
    echo ""
    echo "Install it from: https://itch.io/app"
    echo "Or download directly: https://github.com/itchio/butler/releases"
    echo ""
    echo "After installation, add it to your PATH and try again"
    exit 1
fi

# Check if builds exist
if [ ! -d "$BUILD_DIR/linux" ]; then
    echo "❌ Linux build not found at $BUILD_DIR/linux"
    echo "   Run ./build_for_itch.sh first"
    exit 1
fi

echo "📤 Uploading to: $ITCH_USER/$ITCH_GAME"
echo ""

# Set up butler authentication
export BUTLER_API_KEY="$ITCH_TOKEN"

# Upload Linux build
echo "🐧 Uploading Linux build..."
butler push "$BUILD_DIR/linux" "$ITCH_USER/$ITCH_GAME:linux" --fix-permissions

# Upload web build if it exists
if [ -d "$BUILD_DIR/web" ]; then
    echo "🌐 Uploading web build..."
    butler push "$BUILD_DIR/web" "$ITCH_USER/$ITCH_GAME:web" --fix-permissions
fi

echo ""
echo "✨ Upload complete!"
echo ""
echo "🎮 Visit your game at: https://itch.io/game/$ITCH_GAME"
echo ""

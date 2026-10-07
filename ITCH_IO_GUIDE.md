# Uploading to itch.io for Steam Deck

This guide walks you through building and uploading your game to itch.io for Steam Deck testing.

## Prerequisites

- **Godot 4.7.2** installed locally
  - Download from: https://github.com/godotengine/godot/releases
  - Make sure `godot` is in your PATH or set `GODOT=/path/to/godot`
- **itch.io account** (free)
  - Sign up at https://itch.io

## Building the Game

### Option 1: Using the build script (Recommended)

```bash
chmod +x build_for_itch.sh
./build_for_itch.sh
```

This will create optimized builds for both Linux (Steam Deck) and Web.

### Option 2: Manual build

```bash
# Import resources
godot --headless --import .

# Build Linux export (recommended for Steam Deck)
mkdir -p build/itch/linux
godot --headless --export-release "Linux" "build/itch/linux/winter-warrior"

# Or build web export
mkdir -p build/itch/web
godot --headless --export-release "Web" "build/itch/web/index.html"
```

## Uploading to itch.io

### 1. Create a project on itch.io

1. Go to https://itch.io/dashboard
2. Click "Create new project"
3. Fill in:
   - **Title**: Winter Warrior
   - **Project URL**: `winter-warrior`
   - **Description**: A tight 2D metroidvania: run, coyote-time jumps, wall-jump shaft, dash, and a double-jump ability gate. Battle through the frozen peaks!
   - **Classification**: Game
   - **Kind of project**: HTML / Game Jam / etc.

### 2. Upload the Linux build

1. In your project dashboard, click "Edit game"
2. Scroll to "Uploads"
3. Click "Upload files"
4. Select the folder: `build/itch/linux/`
5. Choose **Linux** as the platform
6. Mark as **Executable** (important for Steam Deck!)
7. Check "This file will be played in the app"

### 3. Set the launch command (optional for web, required for Linux)

For the **Linux** build:
1. After uploading, find the upload in the list
2. Set the launch target to: `winter-warrior` (the executable)

For the **Web** build:
1. Upload `build/itch/web/` as an HTML upload
2. itch.io will automatically handle the launch configuration

### 4. Mark as playable in app

1. After uploads are complete, scroll down to "Embed options"
2. Check "This file will be played in the app"
3. Set the default upload (should be Linux for Steam Deck)

## Testing on Steam Deck

### Add to Steam Deck

1. **On Steam Deck**: Open the itch.io app (or install it)
2. Search for your project
3. Click "Install"
4. Run the game directly from Steam or the itch.io app

### Or play in browser

1. Visit your itch.io project page in a browser
2. Click "Play in Browser" (if web version is available)

## Controls

- **A/D or Arrow Keys**: Move left/right
- **Space**: Jump
- **Shift**: Dash
- **J or X**: Attack
- **S or Down Arrow**: Pound
- **K or C**: Throw

**Note**: The game is designed for keyboard/gamepad controls. Both work well on Steam Deck.

## Troubleshooting

### Game won't launch on Steam Deck

- Ensure the Linux executable is marked as **Executable**
- Check that the launch target is set correctly
- Try launching via the app rather than directly from Steam

### Web version not working

- Make sure all files are uploaded: `index.html`, `index.js`, `index.wasm`, `index.pck`
- Check browser console (F12) for errors
- Works best in modern browsers (Chrome, Firefox, Safari)

### Performance issues

- Linux build should run at 60fps on Steam Deck
- Web version may have reduced performance depending on browser
- Try the Linux version if web feels sluggish

## Next Steps

Once you've tested and confirmed it works:

1. Update the project description with any feedback you have
2. Consider making the project public to share with others
3. You can update the builds anytime by re-uploading

## Resources

- itch.io Documentation: https://itch.io/docs
- Steam Deck Verification: https://steamcommunity.com/steamdeck/verifying
- Godot Export: https://docs.godotengine.org/en/stable/tutorials/export/index.html

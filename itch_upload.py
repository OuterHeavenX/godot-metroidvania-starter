#!/usr/bin/env python3
"""
Upload game builds to itch.io using the API
"""

import os
import sys
import json
import subprocess
from pathlib import Path

# Configuration
ITCH_USER = "outerheavenX"
ITCH_GAME = "metroidvania-starter-test"
ITCH_TOKEN = os.environ.get("ITCH_TOKEN", "")
BUILD_DIR = Path("build/itch")

def log(msg):
    print(f"📤 {msg}")

def error(msg):
    print(f"❌ {msg}", file=sys.stderr)
    sys.exit(1)

def run(cmd, check=True):
    """Run a command and return output"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        error(f"Command failed: {cmd}\n{result.stderr}")
    return result.returncode, result.stdout, result.stderr

def zip_build(source_dir, output_zip):
    """Zip a build directory"""
    if not source_dir.exists():
        error(f"Build directory not found: {source_dir}")

    log(f"Zipping {source_dir.name}...")
    cmd = f"cd {source_dir.parent} && zip -q -r {output_zip.name} {source_dir.name}"
    rc, out, err = run(cmd)
    if rc != 0:
        error(f"Failed to zip: {err}")
    return output_zip

def upload_with_api(build_path, platform):
    """Upload using itch.io's HTTP API"""
    log(f"Uploading {platform} build to itch.io...")

    if not ITCH_TOKEN:
        error("ITCH_TOKEN environment variable not set")

    # The API endpoint for uploading builds
    # Documentation: https://itch.io/docs/api/overview

    url = f"https://itch.io/api/1/{ITCH_TOKEN}/wharf/files"

    # Prepare upload data
    files = {
        'upload': open(build_path, 'rb'),
        'channel': (None, platform),
        'game': (None, ITCH_GAME),
        'user': (None, ITCH_USER),
    }

    # Use curl for the upload (more reliable than requests library)
    cmd = f"""
    curl -X POST \
      -H "Authorization: Bearer {ITCH_TOKEN}" \
      -F "upload=@{build_path}" \
      -F "channel={platform}" \
      -F "game={ITCH_GAME}" \
      -F "user={ITCH_USER}" \
      "https://itch.io/api/1/{ITCH_TOKEN}/wharf/files" \
      -w "\\nHTTP Status: %{{http_code}}\\n"
    """

    log(f"Uploading {build_path.name}...")
    rc, out, err = run(cmd, check=False)

    if rc != 0:
        print(f"Output: {out}")
        print(f"Error: {err}")
        error(f"Upload failed for {platform}")

    print(out)
    return True

def main():
    log("Starting itch.io upload process")
    log(f"User: {ITCH_USER}, Game: {ITCH_GAME}")
    print()

    # Check builds exist
    linux_dir = BUILD_DIR / "linux"
    web_dir = BUILD_DIR / "web"

    if not linux_dir.exists() and not web_dir.exists():
        error(f"No builds found in {BUILD_DIR}")

    # Zip the builds
    linux_zip = BUILD_DIR / "metroidvania-linux.zip"
    web_zip = BUILD_DIR / "metroidvania-web.zip"

    if linux_dir.exists():
        zip_build(linux_dir, linux_zip)
        upload_with_api(linux_zip, "linux")
        log(f"✓ Linux build uploaded")

    if web_dir.exists():
        zip_build(web_dir, web_zip)
        upload_with_api(web_zip, "web")
        log(f"✓ Web build uploaded")

    print()
    print("✨ Upload complete!")
    print(f"🎮 Your game: https://itch.io/game/{ITCH_GAME}")
    print(f"📊 Dashboard: https://itch.io/dashboard")

if __name__ == "__main__":
    main()

"""Run Godot suites with isolated saves and fail on script errors or missing success markers."""
import argparse
import re
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("engine")
parser.add_argument("--suite", action="append", help="Runner basename; repeat to select suites")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
logs = root / "build/test-results"
logs.mkdir(parents=True, exist_ok=True)
scenes = [root / "tests/runners/check_scripts.tscn"] + sorted((root / "tests/runners").glob("run_*.tscn"))
if args.suite:
    scenes = [scene for scene in scenes if scene.stem in args.suite]
    if len(scenes) != len(set(args.suite)):
        parser.error("Unknown suite name")
# A .tres or .tscn that names a resource it never defines fails to parse, and
# the whole file goes with it -- a level that will not load at all. Godot only
# complains when something tries to load it, so it surfaces as a suite hanging
# rather than as an error pointing at the file. Catch it by reading instead.
dangling = []
for path in sorted(root.rglob("*.tres")) + sorted(root.rglob("*.tscn")):
    if ".godot" in path.parts or "build" in path.parts:
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    for kind in ("sub_resource", "ext_resource"):
        defined = set(re.findall(r'^\[' + kind + r' [^\]]*id="([^"]+)"', text, re.M))
        used = set(re.findall(kind.title().replace("_", "") + r'\("([^"]+)"\)', text))
        for name in sorted(used - defined):
            dangling.append(f"{path.relative_to(root)}: {kind} \"{name}\" referenced but never defined")
for line in dangling:
    print("DANGLING", line, flush=True)

failed = []
for scene in scenes:
    with tempfile.TemporaryDirectory() as temp:
        env = dict(os.environ, APPDATA=temp, XDG_DATA_HOME=temp)
        try:
            result = subprocess.run([args.engine, "--headless", "--path", str(root), "--scene", "res://" + scene.relative_to(root).as_posix()], capture_output=True, text=True, timeout=240, env=env)
            output = result.stdout + result.stderr
            good = result.returncode == 0 and ("PASSED" in output or "SCRIPT CHECK OK:" in output) and not any(token in output for token in ["FAIL:", "FAILURES", "SCRIPT ERROR:", "Parse Error", "  FAIL "])
        except subprocess.TimeoutExpired as expired:
            # Keep whatever the suite managed to print. Throwing it away turned
            # a hang into the single word TIMEOUT, which says nothing about
            # whether it stalled on the first assertion or after the last one.
            partial = (expired.stdout or "") + (expired.stderr or "")
            if isinstance(partial, bytes):
                partial = partial.decode("utf-8", "replace")
            output = "TIMEOUT after %ss. Output up to that point:\n%s" % (
                expired.timeout, partial or "(the suite printed nothing at all)")
            good = False
        (logs / (scene.stem + ".log")).write_text(output)
        print(scene.stem, "PASS" if good else "FAIL", flush=True)
        if not good:
            failed.append(scene.stem)
            print(output[-3000:], flush=True)
print(f"{len(scenes) - len(failed)}/{len(scenes)} suites passed")
raise SystemExit(bool(failed) or bool(dangling))

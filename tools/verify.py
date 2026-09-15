"""Run Godot suites with isolated saves and fail on script errors or missing success markers."""
import argparse
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
failed = []
for scene in scenes:
    with tempfile.TemporaryDirectory() as temp:
        env = dict(os.environ, APPDATA=temp, XDG_DATA_HOME=temp)
        try:
            result = subprocess.run([args.engine, "--headless", "--path", str(root), "--scene", "res://" + scene.relative_to(root).as_posix()], capture_output=True, text=True, timeout=120, env=env)
            output = result.stdout + result.stderr
            good = result.returncode == 0 and ("PASSED" in output or "SCRIPT CHECK OK:" in output) and not any(token in output for token in ["FAIL:", "FAILURES", "SCRIPT ERROR:", "Parse Error", "  FAIL "])
        except subprocess.TimeoutExpired:
            output, good = "TIMEOUT", False
        (logs / (scene.stem + ".log")).write_text(output)
        print(scene.stem, "PASS" if good else "FAIL", flush=True)
        if not good:
            failed.append(scene.stem)
            print(output[-3000:], flush=True)
print(f"{len(scenes) - len(failed)}/{len(scenes)} suites passed")
raise SystemExit(bool(failed))

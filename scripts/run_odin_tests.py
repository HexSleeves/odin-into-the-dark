#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build" / "test-packages"
SRC_WORK = WORK / "src"
TEST_ROOT = ROOT / "test"

DEFAULT_PACKAGE_DIRS = [
    "src",
    "src/engine",
    "src/audio",
    "src/io",
    "src/ui",
    "src/render",
]


def copy_tree() -> None:
    if WORK.exists():
        shutil.rmtree(WORK)
    shutil.copytree(
        ROOT / "src",
        SRC_WORK,
        ignore=shutil.ignore_patterns("*_test.odin"),
    )
    data_src = ROOT / "data"
    if data_src.exists():
        shutil.copytree(data_src, WORK / "data")


def overlay_tests() -> None:
    if not TEST_ROOT.exists():
        return
    for test_file in TEST_ROOT.rglob("*_test.odin"):
        rel = test_file.relative_to(TEST_ROOT)
        dest = SRC_WORK / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(test_file, dest)


def run_package(package: str, args: list[str]) -> int:
    path = WORK / package
    if not path.exists():
        return 0
    cmd = ["odin", "test", str(path), f"-collection:libs={ROOT / 'vendor'}"] + args
    print("$", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=ROOT).returncode

def main() -> int:
    args = sys.argv[1:]
    package_dirs = list(DEFAULT_PACKAGE_DIRS)
    if "--root-only" in args:
        args = [arg for arg in args if arg != "--root-only"]
        package_dirs = ["src"]
    copy_tree()
    overlay_tests()
    for package in package_dirs:
        code = run_package(package, args)
        if code != 0:
            return code
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

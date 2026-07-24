from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    static = root / "app" / "static"
    source = static / "logo-saeng.png"
    target = static / "saeng.ico"
    if not source.exists():
        print(f"Logo nao encontrada: {source}")
        return 2
    with Image.open(source) as image:
        rgba = image.convert("RGBA")
        rgba.save(target, format="ICO", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print(f"Icone criado: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

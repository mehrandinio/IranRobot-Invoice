#!/usr/bin/env python3
"""Fetch Vazirmatn fonts for offline Flutter/PDF packaging."""
from pathlib import Path
from urllib.request import urlretrieve

dest = Path(__file__).resolve().parents[1] / "assets" / "fonts"
dest.mkdir(parents=True, exist_ok=True)
base = "https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.003/fonts/ttf/"
for name in ("Vazirmatn-Regular.ttf", "Vazirmatn-Bold.ttf"):
    path = dest / name
    if not path.exists() or path.stat().st_size < 50000:
        urlretrieve(base + name, path)
    if path.stat().st_size < 50000:
        raise RuntimeError("Font download failed: " + name)
print("Fonts ready (SIL OFL 1.1)")

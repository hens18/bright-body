"""Download photo scanned CC0 textures from Poly Haven into the game's texture sets.

Each set in SETS maps one of our material folders to a Poly Haven texture. The
color, normal (OpenGL), roughness and ambient occlusion maps are saved as
game/assets/textures/<set>/{albedo,normal,roughness,ao}.jpg, replacing whatever was
there, and the source is recorded in game/assets/textures/SOURCES.md.

Usage, from the repo root (standard library only, needs network access to
api.polyhaven.com and dl.polyhaven.org):

    python tools/textures/fetch_polyhaven.py              # all sets
    python tools/textures/fetch_polyhaven.py castle_wall  # one set

To try a different texture, change its id below and run the script again. Browse
them at https://polyhaven.com/textures. The texture's real world size is printed;
set the material's uv1_scale to 1 / size in meters so it appears at true scale.
"""

import json
import pathlib
import sys
import urllib.request

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = REPO_ROOT / "game" / "assets" / "textures"

# Our set name: (Poly Haven id, resolution). 2k for large, close surfaces.
SETS = {
    "castle_wall": ("castle_wall_varriation", "2k"),
    "flagstone": ("monastery_stone_floor", "2k"),
    "cut_stone": ("medieval_blocks_03", "1k"),
    "old_wood": ("old_planks_02", "1k"),
    "dark_iron": ("rusty_metal_02", "1k"),
}
MAPS = {"albedo": "Diffuse", "normal": "nor_gl", "roughness": "Rough", "ao": "AO"}
# Poly Haven asks API users to identify themselves; the default Python agent is refused.
HEADERS = {"User-Agent": "bright-body-texture-fetch/1.0 (https://github.com/hens18/bright-body)"}


def get_json(url: str) -> dict:
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS)) as response:
        return json.load(response)


def download(url: str, path: pathlib.Path) -> None:
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS)) as response:
        path.write_bytes(response.read())


def fetch(set_name: str) -> str:
    asset_id, resolution = SETS[set_name]
    files = get_json(f"https://api.polyhaven.com/files/{asset_id}")
    info = get_json(f"https://api.polyhaven.com/info/{asset_id}")
    folder = OUT_DIR / set_name
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.png*"):  # Generated stand ins, replaced by the scans.
        old.unlink()
    for our_name, their_name in MAPS.items():
        url = files[their_name][resolution]["jpg"]["url"]
        download(url, folder / f"{our_name}.jpg")
    size_m = info["dimensions"][0] / 1000.0
    print(f"{set_name}: {info['name']} ({resolution}, {size_m:g} m across)")
    return (f"| {set_name} | [{info['name']}](https://polyhaven.com/a/{asset_id}) | {resolution} "
            f"| {size_m:g} m | {', '.join(info.get('authors', {}))} |")


def main() -> None:
    names = sys.argv[1:] or list(SETS)
    rows = [fetch(name) for name in names]
    sources = OUT_DIR / "SOURCES.md"
    existing = {}
    if sources.exists():
        for line in sources.read_text().splitlines():
            if line.startswith("| ") and not line.startswith("| Set") and not line.startswith("| ---"):
                existing[line.split("|")[1].strip()] = line
    for row in rows:
        existing[row.split("|")[1].strip()] = row
    sources.write_text(
        "# Texture sources\n\n"
        "Photo scanned textures from [Poly Haven](https://polyhaven.com), licensed\n"
        "[CC0](https://polyhaven.com/license): free for any use, no credit required.\n"
        "Downloaded with `tools/textures/fetch_polyhaven.py`.\n\n"
        "| Set | Texture | Resolution | Real world size | Authors |\n| --- | --- | --- | --- | --- |\n"
        + "\n".join(existing[k] for k in sorted(existing)) + "\n")


if __name__ == "__main__":
    main()

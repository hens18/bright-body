"""Generate seamless PBR texture sets for the medieval environment.

Every texture is built from periodic noise, so it tiles with no seams. Each set is
written to game/assets/textures/<name>/ as:

    albedo.jpg      base color (sRGB)
    normal.jpg      tangent space normal map, OpenGL convention (what Godot expects)
    roughness.jpg   grayscale, white = rough
    ao.jpg          ambient occlusion from the height field

Usage, from the repo root (needs numpy and pillow):

    python tools/textures/generate_textures.py            # all sets
    python tools/textures/generate_textures.py castle_wall # one set

These are offline stand ins. The game currently uses photo scanned CC0 textures
from Poly Haven (see fetch_polyhaven.py and game/assets/textures/SOURCES.md);
running this script overwrites them with generated versions.
"""

import pathlib
import sys

import numpy as np
from PIL import Image

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = REPO_ROOT / "game" / "assets" / "textures"
SIZE = 1024


# Noise ----------------------------------------------------------------------

def fbm(rng: np.random.Generator, size: int = SIZE, beta: float = 2.0, low: float = 1.0,
        stretch: tuple = (1.0, 1.0)) -> np.ndarray:
    """Periodic fractal noise in [0, 1], made by shaping white noise in frequency space.

    beta sets roughness (higher = smoother), low removes frequencies below it and
    stretch squashes frequencies per axis for grain like patterns.
    """
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None] * size / stretch[1]
    fx = np.fft.fftfreq(size)[None, :] * size / stretch[0]
    freq = np.sqrt(fx * fx + fy * fy)
    freq[0, 0] = 1.0
    amplitude = 1.0 / freq ** (beta / 2.0)
    amplitude[freq < low] = 0.0
    field = np.real(np.fft.ifft2(np.fft.fft2(white) * amplitude))
    return normalize(field)


def normalize(field: np.ndarray) -> np.ndarray:
    lo, hi = np.percentile(field, 0.5), np.percentile(field, 99.5)
    return np.clip((field - lo) / (hi - lo + 1e-9), 0.0, 1.0)


def voronoi(rng: np.random.Generator, cells: int, size: int = SIZE, jitter: float = 0.8):
    """Periodic Voronoi on a jittered grid. Returns (F1, F2, cell index) per pixel,
    distances in units of one grid cell."""
    grid = int(round(np.sqrt(cells)))
    centers = (np.stack(np.meshgrid(np.arange(grid), np.arange(grid), indexing="xy"), -1).reshape(-1, 2)
               + 0.5 + (rng.random((grid * grid, 2)) - 0.5) * jitter) / grid
    coords = (np.arange(size) + 0.5) / size
    px, py = np.meshgrid(coords, coords, indexing="xy")
    f1 = np.full((size, size), np.inf, np.float32)
    f2 = np.full((size, size), np.inf, np.float32)
    ids = np.zeros((size, size), np.int32)
    for index, (cx, cy) in enumerate(centers):
        dx = np.abs(px - cx)
        dy = np.abs(py - cy)
        dx = np.minimum(dx, 1.0 - dx)  # Wrap around: this is what makes it tile.
        dy = np.minimum(dy, 1.0 - dy)
        d = np.sqrt(dx * dx + dy * dy).astype(np.float32) * grid
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        ids = np.where(closer, index, ids)
        f1 = np.where(closer, d, f1)
    return f1, f2, ids


def blocks(columns: int, rows: int, offset: float = 0.5, size: int = SIZE, rng: np.random.Generator = None):
    """Block layout. Rows alternate by `offset`, or get random offsets when rng is
    given (less regular, more hand laid). Returns (distance to nearest joint in row
    heights, block index, u and v inside the block)."""
    coords = (np.arange(size) + 0.5) / size
    u, v = np.meshgrid(coords, coords, indexing="xy")
    row = np.floor(v * rows)
    row_offsets = rng.random(rows) if rng is not None else (np.arange(rows) % 2) * offset
    x = u * columns + row_offsets[row.astype(np.int32)]
    col = np.floor(x) % columns
    local_u = x - np.floor(x)
    local_v = v * rows - row
    # Blocks are wider than tall, so measure the joint distance in real proportions.
    aspect = rows / columns
    edge = np.minimum(np.minimum(local_u, 1 - local_u) * aspect, np.minimum(local_v, 1 - local_v))
    index = (row * columns + col).astype(np.int32)
    return edge, index, local_u, local_v


def per_cell(index: np.ndarray, rng: np.random.Generator, count: int) -> np.ndarray:
    return rng.random(count)[index]


# Output ---------------------------------------------------------------------

def normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    # np.roll wraps around, so the normal map tiles too.
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * strength
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * strength
    n = np.stack([-dx, dy, np.ones_like(height)], -1)  # +Y up in the map (OpenGL convention).
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def ao_from_height(height: np.ndarray, radius: int = 12, strength: float = 1.6) -> np.ndarray:
    blurred = height.copy()
    for step in (1, 2, 4, 8, radius):
        blurred = (blurred + np.roll(blurred, step, 0) + np.roll(blurred, -step, 0)
                   + np.roll(blurred, step, 1) + np.roll(blurred, -step, 1)) / 5.0
    return np.clip(1.0 - np.maximum(blurred - height, 0.0) * strength, 0.0, 1.0)


def save(name: str, albedo: np.ndarray, height: np.ndarray, roughness: np.ndarray,
         normal_strength: float, ao_strength: float = 1.6) -> None:
    folder = OUT_DIR / name
    folder.mkdir(parents=True, exist_ok=True)
    ao = ao_from_height(height, strength=ao_strength)
    to8 = lambda a: (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(to8(albedo)).save(folder / "albedo.jpg", quality=92)
    Image.fromarray(to8(normal_from_height(height, normal_strength))).save(folder / "normal.jpg", quality=95)
    Image.fromarray(to8(roughness)).save(folder / "roughness.jpg", quality=92)
    Image.fromarray(to8(ao)).save(folder / "ao.jpg", quality=92)
    print(f"wrote {folder.relative_to(REPO_ROOT)}")


def tint(base: tuple, amount: np.ndarray) -> np.ndarray:
    return np.asarray(base, np.float32)[None, None, :] * amount[..., None]


# Texture sets ---------------------------------------------------------------

def castle_wall(rng: np.random.Generator) -> None:
    """Weathered limestone blocks in a running bond, recessed mortar. Tile = 2 m."""
    edge, index, lu, lv = blocks(columns=4, rows=8, rng=rng)
    cells = 32
    mortar_width = 0.045
    bevel = np.clip(edge / 0.12, 0.0, 1.0) ** 0.6  # Rounded, worn block edges.
    chips = fbm(rng, beta=1.6, low=6.0)
    worn = np.clip((0.1 - edge) * 12 + (chips - 0.55) * 2.5, 0, 1)  # Chipped corners.
    face = fbm(rng, beta=2.2, low=2.0)
    fine = fbm(rng, beta=1.2, low=40.0)
    block_tilt = (per_cell(index, rng, cells) - 0.5) * (lu - 0.5) * 0.08
    is_mortar = edge < mortar_width
    stone_height = 0.55 + 0.35 * bevel - 0.25 * worn + 0.12 * face + 0.05 * fine + block_tilt
    mortar_height = 0.15 + 0.1 * fine
    height = np.where(is_mortar, mortar_height, stone_height)

    shade = 0.78 + 0.3 * per_cell(index, rng, cells) + 0.25 * (face - 0.5) + 0.1 * (fine - 0.5)
    warmth = per_cell(index, rng, cells)[..., None]
    stone = tint((0.62, 0.58, 0.52), shade) * (1 - 0.25 * warmth) + tint((0.6, 0.52, 0.42), shade) * 0.25 * warmth
    grime = fbm(rng, beta=2.6, low=1.0)
    stone *= (0.75 + 0.35 * grime)[..., None]
    mortar = tint((0.42, 0.4, 0.37), 0.85 + 0.3 * fine)
    # Grime collects along the joints.
    stone *= (0.8 + 0.2 * np.clip(edge / 0.15, 0, 1))[..., None]
    moss = np.clip((fbm(rng, beta=2.4, low=2.0) - 0.7) * 5, 0, 1) * np.clip(1 - edge / 0.12, 0, 1)
    mortar = mortar * (1 - moss[..., None]) + tint((0.2, 0.26, 0.12), 0.9 + 0.2 * fine) * moss[..., None]
    albedo = np.where(is_mortar[..., None], mortar, stone) * (1 - 0.35 * worn[..., None])
    roughness = np.where(is_mortar, 0.95, 0.72 + 0.2 * fine - 0.1 * face)
    save("castle_wall", albedo, height, roughness, normal_strength=18.0)


def flagstone(rng: np.random.Generator) -> None:
    """Irregular paving stones with dirt filled joints. Tile = 4 m."""
    f1, f2, ids = voronoi(rng, cells=36)
    cells = ids.max() + 1
    gap = f2 - f1
    joint = np.clip(gap / 0.09, 0.0, 1.0)
    bevel = np.clip(gap / 0.35, 0.0, 1.0) ** 0.5
    face = fbm(rng, beta=2.2, low=2.0)
    fine = fbm(rng, beta=1.1, low=60.0)
    cracks = fbm(rng, beta=1.8, low=8.0)
    crack_lines = np.clip(1 - np.abs(cracks - 0.5) * 40, 0, 1) * (per_cell(ids, rng, cells) > 0.6)
    in_joint = joint < 1.0
    height = np.where(in_joint, 0.1 + 0.3 * joint * bevel, 0.55 + 0.3 * bevel + 0.1 * face + 0.04 * fine
                      + (per_cell(ids, rng, cells) - 0.5) * 0.1) - 0.15 * crack_lines

    shade = 0.75 + 0.35 * per_cell(ids, rng, cells) + 0.2 * (face - 0.5)
    hue = per_cell(ids, rng, cells)[..., None]
    stone = tint((0.5, 0.49, 0.46), shade) * (1 - hue * 0.3) + tint((0.52, 0.46, 0.38), shade) * hue * 0.3
    stone *= (0.8 + 0.25 * fbm(rng, beta=2.8, low=1.0))[..., None]
    stone *= (0.78 + 0.22 * bevel)[..., None]  # Darker toward the joints.
    dirt = tint((0.24, 0.21, 0.17), 0.8 + 0.4 * fine)
    albedo = np.where(in_joint[..., None], dirt * (0.7 + 0.3 * joint[..., None]), stone)
    albedo *= (1 - 0.4 * crack_lines[..., None])
    roughness = np.where(in_joint, 0.97, 0.68 + 0.2 * fine - 0.12 * face)
    save("flagstone", albedo, height, roughness, normal_strength=14.0)


def cut_stone(rng: np.random.Generator) -> None:
    """Large dressed ashlar blocks with thin joints, for pillars and plinths. Tile = 2 m."""
    edge, index, lu, lv = blocks(columns=2, rows=4, offset=0.5)
    cells = 8
    face = fbm(rng, beta=2.0, low=3.0)
    fine = fbm(rng, beta=1.0, low=80.0)
    tool = fbm(rng, beta=1.4, low=20.0, stretch=(1.0, 0.2))  # Chisel marks.
    joint = edge < 0.02
    bevel = np.clip(edge / 0.06, 0, 1) ** 0.5
    height = np.where(joint, 0.2, 0.6 + 0.2 * bevel + 0.08 * face + 0.04 * tool + 0.03 * fine)
    shade = 0.82 + 0.2 * per_cell(index, rng, cells) + 0.2 * (face - 0.5) + 0.08 * (tool - 0.5)
    albedo = tint((0.66, 0.63, 0.58), shade) * (0.85 + 0.2 * fbm(rng, beta=2.6, low=1.0))[..., None]
    albedo = np.where(joint[..., None], albedo * 0.55, albedo)
    roughness = 0.62 + 0.25 * fine - 0.1 * face
    save("cut_stone", albedo, height, roughness, normal_strength=10.0)


def old_wood(rng: np.random.Generator) -> None:
    """Weathered oak planks running vertically. Tile = 1 m."""
    planks = 5
    coords = (np.arange(SIZE) + 0.5) / SIZE
    u, v = np.meshgrid(coords, coords, indexing="xy")
    plank = np.floor(u * planks).astype(np.int32)
    local = u * planks - plank
    # Planks have staggered ends so boards don't all line up.
    ends = (v + rng.random(planks)[plank]) % 1.0
    board = (ends * 2).astype(np.int32)
    board_id = plank * 2 + board
    end_gap = np.minimum((ends * 2) % 1.0, 1 - (ends * 2) % 1.0)
    gap = np.minimum(np.minimum(local, 1 - local) * 0.2 * planks, end_gap * 2.0)
    grain = fbm(rng, beta=1.6, low=2.0, stretch=(1.0, 0.06))  # Smooth along the board.
    rings = np.sin((grain * 18 + local * 3 + rng.random(planks * 2)[board_id] * 6) * np.pi) * 0.5 + 0.5
    fine = fbm(rng, beta=1.2, low=50.0, stretch=(1.0, 0.15))
    is_gap = gap < 0.012
    height = np.where(is_gap, 0.1, 0.6 + 0.12 * rings + 0.1 * fine + 0.2 * np.clip(gap / 0.05, 0, 1))
    streaks = fbm(rng, beta=1.0, low=30.0, stretch=(1.0, 0.03))
    shade = (0.7 + 0.4 * rng.random(planks * 2)[board_id] + 0.45 * (rings - 0.5) + 0.2 * (fine - 0.5)
             + 0.3 * (streaks - 0.5))
    albedo = tint((0.42, 0.3, 0.19), shade)
    albedo = np.where(is_gap[..., None], albedo * 0.3, albedo)
    roughness = 0.78 + 0.15 * fine - 0.08 * rings
    save("old_wood", albedo, height, roughness, normal_strength=8.0)


def dark_iron(rng: np.random.Generator) -> None:
    """Blackened forged iron with rust in the pits. Tile = 0.5 m."""
    face = fbm(rng, beta=2.2, low=2.0)
    pits = fbm(rng, beta=1.4, low=30.0)
    rust = np.clip((fbm(rng, beta=2.4, low=3.0) - 0.62) * 4 + (0.5 - pits) * 1.5, 0, 1)
    height = 0.6 + 0.15 * face - 0.2 * np.clip(0.35 - pits, 0, 1)
    iron = tint((0.2, 0.2, 0.21), 0.85 + 0.3 * face)
    albedo = iron * (1 - rust[..., None]) + tint((0.4, 0.2, 0.09), 0.8 + 0.4 * pits) * rust[..., None]
    roughness = 0.45 + 0.25 * face + 0.3 * rust
    save("dark_iron", albedo, height, roughness, normal_strength=6.0)


SETS = {f.__name__: f for f in (castle_wall, flagstone, cut_stone, old_wood, dark_iron)}


def main() -> None:
    names = sys.argv[1:] or list(SETS)
    for index, name in enumerate(names):
        SETS[name](np.random.default_rng(1000 + list(SETS).index(name)))


if __name__ == "__main__":
    main()

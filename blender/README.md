# Blender assets

Source art lives in `source/` as `.blend` files. The game only reads the exported `.glb` files in
`game/assets/models/`, so people without Blender can still run the game.

## Exporting

From the repo root:

```
blender -b blender/source/<name>.blend -P blender/scripts/export_glb.py
```

This writes `game/assets/models/<name>.glb`. Pass `-- --out some/path.glb` to choose another path.
If the file has a collection named **Export**, only that collection is exported, so reference images,
cameras and helpers can stay in the file.

You can also export by hand with *File > Export > glTF 2.0*, format **glTF Binary (.glb)**, with
*Apply Modifiers* on.

## Conventions

- **Scale**: 1 Blender unit = 1 meter. The hero is about 1.9 m tall.
- **Facing**: characters face **-Y** in Blender (the Front view looks at their face). They arrive in Godot
  facing +Z, so the player scene rotates the model 180 degrees under `Player/Visual`.
- **Origin**: at the feet, centered.
- **Apply transforms** (Ctrl+A > All Transforms) before exporting.
- **Materials**: name the armor material `Body` and the trim material `Accent`. The game recolors those two
  with the player's chosen colors, so keep them light and neutral enough to tint well.
- **Animations**: one action per move, named exactly as the game expects. Every action is exported.

| Action name | Used for |
| --- | --- |
| `Idle`, `Run` | Locomotion (set to loop automatically) |
| `Jump` | While airborne |
| `Attack1`, `Attack2`, `Attack3` | Melee combo, about 0.42 s each |
| `Shoot` | Firing while aiming |
| `Dodge` | Dodge roll, about 0.35 s |
| `Hurt`, `Death` | Taking damage, dying |

Missing actions are simply skipped, so a model can start with just `Idle` and `Run`.

## Level pieces and collision

Godot reads name suffixes on Blender objects when importing:

- `Wall-col`: mesh plus a matching static collision shape.
- `Wall-colonly`: collision only, invisible (good for simplified collision meshes).
- `Crate-rigid`: becomes a physics rigid body.

This lets whole level chunks be modeled in Blender and dropped into a Godot scene.

## Scripts

- `scripts/export_glb.py`: exports the open file to `.glb` (see above).
- `scripts/build_placeholder_hero.py`: generates `source/hero_placeholder.blend` and its `.glb`, a blocky
  rigged hero with every animation above. Run with `blender -b -P blender/scripts/build_placeholder_hero.py`.
  Use it as a reference for bone names and action timing when building the real hero.

## Swapping in a new hero

1. Export the new model to `game/assets/models/hero.glb`.
2. Open `game/scenes/player/player.tscn`, delete `Visual/Hero`, and drag `hero.glb` under `Visual`.
   Rename the new node to `Hero` so customization finds it.
3. Rotate it 180 degrees on Y so it faces the same way as `Visual/Muzzle` (Godot's -Z).

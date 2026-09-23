# Bright Body: design notes

A living document. Decisions go in **Decided**; things still to settle go in **Open questions**.

## Decided

- **Genre**: 3D action adventure.
- **Tools**: Blender for models and animation, Godot 4 (GDScript) for the game.
- **Camera**: third person, over the shoulder, with lock on.
- **Combat**: mixed melee and ranged.
  - Melee: three hit combo, costs stamina, can be cancelled into a dodge after the hit lands.
  - Ranged: hold aim for an over the shoulder view, then fire. Currently no ammo, just a cooldown.
  - Defense: dodge roll with invulnerability frames. Hitting an enemy during its windup staggers it.
- **Enemies so far**: Brute (melee) and Caster (ranged).

## Milestones

1. **Combat prototype** (done): greybox arena, hero, two enemy types, HUD, smoke test.
2. **Game feel pass**: hit stop, particles, sound effects, animation blending, camera polish.
3. **First real area**: a hand built level in Blender, enemy placement, checkpoints, a pickup.
4. **Progression**: whatever the answers below call for (abilities, upgrades, items, story beats).
5. **Vertical slice**: one polished area with a boss.

## Open questions

These shape the next milestones. Answers can be short.

1. **World and tone**: setting (fantasy, sci fi, mythic, modern)? Serious, light hearted, dark?
2. **The name**: what does "Bright Body" mean in the game? A character, a power, a place?
3. **Hero**: who are they, and what do they look like? Any reference art?
4. **Ranged weapon**: bow, gun, magic, thrown weapon? Limited ammo or mana, or free with cooldowns?
5. **World structure**: linear levels, hub with levels, or open, interconnected world?
6. **Progression**: new abilities that open new areas, skill tree, gear, or story only?
7. **Enemies and bosses**: themes, factions, a first boss idea?
8. **Art style**: low poly stylized, toon shaded, realistic? Target platforms (PC, console, web)?
9. **Scope**: rough length of the game, and is this solo or a team?

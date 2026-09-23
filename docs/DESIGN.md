# Bright Body: design notes

A living document. Decisions go in **Decided**. Proposals are my suggested way to meet those decisions and
are open to change. Things still to settle go in **Open questions**.

## Decided

| Topic | Decision |
| --- | --- |
| Genre | Medieval action adventure |
| Tools | Blender for art and animation, Godot 4 (GDScript) for the game |
| Team | Solo developer |
| Length | About 4 hours for a first playthrough |
| Hero | An unnamed avatar. The player names them and customizes their look (armor and trim colors, height, build). |
| Camera | Third person, over the shoulder, with lock on |
| Melee | Three hit combo, stamina cost, dodge roll with invulnerability frames |
| Ranged | Only bows, crossbows and magic |
| World | Open world |
| Progression | Skill tree that unlocks new abilities, plus gear |
| Bosses | Three boss fights, each harder than the last |
| Art style | Stylized gothic: stone arches, stained glass, candlelight. Chunky shapes and painted colors rather than realism. |
| Platform | PC only (keyboard/mouse first, gamepad supported) |
| Title | "Bright Body" is a working title only, with no story meaning |
| Skill tree | The three branch proposal below is approved |

### Ranged weapons (built)

| Weapon | Feel | Numbers (starting point) |
| --- | --- | --- |
| Longbow | Hold to draw, release to fire. Arrows arc. Full draw hits hard. | 10 to 28 damage, 0.8 s full draw |
| Crossbow | Fires instantly, flat and fast, then a long reload. | 32 damage, 1.1 s reload |
| Arcane Bolt | Glowing spell that homes in on the locked target. Costs mana. | 14 damage, 12 mana, 0.35 s cooldown |

Weapons are data files in `game/resources/weapons/`, so new bows, crossbows and spells are made by
copying a `.tres` file and changing numbers, with no code needed.

## Proposal: world and pacing

A compact open world fits a 4 hour game and a solo schedule. The idea is one handcrafted map, about
1 km across, with a central hub and three regions. Each region ends in a boss, and the cathedral at the
center holds the final fight.

```
               [ Region 2: Highlands ]
                          |
[ Region 1: Vale ] -- [ Hub: Cathedral town ] -- [ Region 3: Marsh ]
                          |
               [ The Cathedral (final boss) ]
```

- Regions 1 and 2 can be done in either order, and difficulty scales with how many bosses are down.
  Region 3 and the Cathedral open after two bosses.
- The world is streamed in chunks, so each region is its own Godot scene loaded near its border.

| Segment | Time |
| --- | --- |
| Opening and tutorial in the hub | 15 min |
| Region 1 exploration, side content | 55 min |
| Boss 1 | 10 min |
| Region 2 | 55 min |
| Boss 2 | 15 min |
| Region 3 | 50 min |
| The Cathedral and Boss 3 | 30 min |
| Travel, shopping, skill tree | 10 min |
| **Total** | **about 4 h** |

## Proposal: three bosses

Each boss teaches one lesson the next one builds on.

1. **The Warden** (Region 1). A slow, heavily armored knight. Teaches reading windups, dodging and
   punishing. One phase.
2. **The Hollow Choir** (Region 2). A floating caster with summoned adds. Teaches ranged combat, target
   switching with lock on, and managing mana. Two phases.
3. **Final boss** (the Cathedral, name to be decided). The final boss, fast and mixing melee with magic. Tests everything
   the player has learned. Three phases, with arena changes between them.

Difficulty increases through more health and damage, but mostly through shorter windups, longer combos,
more phases and new attack types.

## Skill tree and gear (approved)

Three branches, one per play style. Skill points come from bosses (3 each) and from shrines hidden in the
world (about 12), so about 21 points total. That is enough to finish one branch and dip into the others.

| Blade (melee) | Marksman (bow and crossbow) | Arcane (magic) |
| --- | --- | --- |
| Fourth combo hit | Faster bow draw | Mana regeneration |
| Charged heavy attack (ability) | Triple shot (ability) | Fireball, area damage (ability) |
| Parry and riposte (ability) | Piercing bolts | Chain lightning between enemies (ability) |
| Stamina cost down | Slow motion while aiming mid air | Ward: magic shield (ability) |
| Finisher on staggered enemies | Explosive bolts | Heal spell |

**Gear**: weapon (sword), bow, crossbow, armor, and a relic slot. Gear is found in chests and dropped by
bosses, and it changes numbers and adds perks (for example "arrows set enemies on fire"). There is no
random loot, since every item is handplaced. That keeps balancing manageable for a solo developer.

## Milestones

1. **Combat prototype** (done): greybox arena, hero, two enemy types, HUD, smoke test.
2. **Naming and ranged weapons** (done): title screen, longbow, crossbow, magic, mana.
2b. **Hero customization** (done): armor and trim colors, height and build, with a live 3D preview.
3. **Boss 1, The Warden**: boss framework (phases, health bar, arena), first boss fight.
4. **Skill tree and gear**: data driven skills, skill tree menu, equipment, save and load.
5. **Region 1 greybox**: open world streaming, hub, shrines, chests, enemy camps.
6. **Art pass on Region 1**: gothic kit in Blender (walls, arches, windows, props), lighting.
7. **Bosses 2 and 3, Regions 2 and 3.**
8. **Polish**: audio, menus, balancing, performance.

## Art direction

- **Stylized gothic**: exaggerated proportions (tall pointed arches, thick buttresses, chunky stonework),
  flat or lightly painted textures, strong color from stained glass and warm candlelight against cool stone.
- **Palette**: cool grey and blue stone, warm gold and orange light, saturated jewel tones in glass.
- **Lighting**: shafts of colored light through windows, candle clusters as local warm lights, fog for depth.
- **Modular kit**: walls, arches, pillars, windows, stairs and floor tiles built on a 2 m grid in Blender, so
  levels snap together in Godot. Collision via the `-col` / `-colonly` suffixes (see `blender/README.md`).
- **Characters**: blocky, readable silhouettes that match the placeholder hero's proportions.

## Hero customization (built)

Players choose armor color, trim color, height and build on the title screen. Choices are saved with the
name and applied to any hero model whose Blender materials are named `Body` (armor) and `Accent` (trim).
Planned additions once the real hero is modeled: helmet and hairstyle options, face and skin tone, and gear
that visibly changes the silhouette.

## Open questions

1. **Bosses**: do The Warden and The Hollow Choir fit your vision, and do you have a theme or name for the
   final boss?
2. **Story**: any premise yet? Why is the hero traveling, and what ties the three bosses together?
3. **Customization depth**: beyond colors and body shape, which options matter most (helmets, hair, faces,
   voice, body type)?

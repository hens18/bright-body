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
| Hero | An unnamed avatar. The player names them on the title screen. |
| Camera | Third person, over the shoulder, with lock on |
| Melee | Three hit combo, stamina cost, dodge roll with invulnerability frames |
| Ranged | Only bows, crossbows and magic |
| World | Open world |
| Progression | Skill tree that unlocks new abilities, plus gear |
| Bosses | Three boss fights, each harder than the last |
| Art style | "Cathedral": gothic architecture, stone, stained glass, candlelight (see open questions) |

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
3. **The Bright Body** (the Cathedral). The final boss, fast and mixing melee with magic. Tests everything
   the player has learned. Three phases, with arena changes between them.

Difficulty increases through more health and damage, but mostly through shorter windups, longer combos,
more phases and new attack types.

## Proposal: skill tree and gear

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
3. **Boss 1, The Warden**: boss framework (phases, health bar, arena), first boss fight.
4. **Skill tree and gear**: data driven skills, skill tree menu, equipment, save and load.
5. **Region 1 greybox**: open world streaming, hub, shrines, chests, enemy camps.
6. **Art pass on Region 1**: gothic kit in Blender (walls, arches, windows, props), lighting.
7. **Bosses 2 and 3, Regions 2 and 3.**
8. **Polish**: audio, menus, balancing, performance.

## Open questions

1. **"Cathedral" art style**: I read this as a gothic medieval look (stone, arches, stained glass,
   candlelight). Is that right, or did you mean something else, such as a specific game's look?
2. **Realism**: realistic proportions and textures, or stylized (chunkier shapes, painted look)?
   Stylized is much faster for a solo artist.
3. **Story**: what is "Bright Body"? My placeholder makes it the final boss, a corrupted holy relic.
4. **Platforms**: PC only, or also consoles or Steam Deck?
5. **Hero appearance**: since the hero is an avatar, should players also pick a look (body, face, colors),
   or just the name?
6. **Bosses and skill tree**: do the proposals above fit your vision? What would you change?

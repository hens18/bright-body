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
| Hero | An unnamed avatar. The player names them and customizes their body only: skin tone, hair color, hairstyle, height and build. |
| Starting gear | The hero starts with no armor. All armor is found in loot chests. |
| Story | None for now |
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
| Bosses | The three boss proposal below is approved |

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

## Three bosses (approved)

Each boss teaches one lesson the next one builds on.

1. **The Warden** (Region 1). A slow, heavily armored knight. Teaches reading windups, dodging and
   punishing. One phase.
2. **The Hollow Choir** (Region 2). A floating caster with summoned adds. Teaches ranged combat, target
   switching with lock on, and managing mana. Two phases.
3. **Final boss** (the Cathedral, name to be decided). Fast, mixing melee with magic. Tests everything the
   player has learned. Three phases, with arena changes between them.

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
3. **Hero customization** (done): skin, hair color and style, height and build, with a live 3D preview.
4. **Armor from loot chests** (done): four iron pieces, defense, chests that stay opened, saved equipment.
5. **Boss 1, The Warden**: boss framework (phases, health bar, arena), first boss fight.
6. **Skill tree and inventory**: data driven skills, skill tree menu, inventory and equipment screen.
7. **Region 1 greybox**: open world streaming, hub, shrines, chests, enemy camps.
8. **Art pass on Region 1**: gothic kit in Blender (walls, arches, windows, props), lighting.
9. **Bosses 2 and 3, Regions 2 and 3.**
10. **Polish**: audio, menus, balancing, performance.

## Art direction

- **Stylized gothic**: exaggerated proportions (tall pointed arches, thick buttresses, chunky stonework),
  flat or lightly painted textures, strong color from stained glass and warm candlelight against cool stone.
- **Palette**: cool grey and blue stone, warm gold and orange light, saturated jewel tones in glass.
- **Lighting**: shafts of colored light through windows, candle clusters as local warm lights, fog for depth.
- **Modular kit**: walls, arches, pillars, windows, stairs and floor tiles built on a 2 m grid in Blender, so
  levels snap together in Godot. Collision via the `-col` / `-colonly` suffixes (see `blender/README.md`).
- **Characters**: blocky, readable silhouettes that match the placeholder hero's proportions.

## Hero customization (built)

Customization is bodily only: skin tone, hair color, hairstyle (bald, short, long), height and build, chosen on
the title screen with a live preview. Choices are saved with the name. Face shapes and more hairstyles can come
once the real hero model exists.

## Armor and loot chests (built)

- The hero starts in a plain tunic. Armor comes from loot chests, one piece per slot: head, chest, hands, legs.
- Each piece adds defense. Damage taken is scaled by 100 / (100 + defense), so 50 defense takes a third less
  damage. This formula never reaches zero, so armor always helps without making the hero invincible.
- Picking up a piece equips it straight away if it is at least as good as what is worn. Once there is an
  inventory screen (skill tree milestone), players will also be able to swap pieces by hand.
- Armor shows on the hero: each piece is its own mesh in the Blender model, and helmets hide the hair.
- Opened chests are remembered in the save, so they stay empty. Starting a new game from the title screen
  clears armor and closes every chest.
- The arena has the four iron pieces (38 defense total). Later sets (steel, then boss rewards) raise defense
  along with the rising boss difficulty.

## Open questions

1. **Armor tiers**: how many sets across the game? My suggestion: iron (Region 1), steel (Region 2), then a
   unique set from each boss, about 5 sets in total.
2. **Weapon loot**: should better swords, bows and crossbows also come from chests, or only armor?
3. **Death**: when the hero dies, restart at the last checkpoint with no penalty, or drop something (souls
   style) that can be recovered?

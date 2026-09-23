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
| Starting gear | A worn sword and a plain tunic. No armor and no ranged weapons. |
| Armor | Found only in loot chests. Five tiers: iron, steel, then one unique set per boss. |
| Weapons | Low tier swords, bows, crossbows and spells are in loot chests. Higher tiers drop from enemies, mini bosses and bosses. |
| Death | The hero respawns at the last lit checkpoint shrine with no penalty. Enemies respawn; chests, mini bosses and bosses stay done. |
| Story | None for now |
| Camera | Third person, over the shoulder, with lock on |
| Melee | Three hit combo, stamina cost, dodge roll with invulnerability frames |
| Ranged | Only bows, crossbows and magic |
| World | Open world |
| Progression | Skill tree that unlocks new abilities, plus gear |
| Bosses | Three boss fights, each harder than the last |
| Art style | Realistic gothic medieval: stone arches, stained glass, candlelight, physically based textures. |
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
5. **Weapon loot, mini boss and checkpoints** (done): chest and drop weapons, the Brute Captain, shrines.
6. **Boss 1, The Warden**: boss framework (phases, health bar, arena), first boss fight.
7. **Skill tree and inventory**: data driven skills, skill tree menu, inventory and equipment screen.
8. **Region 1 greybox**: open world streaming, hub, shrines, chests, enemy camps.
9. **Art pass on Region 1**: gothic kit in Blender (walls, arches, windows, props), lighting.
10. **Bosses 2 and 3, Regions 2 and 3.**
11. **Polish**: audio, menus, balancing, performance.

## Art direction

Realistic, replacing the earlier stylized plan.

- **Materials**: physically based (PBR) textures on everything: base color, normal, roughness and ambient
  occlusion maps. Environment materials live in `game/resources/materials/` and use world space triplanar
  mapping, so level geometry needs no UV unwrapping.
- **Textures**: photo scanned CC0 textures from Poly Haven, downloaded by `tools/textures/fetch_polyhaven.py`
  and listed in `game/assets/textures/SOURCES.md`, shown at their real world scale. Swapping a texture is a
  one line change in that script. `tools/textures/generate_textures.py` remains as an offline fallback.
- **Lighting**: low warm sun with soft shadows, neutral ambient fill, screen space ambient occlusion and
  indirect light, volumetric fog for depth, ACES tone mapping. Candles and shrines as warm local lights.
- **Architecture**: gothic castle and cathedral: tall stone walls with battlements, columns with bases and
  capitals, pointed arches and stained glass to come.
- **Characters**: the blocky placeholder hero and capsule enemies must be replaced with realistic rigged
  models (see open questions).

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
- The arena has the four iron pieces (44 defense total).

## Loot tiers (built)

| Tier | Armor (chests only) | Weapons | Where weapons come from |
| --- | --- | --- | --- |
| 1 | Iron set | Iron Sword, Hunting Bow, Light Crossbow, Arcane Bolt | Chests |
| 2 | Steel set | e.g. Ember Bolt | Chests (steel armor), regular enemies (weapons, chance based) |
| 3 | Warden's set | e.g. Captain's Longsword | Mini bosses (guaranteed) |
| 4 | Choir's set | Boss weapons | Boss 2 |
| 5 | Final boss set | Boss weapons | Final boss |

- The hero carries one sword and one each of bow, crossbow and spell. A find is equipped if it is at least
  as strong as what is in that slot (defense for armor, damage for weapons). An inventory screen for swapping
  by hand comes with the skill tree milestone.
- Enemies have `drop` and `drop_chance` fields, so any enemy can carry any item. Drops float and glow, and
  are picked up by walking into them.
- Items are data files (`game/resources/items/`, `game/resources/weapons/`), each with a tier.

## Mini bosses and checkpoints (built)

- **Brute Captain** (arena mini boss): 240 health, super armor (hits never interrupt it), heavy lunging
  swings, guaranteed drop of the Captain's Longsword. Once beaten it stays dead, even after dying or reloading.
- **Checkpoint shrines**: stone altars with candles. Touching one lights it, makes it the respawn point and
  restores health. On death the screen says so, and after 3 seconds (or pressing R) the hero rises at the
  last lit shrine. Regular enemies come back; opened chests and defeated mini bosses do not.

## Open questions

1. **Realistic characters**: how should we source the hero and enemy models? Options:
   - Mixamo (free with an Adobe account): rigged realistic characters plus hundreds of animations.
   - A purchased asset pack (for example on Fab or the Unity Asset Store, where licenses allow Godot use).
   - Generating models with an AI 3D tool, then rigging them in Blender (uses paid credits, quality varies).
2. **Mini boss count**: two per region (about six total)?
3. **Healing**: healing potions with limited uses, refilled at shrines?
4. **Shops**: keep gold and a merchant, or all gear from chests and drops?

class_name HeroAppearance
extends Resource
## The player's chosen body for their hero: skin tone, hair and proportions.
## Armor is not chosen here; it is found in loot chests (see ArmorItem).

enum Hairstyle { BALD, SHORT, LONG }

const SKIN_TONES: Array[Color] = [
	Color(0.98, 0.84, 0.72),
	Color(0.93, 0.74, 0.58),
	Color(0.82, 0.6, 0.42),
	Color(0.66, 0.46, 0.3),
	Color(0.48, 0.32, 0.2),
	Color(0.32, 0.21, 0.14),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.1, 0.08, 0.07), # Black
	Color(0.35, 0.22, 0.12), # Brown
	Color(0.62, 0.42, 0.2), # Light brown
	Color(0.88, 0.74, 0.45), # Blond
	Color(0.62, 0.24, 0.1), # Auburn
	Color(0.75, 0.75, 0.75), # Grey
]
const HAIRSTYLE_NAMES := ["Bald", "Short", "Long"]
const HEIGHT_RANGE := Vector2(0.9, 1.1)
const BUILD_RANGE := Vector2(0.85, 1.2)

@export var skin_tone := SKIN_TONES[1]
@export var hair_color := HAIR_COLORS[1]
@export var hairstyle := Hairstyle.SHORT
## Vertical scale of the model.
@export_range(0.9, 1.1) var height := 1.0
## Horizontal scale of the model: slim to broad.
@export_range(0.85, 1.2) var build := 1.0


func to_dict() -> Dictionary:
	return {"skin_tone": skin_tone, "hair_color": hair_color, "hairstyle": hairstyle,
			"height": height, "build": build}


static func from_dict(data: Dictionary) -> HeroAppearance:
	var appearance := HeroAppearance.new()
	appearance.skin_tone = data.get("skin_tone", appearance.skin_tone)
	appearance.hair_color = data.get("hair_color", appearance.hair_color)
	appearance.hairstyle = clampi(data.get("hairstyle", appearance.hairstyle), 0, Hairstyle.size() - 1)
	appearance.height = clampf(data.get("height", 1.0), HEIGHT_RANGE.x, HEIGHT_RANGE.y)
	appearance.build = clampf(data.get("build", 1.0), BUILD_RANGE.x, BUILD_RANGE.y)
	return appearance

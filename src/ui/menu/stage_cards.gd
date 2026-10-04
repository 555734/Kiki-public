class_name StageCards
extends RefCounted
## The co-op stages the start menu offers, in menu order.

## The stages the menu offers, in order, with the art each card shows.
##
## The pictures are rendered from the stages themselves by
## `tools/capture_stage_cards.gd` -- through a portrait window, because a card
## is twice as tall as it is wide and a centre crop of a 16:9 screenshot is a
## column of sky. That is what these used to be: 1-1 showed the bare parallax
## backdrop with no ground in it at all.
static func all() -> Array[Dictionary]:
	return [
		{"number": "1-1", "name": "GREENFIELD PLAINS",
			"blurb": "走る・跳ぶ・助け合う最初の一歩",
			"which": Stage.Which.GREENFIELD, "accent": Color("15cf8a"),
			"art": preload("res://assets/menu/card_1_1.png"), "crop_top": 370.0},
		{"number": "1-2", "name": "THE HOLLOW OUTSKIRTS",
			"blurb": "月明かりの村を駆け抜ける",
			"which": Stage.Which.HORROR, "accent": Color("4688ef"),
			"art": preload("res://assets/menu/card_1_2.png"), "crop_top": 310.0},
		{"number": "1-3", "name": "THE SKYWARD RUINS",
			"blurb": "足場をつないで天空の頂へ",
			"which": Stage.Which.SKYWARD_RUINS, "accent": Color("8659e8"),
			"art": preload("res://assets/menu/card_1_3.png"), "crop_top": 430.0},
		{"number": "1-4", "name": "THE SUNLIT COAST",
			"blurb": "岩と桟橋をつないで海の旗へ",
			"which": Stage.Which.SEA, "accent": Color("1fa7d8"),
			"art": preload("res://assets/menu/card_1_4.png"), "crop_top": 400.0},
		{"number": "1-5", "name": "THE POISON MARSH",
			"blurb": "毒沼の足場を渡り岸の門へ",
			"which": Stage.Which.SWAMP, "accent": Color("75b72b"),
			"art": preload("res://assets/menu/card_1_5.png"), "crop_top": 350.0},
		{"number": "1-6", "name": "THE SANDGLASS RUINS",
			"blurb": "奇妙な敵が待つ砂漠の遺跡へ",
			"which": Stage.Which.DESERT, "accent": Color("e6a44b"),
			"art": preload("res://assets/menu/card_1_6.png"), "crop_top": 330.0},
		{"number": "1-7", "name": "THE CLOCKWORK TOWER",
			"blurb": "仕掛けだらけの塔をふたりで登る",
			"which": Stage.Which.TOWER, "accent": Color("8c8a78"),
			"art": preload("res://assets/menu/card_1_7.png"), "crop_top": 320.0},
		{"number": "1-8", "name": "THE UNDERGROVE",
			"blurb": "地下の仕掛けと敵をくぐり抜ける",
			"which": Stage.Which.CAVE, "accent": Color("708797"),
			"art": preload("res://assets/menu/card_1_8.png"), "crop_top": 320.0},
	]

static func for_which(which: int) -> Dictionary:
	for info in all():
		if int(info["which"]) == which:
			return info
	return {}

## The card of the stage that is selected now, or the first.
static func current() -> Dictionary:
	var info := for_which(Stage.current())
	return info if not info.is_empty() else all()[0]

## Which page of `per_page` cards a stage is on.
static func page_of(which: int, per_page: int) -> int:
	var cards := all()
	for i in cards.size():
		if int(cards[i]["which"]) == which:
			return i / per_page
	return 0

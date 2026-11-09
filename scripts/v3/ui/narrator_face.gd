class_name NarratorFace
extends RefCounted
## Story (4 Nov): the narrator's face as a round icon, cut from the 2D
## narrator art (MunshiBust.SPRITE_PATH's idle pose: head centre x 425, hair
## top 58 on its 748 x 517 canvas). Used where the old 2D "munshi" glyph was:
## Rani's chip (ReactChip) and her row in STAFF › WAITERS. Without the art it
## falls back to that glyph.
## 3D Rani (5 Nov): her face rendered from the idle bust (FACE_3D, square,
## transparent) wins over the 2D cut when it exists.

static var SPRITE: String = ThemePack.textures_dir() + "narrator/narrator_idle.png"
## Her face on the idle sprite: a square from the hair top to the chin.
const FACE := Rect2(330, 72, 190, 190)
static var FACE_3D: String = ThemePack.textures_dir() + "narrator/rani_face.png"


## A `sz` px round face on `bg` with a `ring` border.
static func make(sz: float, bg: Color = UiKit.MARIGOLD_PALE, ring: Color = Color.WHITE) -> Control:
	var three_d: bool = ResourceLoader.exists(FACE_3D)
	if not three_d and not ResourceLoader.exists(SPRITE):
		var ic := UiIcon.new("munshi", Vector2(sz, sz), Color.WHITE, bg)
		ic.pad = 0.08
		return ic
	var disc: Panel = UiKit.panel(bg, sz * 0.5, 2, ring)
	disc.name = "NarratorFace"
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2(sz, sz)
	disc.size = Vector2(sz, sz)
	disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var pic := TextureRect.new()
	if three_d:
		pic.texture = load(FACE_3D) as Texture2D
	else:
		var at := AtlasTexture.new()
		at.atlas = load(SPRITE) as Texture2D
		at.region = FACE
		pic.texture = at
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(pic)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return disc

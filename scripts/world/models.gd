class_name Models
extends RefCounted
## Loads .glb models from the running theme pack (ThemePack.models_dir(),
## res://themes/<id>/models/), then from the kit's own models
## (ThemePack.ENGINE_DIR + "models/"). Falls back to a coloured box so the
## game runs before an asset exists, and prints "[pack] missing model '<id>'"
## once per id (the test suite fails on it: a pack must ship every model the
## game asks for).

static var _missing := {}

static var _cache := {}
## Palette material sharing (build optimisation, docs/optimise/report.md):
## every glb comes with its own copy of the same palette atlas
## (<id>_palette.png, one atlas from tools/blender/build_assets.py) and so its
## own material. The first time a model is made, its palette materials are
## swapped, in the shared mesh resources, for ONE material per distinct set of
## material settings and imported atlas data (_tex_storage): the renderer
## switches materials far less often and the duplicate atlases are freed.
## Same imported texture bytes, same settings: same pixels.
static var _shared_mats := {}
static var _shared_done := {}
## Material instance id -> its shared material, for the model being shared
## (a glb's meshes all use the same palette material: one key per model).
static var _seen := {}


## res:// path of model `id` (the pack's first, then the kit's), "" when
## neither has it.
static func path_of(id: String) -> String:
	var p: String = ThemePack.models_dir() + id + ".glb"
	if ResourceLoader.exists(p):
		return p
	p = ThemePack.ENGINE_DIR + "models/" + id + ".glb"
	return p if ResourceLoader.exists(p) else ""


## True when model `id` exists in the pack or the kit.
static func exists(id: String) -> bool:
	return path_of(id) != ""


static func make(id: String, fallback_size := Vector3(0.6, 0.6, 0.6), fallback_color := Color.HOT_PINK) -> Node3D:
	if not _cache.has(id):
		var path := path_of(id)
		_cache[id] = load(path) if path != "" else null
		if path == "" and not _missing.has(id):
			_missing[id] = true
			print("[pack] missing model '%s' (theme %s)" % [id, ThemePack.id()])
	var ps: PackedScene = _cache[id]
	if ps != null:
		var n: Node3D = ps.instantiate()
		n.name = id
		if not _shared_done.has(id):
			_shared_done[id] = true
			_share_palette(n)
			_seen.clear()
		return n
	var root := Node3D.new()
	root.name = id
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = fallback_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fallback_color
	bm.material = mat
	mi.mesh = bm
	mi.position.y = fallback_size.y * 0.5
	root.add_child(mi)
	return root


## Swaps the palette materials of every mesh under `n` (the mesh resources
## are shared by all instances of the model) for the shared ones.
static func _share_palette(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh is ArrayMesh:
			_share_mesh(mi.mesh as ArrayMesh)
			var sm: Mesh = (mi.mesh as ArrayMesh).shadow_mesh
			if sm is ArrayMesh:
				_share_mesh(sm as ArrayMesh)
		if mi.mesh != null:
			for si in mi.mesh.get_surface_count():
				var o: Material = mi.get_surface_override_material(si)
				var s: Material = _shared_for(o)
				if s != null and s != o:
					mi.set_surface_override_material(si, s)
	for c in n.get_children():
		_share_palette(c)


static func _share_mesh(m: ArrayMesh) -> void:
	for si in m.get_surface_count():
		var cur: Material = m.surface_get_material(si)
		var s: Material = _shared_for(cur)
		if s != null and s != cur:
			m.surface_set_material(si, s)


## The shared material for palette material `m` (null when `m` is not one).
static func _shared_for(m: Material) -> Material:
	if m == null:
		return null
	var mid: int = m.get_instance_id()
	if not _seen.has(mid):
		_seen[mid] = _find_shared(m)
	return _seen[mid]


static func _find_shared(m: Material) -> Material:
	if not (m is BaseMaterial3D):
		return null
	var bm := m as BaseMaterial3D
	var tex: Texture2D = bm.albedo_texture
	if tex == null or not tex.resource_path.get_file().ends_with("_palette.png"):
		return null
	var key: Array = _mat_key(bm, _tex_storage(tex))
	if not _shared_mats.has(key):
		_shared_mats[key] = bm
	return _shared_mats[key]


## The atlas's imported bytes (md5 of the .ctex the texture was loaded from):
## the source PNGs are identical, but the editor's detect-3D step switched some
## imports to VRAM compression and some were compressed by an older encoder,
## so only atlases with identical imported data are shared and every model
## keeps its exact pixels. One small file read per atlas, once.
static var _tex_md5 := {}


static func _tex_storage(tex: Texture2D) -> String:
	var lp: String = (tex as CompressedTexture2D).load_path if tex is CompressedTexture2D else ""
	if lp == "":
		return "id%d" % tex.get_instance_id()
	if not _tex_md5.has(lp):
		_tex_md5[lp] = FileAccess.get_md5(lp)
	return str(_tex_md5[lp])


## Stored property names per material class (all but the name / path and
## albedo_texture), read once.
static var _prop_names := {}


## Every stored setting of the material except its name and its albedo
## texture (the palette, given as `tex_key`), as an Array (compared by value;
## resources by identity).
static func _mat_key(m: BaseMaterial3D, tex_key: String) -> Array:
	var cls: String = m.get_class()
	if not _prop_names.has(cls):
		var names := PackedStringArray()
		for p: Dictionary in m.get_property_list():
			if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0:
				continue
			var pn: String = str(p["name"])
			if pn == "albedo_texture" or pn.begins_with("resource_") or pn == "script":
				continue
			names.append(pn)
		_prop_names[cls] = names
	var key: Array = [cls, tex_key]
	for pn: String in (_prop_names[cls] as PackedStringArray):
		key.append(m.get(pn))
	return key


## Makes every mesh under `n` draw on top of the world (UI-like 3D icons).
static func overlay(n: Node, priority := 12) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m is BaseMaterial3D:
					var key := "_overlay_%d" % priority
					if not m.has_meta(key):
						var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
						d.no_depth_test = true
						d.render_priority = priority
						m.set_meta(key, d)
					mi.set_surface_override_material(i, m.get_meta(key))
	for c in n.get_children():
		overlay(c, priority)


## A flat unshaded disc, used for unlock pads and progress rings.
static func disc(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	cm.radial_segments = 24
	cm.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.material = mat
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Thin bar (for patience / cook progress), anchored at its left edge.
static func bar(width: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func tap_area(size: Vector3, target: Object) -> Area3D:
	var a := Area3D.new()
	a.input_ray_pickable = true
	a.monitoring = false
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y * 0.5
	a.add_child(cs)
	a.set_meta("tap_target", target)
	return a

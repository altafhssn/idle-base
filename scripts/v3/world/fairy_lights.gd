class_name FairyLights
extends Node
## Festive fairy lights (user request #12, 2026-10-20). ART bakes the bulbs
## into dhaba_v3.glb / street_v3.glb as MeshInstance3D nodes named
## "fairy_bulb_<string>" (one node per string or string group, every bulb a
## separate small mesh island) with the bulb colour in the vertex colour and
## an animation code in its alpha (tools/blender/v3_exterior.py):
##   a <  0.5: twinkle, phase = 2a (random per bulb)
##   a >= 0.5: chase, step = round(4 * (2a - 1)) = 0..3 along the string
## This driver gives every such node one of two POOLED ShaderMaterials (one
## for twinkling strings, one for chase strings - shared by all nodes, built
## once from the pack's models/fairy_bulb_material.tres). The shader runs the
## animation on the GPU from TIME: brightness 0.6..1.0 at 1.5..3 Hz per bulb,
## chase strings step every 0.18 s, a x1.25 boost so the bulbs read slightly
## brighter than the daylight scene (always on). No lights, no per-bulb nodes,
## no per-frame CPU work; shadows off.
##
## API: attach(root) -> int (strings found), set_brightness(low, high),
## set_boost(boost) (day / night cycle), set_speed(mult), strings.

static var MATERIAL_PATH: String = ThemePack.models_dir() + "fairy_bulb_material.tres"
const PREFIX := "fairy_bulb_"
## Strings that run a chase pattern (the rest twinkle).
const CHASE_KEYS := ["sign_top", "sign_bottom", "gate_board", "parking_board", "gumti"]
const CHASE_STEP := 0.18
const TWINKLE_HZ := Vector2(1.5, 3.0)

static var _mat_twinkle: ShaderMaterial = null
static var _mat_chase: ShaderMaterial = null

## Every bulb string node driven by this node.
var strings: Array[MeshInstance3D] = []
## False by day: the strings are hidden (art audit M4 / S9, 4 Nov).
var _lit: bool = true


## Finds every fairy_bulb_* mesh under `root` and gives it the shared
## material. Safe to call again for a new root (e.g. a rebuilt world).
func attach(root: Node) -> int:
	if root == null:
		return 0
	_ensure_materials()
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if node is MeshInstance3D and str(node.name).begins_with(PREFIX):
			var mi := node as MeshInstance3D
			if strings.has(mi):
				continue
			var key: String = str(mi.name).substr(PREFIX.length())
			mi.material_override = _mat_chase if _is_chase(key) else _mat_twinkle
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			mi.visible = _lit
			strings.append(mi)
			n += 1
	return n


## Twinkle range (shared by every string).
func set_brightness(low: float, high: float) -> void:
	_ensure_materials()
	for m in [_mat_twinkle, _mat_chase]:
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("low", low)
		sm.set_shader_parameter("high", high)


## Overall bulb boost (1.25 = the daylight look; DayNight raises it at night).
func set_boost(boost: float) -> void:
	_ensure_materials()
	for m in [_mat_twinkle, _mat_chase]:
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("boost", boost)


## Shows the bulb strings only from dusk (art audit M4 / S9, 4 Nov): hidden by
## day, which also saves their triangles. DayNight calls it with night > 0.02.
func set_lit(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	for mi in strings:
		if is_instance_valid(mi):
			mi.visible = on


## Animation speed multiplier (1 = spec rates).
func set_speed(mult: float) -> void:
	_ensure_materials()
	var k: float = maxf(0.05, mult)
	for m in [_mat_twinkle, _mat_chase]:
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("hz_min", TWINKLE_HZ.x * k)
		sm.set_shader_parameter("hz_max", TWINKLE_HZ.y * k)
		sm.set_shader_parameter("chase_step", CHASE_STEP / k)


static func _is_chase(key: String) -> bool:
	for v in CHASE_KEYS:
		if key.begins_with(str(v)):
			return true
	return false


static func _ensure_materials() -> void:
	if _mat_twinkle != null:
		return
	var base: ShaderMaterial = null
	if ResourceLoader.exists(MATERIAL_PATH):
		base = load(MATERIAL_PATH) as ShaderMaterial
	if base == null:
		base = ShaderMaterial.new()
		base.shader = _fallback_shader()
	_mat_twinkle = base.duplicate() as ShaderMaterial
	_mat_chase = base.duplicate() as ShaderMaterial
	_mat_chase.set_shader_parameter("chase_step", CHASE_STEP)


## Used only if ART's material is missing: same encoding, same look.
static func _fallback_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
uniform float low = 0.6;
uniform float high = 1.0;
uniform float hz_min = 1.5;
uniform float hz_max = 3.0;
uniform float chase_step = 0.18;
uniform float chase_dim = 0.35;
uniform float boost = 1.25;
varying vec4 v_col;
void vertex() { v_col = COLOR; }
void fragment() {
	float code = v_col.a;
	float b;
	if (code < 0.5) {
		float ph = code * 2.0;
		float hz = mix(hz_min, hz_max, fract(ph * 7.31 + 0.13));
		b = mix(low, high, 0.5 + 0.5 * sin(6.2831853 * (TIME * hz + ph)));
	} else {
		float s = floor((code - 0.5) * 8.0 + 0.5);
		float now = mod(floor(TIME / chase_step), 4.0);
		b = (abs(s - now) < 0.5) ? high : mix(chase_dim, high, 0.35);
	}
	vec3 c = mix(v_col.rgb / 12.92, pow((v_col.rgb + 0.055) / 1.055, vec3(2.4)), step(0.04045, v_col.rgb));
	ALBEDO = c * b * boost;
}
"""
	return sh

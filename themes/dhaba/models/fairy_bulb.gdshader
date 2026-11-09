// Fairy-light bulbs of dhaba_v3.glb / street_v3.glb (nodes named "fairy_bulb_*").
// ART (tools/blender/v3_exterior.py) bakes per vertex:
//   COLOR.rgb = bulb colour (linear)
//   COLOR.a   = animation code: a < 0.5 -> twinkle with phase 2a;
//               a >= 0.5 -> chase, step 4 * (2a - 1) = 0..3 along the string.
// Unshaded, no lights, no per-frame CPU work: one draw call per string node.
// Apply via res://themes/dhaba/models/fairy_bulb_material.tres as material_override on every
// MeshInstance3D whose name starts with "fairy_bulb_".
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform float low : hint_range(0.0, 1.0) = 0.6;      // twinkle minimum brightness
uniform float high : hint_range(0.0, 2.0) = 1.0;     // twinkle maximum brightness
uniform float hz_min = 1.5;                           // twinkle rate range (per bulb)
uniform float hz_max = 3.0;
uniform float chase_step = 0.18;                      // s per chase step
uniform float chase_dim : hint_range(0.0, 1.0) = 0.35;
uniform float boost = 1.25;                           // reads a bit brighter than the lit scene
// Godot imports the glb's COLOR_0 bytes as sRGB values (checked 2026-10-20): convert to
// linear so the bulbs show the colours ART picked (#FFD17F warm white, marigold, ...).
uniform bool vertex_srgb = true;

varying vec4 v_col;

void vertex() {
	v_col = COLOR;
}

void fragment() {
	float code = v_col.a;
	float b;
	if (code < 0.5) {
		float ph = code * 2.0;
		float hz = mix(hz_min, hz_max, fract(ph * 7.31 + 0.13));
		b = mix(low, high, 0.5 + 0.5 * sin(6.2831853 * (TIME * hz + ph)));
	} else {
		float step_i = floor((code - 0.5) * 8.0 + 0.5);          // 0..3
		float now = mod(floor(TIME / chase_step), 4.0);
		b = (abs(step_i - now) < 0.5) ? high : mix(chase_dim, high, 0.35);
	}
	vec3 c = v_col.rgb;
	if (vertex_srgb) {
		c = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
	}
	ALBEDO = c * b * boost;
}

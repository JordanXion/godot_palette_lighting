shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

#include "res://addons/palette_lighting/palette_lighting.gdshaderinc"

uniform sampler2D base_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 base_tint = vec4(1.0);
uniform bool is_vertex_color_enabled = false;
uniform bool is_per_vertex = true;
uniform bool is_alpha_cutout_enabled = false;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform int debug_view : hint_enum("Combined", "Diffuse", "Additive", "Orientation") = 0;
uniform bool is_shadow_receiving_enabled = false;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.7;
uniform vec4 extra_emission : source_color = vec4(0.0);
uniform float extra_emission_energy = 0.0;

varying vec3 sampled_diffuse;
varying vec3 sampled_additive;
varying vec3 world_normal;
varying float sampled_coordinate;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	sampled_coordinate = palette_coordinate(world_normal);
	sampled_diffuse = palette_sample(sampled_coordinate, palette_diffuse_slot, false);
	sampled_additive = palette_sample(sampled_coordinate, palette_additive_slot, true);
}

void fragment() {
	vec4 base = texture(base_texture, UV) * base_tint;
	if (is_vertex_color_enabled) {
		base *= COLOR;
	}
	if (is_alpha_cutout_enabled && base.a < alpha_cutoff) {
		discard;
	}
	float coordinate = is_per_vertex ? sampled_coordinate : palette_coordinate(world_normal);
	vec3 diffuse = sampled_diffuse;
	vec3 additive = sampled_additive;
	if (!is_per_vertex) {
		diffuse = palette_sample(coordinate, palette_diffuse_slot, false);
		additive = palette_sample(coordinate, palette_additive_slot, true);
	}
	vec3 color = palette_compose(base.rgb, diffuse, additive);
	if (debug_view == 1) {
		color = palette_is_encoded ? palette_to_linear(diffuse) : diffuse;
	} else if (debug_view == 2) {
		color = palette_is_encoded ? palette_to_linear(additive) : additive;
	} else if (debug_view == 3) {
		color = palette_to_linear(vec3(1.0 - coordinate));
	}
	ALBEDO = OUTPUT_IS_SRGB ? palette_to_encoded(color) : color;
	SPECULAR = 0.0;
	// emission retains colored fill where a cast shadow blocks the directional light.
	float visibility_floor = (is_shadow_receiving_enabled && debug_view == 0)
		? 1.0 - shadow_strength : 1.0;
	EMISSION = ALBEDO * visibility_floor + extra_emission.rgb * extra_emission_energy;
}

void light() {
	// the palette supplies brightness and hue; the sun only supplies shadow visibility.
	if (is_shadow_receiving_enabled && debug_view == 0 && LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += vec3(ATTENUATION * shadow_strength);
	}
}

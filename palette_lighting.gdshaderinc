// samplers retain encoded RGB so the arithmetic space is an explicit choice.
uniform sampler2D palette_atlas_a : filter_nearest, repeat_disable;
uniform sampler2D palette_atlas_b : filter_nearest, repeat_disable;
uniform vec3 palette_direction = vec3(-0.4, 0.8, 0.4);
uniform float palette_blend : hint_range(0.0, 1.0) = 0.0;
uniform int palette_diffuse_slot : hint_range(0, 7) = 0;
uniform int palette_additive_slot : hint_range(0, 7) = 0;
uniform bool palette_is_encoded = true;
uniform bool palette_is_additive_enabled = true;
uniform float palette_additive_strength : hint_range(0.0, 2.0) = 1.0;

vec3 palette_to_linear(vec3 color) {
	vec3 low = color / 12.92;
	vec3 high = pow((color + vec3(0.055)) / 1.055, vec3(2.4));
	return mix(low, high, step(vec3(0.04045), color));
}

vec3 palette_to_encoded(vec3 color) {
	vec3 low = color * 12.92;
	vec3 high = 1.055 * pow(max(color, vec3(0.0)), vec3(1.0 / 2.4)) - vec3(0.055);
	return mix(low, high, step(vec3(0.0031308), color));
}

float palette_coordinate(vec3 world_normal) {
	float orientation = dot(normalize(world_normal), normalize(palette_direction));
	return clamp((1.0 - orientation) * 0.5, 0.0, 1.0);
}

vec3 palette_sample(float coordinate, int slot, bool is_additive) {
	// texel centers make every entry reachable without sampling adjacent rows.
	float index = floor(clamp(coordinate, 0.0, 1.0) * 255.0);
	float row = float(clamp(slot, 0, 7) * 2) + (is_additive ? 1.0 : 0.0);
	vec2 uv = vec2((index + 0.5) / 256.0, (row + 0.5) / 16.0);
	vec3 a = textureLod(palette_atlas_a, uv, 0.0).rgb;
	vec3 b = textureLod(palette_atlas_b, uv, 0.0).rgb;
	if (!palette_is_encoded) {
		a = palette_to_linear(a);
		b = palette_to_linear(b);
	}
	return mix(a, b, palette_blend);
}

vec3 palette_compose(vec3 base_encoded, vec3 diffuse, vec3 additive) {
	vec3 base = palette_is_encoded ? base_encoded : palette_to_linear(base_encoded);
	vec3 result = base * diffuse;
	if (palette_is_additive_enabled) {
		result += additive * palette_additive_strength;
	}
	// clipping before conversion preserves the bounded color response of the ramps.
	result = clamp(result, vec3(0.0), vec3(1.0));
	return palette_is_encoded ? palette_to_linear(result) : result;
}

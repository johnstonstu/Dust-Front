shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec4 shallow_color : source_color = vec4(0.18, 0.55, 0.58, 0.78);
uniform vec4 deep_color : source_color = vec4(0.05, 0.22, 0.32, 0.88);
uniform vec3 glow_color : source_color = vec3(0.18, 0.78, 0.72);
uniform float glow_energy = 0.55;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float ripple = sin(world.x * 0.35 + TIME * 1.4) * cos(world.z * 0.28 - TIME * 1.1);
	float ripple2 = sin((world.x + world.z) * 0.55 + TIME * 2.2) * 0.5 + 0.5;
	float depth_mix = clamp(0.45 + ripple * 0.18 + ripple2 * 0.12, 0.0, 1.0);
	vec4 water = mix(deep_color, shallow_color, depth_mix);
	// Fake fresnel: brighter / more opaque toward grazing angles.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	ALBEDO = mix(water.rgb, glow_color, fresnel * 0.35 + ripple2 * 0.08);
	ALPHA = clamp(mix(water.a, 0.95, fresnel * 0.5), 0.35, 0.95);
	ROUGHNESS = mix(0.05, 0.22, fresnel);
	METALLIC = 0.15;
	EMISSION = glow_color * (glow_energy * (0.55 + ripple2 * 0.45 + fresnel * 0.35));
}

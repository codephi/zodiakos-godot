shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

varying vec4 stellar_color;
varying vec4 stellar_custom;

void vertex() {
	stellar_color = COLOR;
	stellar_custom = INSTANCE_CUSTOM;
}

void fragment() {
	float distance_from_center = distance(UV, vec2(0.5));
	float core = smoothstep(0.22, 0.0, distance_from_center);
	float halo = smoothstep(0.5, 0.05, distance_from_center) * stellar_custom.w;
	float period_seconds = mix(2.5, 8.0, stellar_custom.y);
	float pulse = 1.0 + sin(TIME * TAU / period_seconds + stellar_custom.x * TAU)
		* stellar_custom.z;
	ALBEDO = stellar_color.rgb * core;
	EMISSION = stellar_color.rgb * (core + halo) * pulse * 1.8;
	ALPHA = clamp(core + halo, 0.0, 1.0);
}

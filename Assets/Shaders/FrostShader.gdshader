// shader from: https://godotshaders.com/shader/frosted-glass-3/ with addaptations
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap; // Captures the screen texture
uniform sampler2D frosted_texture : source_color, repeat_enable; // Your frosted glass texture for distortion
uniform sampler2D edge_noise : repeat_enable; // Noise

uniform int lod_level : hint_range(0, 10) = 4; // Base blur level
uniform float brightness : hint_range(0.0, 100.0) = 1.0; // Brightness adjustment
uniform float distortion_intensity : hint_range(0.0, 0.1) = 0.02; // Strength of distortion
uniform vec3 tint : source_color = vec3(0.9, 0.92, 0.95);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.25;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.0;

// w0, w1, w2, and w3 are the four cubic B-spline basis functions
float w0(float a) {
	return (1.0f / 6.0f) * (a * (a * (-a + 3.0f) - 3.0f) + 1.0f);
}

float w1(float a) {
	return (1.0f / 6.0f) * (a * a * (3.0f * a - 6.0f) + 4.0f);
}

float w2(float a) {
	return (1.0f / 6.0f) * (a * (a * (-3.0f * a + 3.0f) + 3.0f) + 1.0f);
}

float w3(float a) {
	return (1.0f / 6.0f) * (a * a * a);
}

// g0 and g1 are the two amplitude functions
float g0(float a) {
	return w0(a) + w1(a);
}

float g1(float a) {
	return w2(a) + w3(a);
}

// h0 and h1 are the two offset functions
float h0(float a) {
	return -1.0f + w1(a) / (w0(a) + w1(a));
}

float h1(float a) {
	return 1.0f + w3(a) / (w2(a) + w3(a));
}

vec4 texture2D_bicubic(sampler2D tex, vec2 uv, int p_lod, ivec2 tex_size) {
	vec2 tex_size_lod = vec2(tex_size >> p_lod);
	vec2 pixel_size = vec2(1.0f) / tex_size_lod;
	uv = uv * tex_size_lod + vec2(0.5f);
	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);
	float g0x = g0(fuv.x);
	float g1x = g1(fuv.x);
	float h0x = h0(fuv.x);
	float h1x = h1(fuv.x);
	float h0y = h0(fuv.y);
	float h1y = h1(fuv.y);
	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - vec2(0.5f)) * pixel_size;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - vec2(0.5f)) * pixel_size;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - vec2(0.5f)) * pixel_size;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - vec2(0.5f)) * pixel_size;
	return (g0(fuv.y) * (g0x * textureLod(tex, p0, float(p_lod)) + g1x * textureLod(tex, p1, float(p_lod)))) +
		   (g1(fuv.y) * (g0x * textureLod(tex, p2, float(p_lod)) + g1x * textureLod(tex, p3, float(p_lod))));
}

void fragment() {
	float dist = distance(UV, vec2(0.5)) / 0.7071;
	float noise = texture(edge_noise, UV * 1.5).r - 0.5;

	float threshold = 1.0 - fog_amount * 1.1;
	float mask = smoothstep(threshold - 0.15, threshold + 0.15, dist + noise * 0.3);
	mask *= step(0.001, fog_amount);

	vec2 distortion = texture(frosted_texture, UV).rg - 0.5;
	distortion = normalize(distortion) * distortion_intensity * mask;

	vec4 blurred = texture2D_bicubic(screen_texture, SCREEN_UV + distortion, lod_level, textureSize(screen_texture, 0));

	ALBEDO = mix(blurred.rgb, tint, tint_strength);
	ALPHA = mask;
}
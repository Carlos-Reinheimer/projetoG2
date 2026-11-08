shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float speed = 0.6;
uniform float flame_roughness = 0.4;
uniform vec4 color_core : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform vec4 color_mid  : source_color = vec4(1.0, 0.4, 0.05, 1.0);
uniform vec4 color_edge : source_color = vec4(0.5, 0.05, 0.0, 1.0);

void fragment() {
	float h = 1.0 - UV.y; // 0 at the bottom, 1 at the top

	// Two layers of noise scrolling upward at different speeds = flickering flames
	float n1 = texture(noise_tex, vec2(UV.x * 2.0, UV.y * 1.5 + TIME * speed)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 4.0 + 0.3, UV.y * 3.0 + TIME * speed * 1.7)).r;
	float noise = n1 * 0.65 + n2 * 0.35;

	// Height of the fire front, plus noise to make jagged flame tongues
	float front = progress * 1.6 - 0.2;
	float fire = front - h + (noise - 0.5) * flame_roughness;

	float alpha = smoothstep(0.0, 0.05, fire);

	// Darker red at the edges, bright yellow deep inside
	float t = clamp(fire * 3.0, 0.0, 1.0);
	vec3 col = mix(color_edge.rgb, color_mid.rgb, smoothstep(0.0, 0.4, t));
	col = mix(col, color_core.rgb, smoothstep(0.5, 1.0, t));

	COLOR = vec4(col, alpha);
}
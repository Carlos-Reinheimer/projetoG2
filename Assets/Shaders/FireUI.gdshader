shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float speed = 0.6;
uniform float flame_roughness = 0.4;

// Animation
uniform float pulse_amount = 0.04;  // how much the fire height breathes
uniform float pulse_speed = 1.5;
uniform float sway = 0.03;          // side-to-side wobble of the flame tips

// Edge fading
uniform float fade_sides  : hint_range(0.0, 0.5) = 0.15; // left & right
uniform float fade_top    : hint_range(0.0, 0.5) = 0.2;
uniform float fade_bottom : hint_range(0.0, 0.5) = 0.0;  // raise if the bottom isn't at the screen edge
uniform float side_taper  : hint_range(0.0, 1.0) = 0.4;  // flames get shorter toward the sides

// Colors
uniform vec4 color_core : source_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform vec4 color_mid  : source_color = vec4(1.0, 0.4, 0.05, 1.0);
uniform vec4 color_edge : source_color = vec4(0.5, 0.05, 0.0, 1.0);

void fragment() {
	float h = 1.0 - UV.y; // 0 at the bottom, 1 at the top

	// Sway: stronger toward the top, base stays anchored
	vec2 uv = UV;
	uv.x += sin(UV.y * 6.0 + TIME * 2.0) * sway * h;

	// Two layers of noise scrolling upward at different speeds = flickering flames
	float n1 = texture(noise_tex, vec2(uv.x * 2.0, uv.y * 1.5 + TIME * speed)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 4.0 + 0.3, uv.y * 3.0 + TIME * speed * 1.7)).r;
	float noise = n1 * 0.65 + n2 * 0.35;

	// Edge masks (max() avoids smoothstep(0, 0, x) when a fade is set to 0)
	float side = smoothstep(0.0, max(fade_sides, 0.0001), UV.x)
	           * smoothstep(0.0, max(fade_sides, 0.0001), 1.0 - UV.x);
	float top    = smoothstep(0.0, max(fade_top, 0.0001), UV.y);
	float bottom = smoothstep(0.0, max(fade_bottom, 0.0001), 1.0 - UV.y);

	// Fire front height, with a slow irregular "breathing" pulse
	float front = progress * 1.6 - 0.2;
	front += (sin(TIME * pulse_speed) + 0.5 * sin(TIME * pulse_speed * 2.3)) * pulse_amount;
	front -= (1.0 - side) * side_taper; // lower the flames near the sides

	float fire = front - h + (noise - 0.5) * flame_roughness;
	float alpha = smoothstep(0.0, 0.05, fire);

	// Darker red at the edges, bright yellow deep inside
	float t = clamp(fire * 3.0, 0.0, 1.0);
	vec3 col = mix(color_edge.rgb, color_mid.rgb, smoothstep(0.0, 0.4, t));
	col = mix(col, color_core.rgb, smoothstep(0.5, 1.0, t));

	COLOR = vec4(col, alpha * side * top * bottom);
}
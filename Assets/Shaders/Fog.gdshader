shader_type fog;

uniform float smoke_level = 3.0;          // world-space height where smoke starts
uniform float layer_softness = 0.6;       // how blurry the bottom of the smoke layer is
uniform float density : hint_range(0.0, 2.0) = 0.6;
uniform vec4 smoke_color : source_color = vec4(0.15, 0.14, 0.13, 1.0);
uniform sampler3D noise_tex;              // NoiseTexture3D + FastNoiseLite
uniform float drift_speed = 0.05;

void fog() {
	// Thick above smoke_level, fading out below it
	float layer = smoothstep(smoke_level - layer_softness, smoke_level + layer_softness, WORLD_POSITION.y);

	// Slowly drifting noise so it looks like rolling smoke, not a flat slab
	vec3 p = WORLD_POSITION * 0.25 + vec3(TIME * drift_speed, TIME * drift_speed * 0.3, 0.0);
	float n = texture(noise_tex, p).r;

	DENSITY = density * layer * n;
	ALBEDO = smoke_color.rgb;
}
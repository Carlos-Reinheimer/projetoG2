shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float thickness = 0.03;

void vertex() {
	vec3 world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_pos += world_normal * thickness;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
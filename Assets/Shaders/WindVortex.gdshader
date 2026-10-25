shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.8, 1, 1.0, 1.0);
uniform float speed = 2.0;
uniform float stripe_count = 10.0;
uniform float stripe_sharpness = 8.0;
uniform float intensity = 1;

uniform float cone_height = 4.0;      // match the CylinderMesh height
uniform float end_fade = 0.5;        // 0–0.5: how much of each end fades out
uniform float edge_softness = 1.0;    // higher = more silhouette smearing

varying float height_t;

void vertex() {
    // 0 at one end of the cylinder, 1 at the other
    height_t = VERTEX.y / cone_height + 0.5;
}

void fragment() {
    vec2 uv = UV;
    uv.x += uv.y * 0.5;
    uv.y += TIME * speed;
    float s = sin((uv.x + uv.y * 0.3) * stripe_count * TAU) * 0.5 + 0.5;
    s = pow(s, stripe_sharpness);

    // Soft fade at both open ends
    float ends = smoothstep(0.0, end_fade, height_t)
               * smoothstep(1.0, 1.0 - end_fade, height_t);

    // Fresnel: fade where the surface is seen edge-on
    float facing = abs(dot(normalize(NORMAL), VIEW));
    float edges = pow(facing, edge_softness);

    ALBEDO = tint.rgb;
    ALPHA = s * ends * edges * intensity;
}
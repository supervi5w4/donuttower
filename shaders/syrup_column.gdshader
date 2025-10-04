shader_type canvas_item;

uniform vec4 base_col : source_color = vec4(0.85, 0.60, 0.20, 0.90);
uniform float edge_softness = 0.18;
uniform float drip_speed = 0.65;
uniform float wobble_amp = 0.06;
uniform sampler2D noise_tex;

void fragment() {
    vec2 uv = UV;
    float t = TIME * drip_speed;
    float n = texture(noise_tex, vec2(uv.x * 2.0, uv.y * 0.7 + t)).r;
    float wave = (sin(uv.y * 18.0 + n * 6.283) * wobble_amp);

    float left  = smoothstep(0.0, edge_softness, uv.x + wave);
    float right = smoothstep(0.0, edge_softness, 1.0 - uv.x - wave);
    float side_mask = clamp(left * right, 0.0, 1.0);

    float top_fade = smoothstep(0.05, 0.0, uv.y);
    float alpha = base_col.a * side_mask * (1.0 - top_fade * 0.5);

    float shine = exp(-pow((uv.x - 0.35 - wave * 0.5), 2.0) / 0.01);
    float shine_anim = 0.35 + 0.25 * sin(TIME * 1.2);
    vec3 col = base_col.rgb + vec3(shine * shine_anim);
    COLOR = vec4(col, alpha);
}

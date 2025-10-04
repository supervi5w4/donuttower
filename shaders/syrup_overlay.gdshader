shader_type canvas_item;

uniform vec4 syrup_col = vec4(0.90, 0.70, 0.30, 0.85);
uniform float pulse_speed = 3.0;
uniform float drip_phase  = 0.5;

float sd_circle(vec2 p, float r) { return length(p) - r; }

void fragment() {
    vec2 p = (UV * 2.0 - 1.0);
    float d0 = sd_circle(p, 0.55);
    float t = TIME * 0.6 + drip_phase;
    float d1 = sd_circle(p - vec2( 0.20,  0.10 + 0.05*sin(t*2.1)), 0.20);
    float d2 = sd_circle(p - vec2(-0.22,  0.00 + 0.04*sin(t*1.7)), 0.16);
    float d3 = sd_circle(p - vec2( 0.05, -0.15 + 0.03*sin(t*2.7)), 0.12);
    float d = min(min(d0, d1), min(d2, d3));
    float a = smoothstep(0.02, -0.10, d);
    a *= 0.96 + 0.04 * sin(TIME * pulse_speed);
    float spec = exp(-dot(p - vec2(-0.2, -0.15), p - vec2(-0.2, -0.15)) * 12.0) * 0.4;
    vec3 col = syrup_col.rgb + vec3(spec);
    COLOR = vec4(col, syrup_col.a * a);
}

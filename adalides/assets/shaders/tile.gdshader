shader_type spatial;
render_mode cull_back;
// Casilla del campo: borde luminoso del color del bando, vetas de energía que
// fluyen, y resalte (pulsante) cuando se puede colocar o se pasa el ratón.

uniform vec4 base_color : source_color = vec4(0.2, 0.3, 0.5, 1.0);
uniform vec4 edge_color : source_color = vec4(0.35, 0.6, 1.0, 1.0);
uniform float highlight : hint_range(0.0, 1.0) = 0.0;
uniform float hover : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 d = min(uv, 1.0 - uv);
	float border = min(d.x, d.y);
	float edge = 1.0 - smoothstep(0.0, 0.07, border);
	float inner = 1.0 - smoothstep(0.07, 0.2, border);
	float t = TIME * 0.2 + seed;
	float n = noise(uv * 3.0 + vec2(t, -t * 0.7)) * 0.6 + noise(uv * 7.0 - vec2(t * 0.5, t)) * 0.4;
	float veins = smoothstep(0.55, 0.75, n);
	float sweep = 1.0 - smoothstep(0.0, 0.08, abs(fract(uv.x * 0.5 + uv.y * 0.5 - TIME * 0.06 + seed) - 0.5) * 2.0 - 0.9);
	vec3 col = base_color.rgb * (0.8 + 0.35 * n);
	col += edge_color.rgb * (edge * 0.9 + inner * 0.18 + veins * 0.12);
	float pulse = 0.5 + 0.5 * sin(TIME * 4.0 + seed);
	vec3 hl = mix(vec3(0.3, 1.0, 0.5), vec3(1.0, 0.85, 0.3), hover);
	float k = clamp(highlight * 0.38 + hover * 0.8, 0.0, 1.0) * (0.7 + 0.3 * pulse);
	col = mix(col, hl, k);
	ALBEDO = col;
	EMISSION = edge_color.rgb * (edge * 0.7 + veins * 0.25 + sweep * 0.35) + hl * k * 0.9;
	ROUGHNESS = 0.55;
	METALLIC = 0.15;
}

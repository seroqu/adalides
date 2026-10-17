shader_type spatial;
// Mesa de piedra oscura con vetas doradas tenues y un halo bajo el campo.

uniform vec4 stone : source_color = vec4(0.13, 0.1, 0.1, 1.0);
uniform vec4 vein : source_color = vec4(0.55, 0.42, 0.18, 1.0);
uniform float glow_radius = 6.0;

varying vec3 wp;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float grain = fbm(p * 1.3);
	float v = fbm(p * 0.35 + vec2(3.1, 7.7));
	float veins = smoothstep(0.48, 0.52, abs(v - 0.5) * 2.0) * (1.0 - smoothstep(0.52, 0.6, abs(v - 0.5) * 2.0));
	vec3 col = stone.rgb * (0.7 + 0.5 * grain);
	col = mix(col, vein.rgb, veins * 0.45);
	float dist = length(p - vec2(-2.2, 2.75));
	float halo = 1.0 - smoothstep(glow_radius * 0.6, glow_radius, dist);
	col += vec3(0.25, 0.18, 0.08) * halo * (0.5 + 0.5 * grain);
	ALBEDO = col;
	EMISSION = vein.rgb * veins * 0.12 + vec3(0.2, 0.14, 0.05) * halo * 0.25;
	ROUGHNESS = 0.9;
}

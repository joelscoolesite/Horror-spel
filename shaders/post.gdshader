// Nabewerking over het hele scherm: minder kleuren + dithering (PS1-look),
// filmkorrel, vignet, en effecten voor als het hoofd van het kind "raar doet".
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_levels = 32.0;   // kleuren per kanaal (PS1 = 32)
uniform float dither = 1.0;
uniform float grain = 0.035;
uniform float vignette = 0.55;
uniform float distortion = 0.0;      // 0..1  golvend beeld
uniform float static_amount = 0.0;   // 0..1  TV-ruis over het beeld
uniform float desaturate = 0.0;      // 0..1  kleur wegtrekken
uniform float darkness = 0.0;        // 0..1  extra donker (deken over je hoofd)
uniform float chroma = 0.0;          // kleurranden (rood/blauw uit elkaar)
uniform float proximity = 0.0;       // 0..1  het monster is dichtbij

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (distortion > 0.0) {
		uv.x += sin(uv.y * 30.0 + TIME * 2.3) * 0.006 * distortion;
		uv.y += sin(uv.x * 20.0 + TIME * 1.7) * 0.004 * distortion;
		// af en toe een horizontale 'hapering'
		float band = step(0.985, hash(vec2(floor(uv.y * 40.0), floor(TIME * 12.0))));
		uv.x += band * 0.03 * distortion;
	}
	// het monster is dichtbij: beeld trilt en scheurt
	if (proximity > 0.0) {
		float tear = step(1.0 - proximity * 0.08, hash(vec2(floor(uv.y * 90.0), floor(TIME * 20.0))));
		uv.x += tear * (hash(vec2(TIME, uv.y)) - 0.5) * 0.06 * proximity;
	}
	float ca = chroma + proximity * 0.006;
	vec3 c = vec3(
		texture(screen_tex, uv + vec2(ca, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(ca, 0.0)).b);

	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desaturate);

	float n = hash(FRAGCOORD.xy + fract(TIME) * 100.0);
	c += (n - 0.5) * grain;
	c = mix(c, vec3(n), static_amount * 0.8 + proximity * proximity * 0.12);

	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * vignette * 2.0;
	c *= 1.0 - darkness;

	ivec2 px = ivec2(FRAGCOORD.xy) % 4;
	float b = (BAYER[px.y * 4 + px.x] / 16.0 - 0.5) * dither;
	c = floor(c * color_levels + b + 0.5) / color_levels;

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}

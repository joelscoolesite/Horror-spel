// Spiegel: laat het beeld van de spiegel-camera zien (links/rechts omgedraaid),
// een beetje vies en blauwig, zoals een oude badkamerspiegel.
shader_type spatial;
render_mode unshaded;

uniform sampler2D reflection : filter_nearest;
uniform float grime = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec3 c = texture(reflection, uv).rgb;
	c *= vec3(0.85, 0.92, 0.95);
	float spots = hash(floor(UV * vec2(40.0, 48.0)));
	c *= 1.0 - grime * step(0.92, spots) * 0.5;
	// donkere randjes
	vec2 e = min(UV, 1.0 - UV);
	c *= smoothstep(0.0, 0.06, min(e.x, e.y)) * 0.3 + 0.7;
	ALBEDO = c;
}

// Raam: je ziet niet echt naar buiten, alleen licht (dag) of donker met een
// straatlantaarn (nacht). Met een kozijn-kruis erdoor.
shader_type spatial;
render_mode unshaded;

uniform vec4 sky_top : source_color = vec4(0.02, 0.03, 0.08, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.06, 0.07, 0.12, 1.0);
uniform vec4 glow_color : source_color = vec4(0.9, 0.6, 0.25, 1.0);
uniform float glow = 0.0;
uniform vec2 glow_pos = vec2(0.75, 0.7);

void fragment() {
	vec2 uv = floor(UV * vec2(32.0, 24.0)) / vec2(32.0, 24.0);
	vec3 c = mix(sky_top.rgb, sky_bottom.rgb, uv.y);
	float d = distance(uv * vec2(1.3, 1.0), glow_pos * vec2(1.3, 1.0));
	c += glow_color.rgb * glow * smoothstep(0.35, 0.0, d);
	// kozijn
	if (abs(UV.x - 0.5) < 0.025 || abs(UV.y - 0.45) < 0.03) c = vec3(0.05);
	ALBEDO = c;
}

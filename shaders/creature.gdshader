// Huid van het monster. Zelfde PS1-look als de rest, plus:
// - de huid "trilt" een beetje (alsof er iets onder beweegt)
// - een vage lichtrand, zodat je het silhouet in het donker nog net ziet
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

global uniform float ps1_snap;
global uniform float ps1_affine;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(0.16, 0.15, 0.16, 1.0);
uniform float uv_scale = 6.0;
uniform float wobble = 0.006; // hoeveel de huid trilt (meters)
uniform vec3 rim_color : source_color = vec3(0.35, 0.4, 0.55);
uniform float rim_strength = 0.3;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

varying vec3 affine_uv;

void vertex() {
	vec3 v = VERTEX;
	float n = sin(TIME * 23.0 + v.y * 40.0 + v.x * 31.0) * sin(TIME * 17.0 + v.z * 29.0);
	v += NORMAL * n * wobble;

	vec3 an = abs(NORMAL);
	vec2 uv;
	if (an.y >= an.x && an.y >= an.z) {
		uv = VERTEX.xz;
	} else if (an.x >= an.z) {
		uv = vec2(VERTEX.z, -VERTEX.y);
	} else {
		uv = vec2(VERTEX.x, -VERTEX.y);
	}
	UV = uv * uv_scale;

	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(v, 1.0));
	vec2 grid = vec2(ps1_snap, ps1_snap * 0.5625);
	if (clip.w > 0.0) {
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, ps1_affine);
	ALBEDO = texture(albedo_tex, uv).rgb * tint.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * rim * rim_strength + emission_color * emission_energy;
}

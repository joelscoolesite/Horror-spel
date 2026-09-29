// PS1-shader voor alle 3D-objecten.
// - Vertex snapping: hoekpunten "springen" naar een grof raster -> wiebelig beeld.
// - Affine texture mapping: textures vervormen een beetje, zoals op de PS1.
// - Box-projectie: textures worden automatisch op elk blok geplakt, zodat
//   we geen UV's hoeven te maken. `uv_scale` = aantal herhalingen per meter.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Globaal instelbaar in Project Settings > Shader Globals.
global uniform float ps1_snap;   // lager = wiebeliger (bijv. 120)
global uniform float ps1_affine; // 0 = normaal, 1 = volledige PS1-vervorming

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float uv_scale = 1.0;
uniform vec2 uv_offset = vec2(0.0);
// true = texture volgt de wereld (muren sluiten mooi aan)
// false = texture volgt het object (voor dingen die bewegen, zoals deuren)
uniform bool world_uv = false;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
// > 0 = iets naar de camera toe duwen (in meters), zodat platte dingen op een
// muur of vloer (poster, tapijt) niet gaan flikkeren (z-fighting).
uniform float depth_bias = 0.0;

varying vec3 affine_uv;

void vertex() {
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	if (world_uv) {
		p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		n = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	}
	vec3 an = abs(n);
	vec2 uv;
	if (an.y >= an.x && an.y >= an.z) {
		uv = p.xz;
	} else if (an.x >= an.z) {
		uv = vec2(p.z, -p.y);
	} else {
		uv = vec2(p.x, -p.y);
	}
	UV = uv * uv_scale + uv_offset;

	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz -= normalize(view.xyz) * depth_bias;
	vec4 clip = PROJECTION_MATRIX * view;
	vec2 grid = vec2(ps1_snap, ps1_snap * 0.5625);
	if (clip.w > 0.0) {
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, ps1_affine);
	vec4 c = texture(albedo_tex, uv) * tint;
	ALBEDO = c.rgb;
	EMISSION = emission_color * emission_energy;
}

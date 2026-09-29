// Beeldscherm van de TV (en de laptop). Straalt zelf licht uit.
// mode 0 = uit, 1 = spelletje, 2 = ruis, 3 = webpagina/tekst
shader_type spatial;
render_mode unshaded;

uniform int mode = 0;
uniform vec4 page_color : source_color = vec4(0.85, 0.87, 0.9, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * vec2(48.0, 36.0));
	vec3 c = vec3(0.02, 0.025, 0.03);
	if (mode == 1) {
		// simpel platformspelletje: lucht, grond, een springend poppetje
		c = vec3(0.1, 0.12, 0.35);
		if (px.y > 27.0) c = vec3(0.15, 0.45, 0.12);
		float t = TIME * 1.3;
		vec2 hero = vec2(mod(t * 10.0, 56.0) - 4.0, 23.0 - abs(sin(t * 3.0)) * 8.0);
		if (px.x >= hero.x && px.x < hero.x + 3.0 && px.y >= hero.y && px.y < hero.y + 5.0) c = vec3(0.95, 0.8, 0.3);
		// deuren op de achtergrond... het poppetje loopt er langs
		for (float i = 0.0; i < 4.0; i += 1.0) {
			float dx = i * 12.0 + 4.0;
			if (px.x >= dx && px.x < dx + 5.0 && px.y >= 16.0 && px.y < 28.0) c = vec3(0.35, 0.2, 0.12);
		}
		c *= 0.9 + 0.1 * sin(UV.y * 400.0);
	} else if (mode == 2) {
		float n = hash(px * 1.7 + floor(TIME * 30.0));
		c = vec3(n) * (0.75 + 0.25 * sin(UV.y * 300.0 + TIME * 40.0));
	} else if (mode == 3) {
		c = page_color.rgb;
		if (px.y < 5.0) c = vec3(0.95, 0.55, 0.1);
		if (px.y > 8.0 && mod(px.y, 5.0) < 1.5 && px.x > 3.0 && px.x < 30.0 + hash(vec2(px.y)) * 14.0) c = vec3(0.3);
	}
	ALBEDO = c;
}

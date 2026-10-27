shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool enabled = true;

void fragment() {
	// One shared logical grid: 240 x 400 pixels across the 480 x 800 canvas.
	// Every 32 px terrain tile therefore occupies exactly 16 x 16 game pixels.
	vec2 grid = vec2(240.0, 400.0);
	vec2 sample_uv = (floor(SCREEN_UV * grid) + vec2(0.5)) / grid;
	// UI is drawn at its own text resolution; all world shapes share this grid.
	vec2 uv = (enabled && SCREEN_UV.y >= 0.12) ? sample_uv : SCREEN_UV;
	ivec2 size = textureSize(screen_texture, 0);
	ivec2 pixel = clamp(ivec2(floor(uv * vec2(size))), ivec2(0), size - ivec2(1));
	COLOR = texelFetch(screen_texture, pixel, 0);
	COLOR.a = 1.0;
}

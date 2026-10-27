shader_type canvas_item;
render_mode unshaded;
varying vec2 object_pixel;
varying vec4 shape_color;
uniform float dither_pixel_size = 2.0;

void vertex() {
	// Keep geometry intact: snapping outline vertices can collapse thin borders.
	// Native low-resolution viewports rasterize rotated sprites before enlargement.
	object_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// Fragment COLOR already includes Godot's texture sample. Save the original
	// drawing color so a filtered sample cannot introduce intermediate RGB values.
	shape_color = COLOR;
}

void fragment() {
	// Each draw object owns its pixel pattern. Preserve RGB; coverage is binary.
	ivec2 p = ivec2(mod(floor(object_pixel / dither_pixel_size), vec2(8.0)));
	int bayer[64] = int[64](0,32,8,40,2,34,10,42,48,16,56,24,50,18,58,26,12,44,4,36,14,46,6,38,60,28,52,20,62,30,54,22,3,35,11,43,1,33,9,41,51,19,59,27,49,17,57,25,15,47,7,39,13,45,5,37,63,31,55,23,61,29,53,21);
	float threshold = (float(bayer[p.y * 8 + p.x]) + 0.5) / 64.0;
	ivec2 size = textureSize(TEXTURE, 0);
	ivec2 pixel = clamp(ivec2(floor(UV * vec2(size))), ivec2(0), size - ivec2(1));
	vec4 source = texelFetch(TEXTURE, pixel, 0);
	float coverage = shape_color.a * source.a;
	if (coverage < threshold) {
		discard;
	}
	COLOR = vec4(shape_color.rgb * source.rgb, 1.0);
}

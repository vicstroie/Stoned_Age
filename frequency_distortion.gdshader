shader_type canvas_item;

uniform float speed: hint_range(-50.0, 50.0, 0.01) = 0.0;
uniform float frequency: hint_range(0.1, 20.0, 0.1) = 10.0;
uniform float contrast: hint_range(0.0, 1.0, 0.01) = 0.8;

float get_shade(vec4 pixel) {
	return (pixel.r + pixel.b + pixel.g) / 3.0;
}

void fragment() {
	vec2 uv = UV;
	vec2 resolution = 1.0 / TEXTURE_PIXEL_SIZE;
	float time = TIME * speed;
	float result = 0.0;
	for (float x = 0.0; x <= FRAGCOORD.x; x++) {
		vec2 coords = vec2(x / resolution.x, uv.y);
		vec4 pixel = texture(TEXTURE, coords);
		result += get_shade(pixel);
	}
	result = sin(result * frequency + time);
	
	//IN GRAYSCALE
	//result *= (1.0 - contrast) + contrast * get_shade(texture(TEXTURE, uv));
	//COLOR = vec4(vec3(result), 1.0); //Turns image to grayscale
	
	//IN COLOR
	vec3 color = result * (1.0 - contrast) + contrast * texture(TEXTURE, uv).rgb;
	COLOR = vec4(color, 1.0); 
}
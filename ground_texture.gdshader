shader_type spatial;

uniform sampler2D dirt_albedo : source_color;
uniform sampler2D dirt_normal;
uniform sampler2D dirt_roughness;
uniform sampler2D grass_albedo : source_color;
uniform sampler2D grass_normal;
uniform sampler2D grass_roughness;
uniform float uv_scale = 1.0;


void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 dirt_a = texture(dirt_albedo, UV).rgb;
	//vec3 dirt_n = texture(dirt_normal, UV).rgb;
	//float dirt_r = texture(dirt_roughness, UV).r;
	vec3 grass_a = texture(grass_albedo, UV).rgb;
	//vec3 grass_n = texture(grass_normal, UV).rgb;
	//float grass_r = texture(grass_roughness, UV).r;
	
	float dirt_mask = COLOR.r;
	
	ALBEDO = mix(grass_a, dirt_a, dirt_mask);
	//NORMAL_MAP = mix(grass_n, dirt_n, dirt_mask);
	//ROUGHNESS = mix(grass_r, dirt_r, dirt_mask);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

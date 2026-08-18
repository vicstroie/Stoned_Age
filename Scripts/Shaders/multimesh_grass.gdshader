shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_schlick_ggx;
// Nice Shader by @_Malido ^^
// credit and ref: https://godotshaders.com/shader/stylized-multimesh-grass-shader/
const int TOTAL_GRASS_VARIANTS = 4;
uniform sampler2D variants[TOTAL_GRASS_VARIANTS];
uniform bool billboard_y = false;

// 'instance' keyword is only for Vulkan rendering drivers and allows multiple grass variants with the same material
instance uniform int variant_index;
uniform vec3 top_color: source_color;
uniform vec3 bottom_color: source_color;
uniform float ambient_occlusion_factor: hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float specular_strength: hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float player_displacement_strength: hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float player_displacement_size: hint_range(0.0, 2.0, 0.01) = 1.0;

uniform vec3 wind_direction; // Use a negative y component to give it an extra touch (For displacement effect and noise scroll direction)
uniform float wind_strength: hint_range(0.0, 1.0, 0.01) = 0.3;
uniform sampler2D wind_noise; // Periln FBM Noise looks Best
uniform float wind_noise_size: hint_range(0.0, 1.0, 0.001) = 0.05; // high values dont work well
uniform float wind_noise_speed: hint_range(0.0, 1.0, 0.001) = 0.1;

// Instance the Player Position through a GDScript in the _physics_process
instance uniform vec3 player_position;

void vertex() {
	if(billboard_y){
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	}

	
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	vec3 wind_texture = texture(wind_noise, world_position.xz * wind_noise_size + normalize(-wind_direction.xz) * (TIME + UV.y / 2.5) * wind_noise_speed).rgb;
	vec3 wind_vector = (vec4(wind_texture * normalize(wind_direction) * wind_strength, 0.0) * MODEL_MATRIX).xyz;
	
	float player_height = smoothstep(1.0, 0.0, length(player_position.y - world_position.y + 0.3));
	vec3 push_direction = vec3(world_position - player_position) * vec3(1 , -0.3 ,1);
	float player_position_factor = smoothstep(player_displacement_size, 0.0, length(push_direction));
	
	vec3 player_push_vector = (vec4(normalize(push_direction), 0.0) * MODEL_MATRIX).xyz;
	
	// Apply Player Position displacement
	VERTEX += player_push_vector * (1.0 - UV.y) * player_position_factor * player_displacement_strength * player_height;
	// Apply Wind displacement linearly
	VERTEX += wind_vector * (1.0 - UV.y) * (1.0 - player_position_factor * 0.7);
	
	// A new normal correction, which aligns the normals of the mesh facing upwards no matter the original direction.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 color = mix(bottom_color, top_color, 1.0 - UV.y);
	
	// Add fake ambient occlusion by darkening the base of the mesh
	float ao_fallof = pow(UV.y, 5.0);
	vec3 ao_color = bottom_color * (1.0 - ambient_occlusion_factor);
	


	// Apply vertex color to albedo
	ALBEDO = COLOR.rgb;
	
	vec4 detail_mask = texture(variants[variant_index], UV);

	// Details will look awfull if you try to vertex-color it, so is better to process it here
	ALBEDO = mix(color, ALBEDO, detail_mask.r);
	
	
	// Enables alpha scissor
	ALPHA = detail_mask.a;
	ALPHA_SCISSOR_THRESHOLD = 0.8;



	ROUGHNESS = 0.4;
	
	// Increase the Specular with Grass Height
	SPECULAR *= (1.0 - UV.y) * specular_strength;
	
	// Just removing some funny shading
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
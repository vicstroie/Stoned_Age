// POLYBLOCKS | NATUREBLOCKS | TREE LEAVES SHADER
// BUKKBEEK.GITHUB.IO

shader_type spatial;
render_mode world_vertex_coords, depth_draw_opaque, shadows_disabled;

uniform vec3 albedoColor : source_color = vec3(0.3, 0.4, 0.2);
uniform sampler2D alphaTexture : repeat_disable, source_color;
uniform float shadowIntensity : hint_range(-2.0, 2.0) = 1.0;
uniform sampler2D windNoise;
uniform float windSpeed : hint_range(0.1, 2.0) = 1.2;
uniform float windStrength : hint_range(0.0, 2.0) = 0.25;
uniform vec3 ambientColor : source_color = vec3(0.6, 0.2, 0.2);
uniform float ambientStrength : hint_range(0.0, 2.0) = 0.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {

vec2 wind_uv_x = vec2( VERTEX.x + TIME * windSpeed * 0.1, 0.5);

vec2 wind_uv_z = vec2( VERTEX.z + TIME * windSpeed * 0.1, 0.5);

float wind_x = texture(windNoise, wind_uv_x).r - 0.5;
float wind_z = texture(windNoise, wind_uv_z).b - 0.5;

VERTEX.x += wind_x * windStrength * (1.0 - UV.y);
VERTEX.z += wind_z * windStrength * (1.0 - UV.x);
world_position = VERTEX;
world_normal = NORMAL;

}

void fragment() {
	vec4 alphaData = texture(alphaTexture, UV);
	vec3 light_dir = normalize(vec3(0.5, 1.0, 0.3));

	// Always shade using world-up instead of the vertex normal
	vec3 normal = vec3(1.0, 1.0, 1.0);

	float NdotL = dot(normal, light_dir);
	float lambert = max(NdotL, 0.0);
	float shadowBias = mix(0.3, 0.0, shadowIntensity);
	vec3 diffuse = vec3(1.0, 0.95, 0.8) * (lambert + shadowBias);
	vec3 ambient = ambientColor * ambientStrength;
	vec3 lighting = diffuse + ambient;
	lighting = clamp(lighting, 0.0, 2.0);
	vec3 litColor = albedoColor * lighting;
	ALBEDO = litColor;
	ALPHA = alphaData.r;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
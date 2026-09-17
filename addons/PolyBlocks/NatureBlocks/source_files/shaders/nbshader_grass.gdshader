// POLYBLOCKS | NATUREBLOCKS | GRASS SHADER
// BUKKBEEK.GITHUB.IO

shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_prepass_alpha;

uniform sampler2D albedoGradient : repeat_disable, source_color;
uniform sampler2D alphaMask : repeat_disable;
uniform float windSpeed : hint_range(0.5, 5.0) = 2.0;
uniform float windStrength : hint_range(0.0, 1.0) = 0.2;
uniform sampler2D hue_noise : repeat_enable;
uniform float hueNoiseScale : hint_range(0.01, 2.0) = 1.0;
uniform float hueStrength : hint_range(0.0, 0.5) = 0.1;
uniform vec3 ambientColor : source_color = vec3(0.6, 0.2, 0.2);
uniform float ambientStrength : hint_range(0.0, 1.0) = 0.0;
varying float grassHeight;
varying vec3 grassWorldPosition;

vec3 hue_shift(vec3 color, float shift)
{
const vec3 k = vec3(0.57735);
float cosAngle = cos(shift * 6.283185);
float sinAngle = sin(shift * 6.283185);

return color * cosAngle + cross(k, color) * sinAngle + k * dot(k, color) * (1.0 - cosAngle);
}

void vertex()
{
grassHeight = clamp(VERTEX.y, 0.0, 1.0);
grassWorldPosition = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

float sway = sin(grassWorldPosition.x + TIME * windSpeed + grassHeight * 2.0);
VERTEX.x += sway * grassHeight * grassHeight * windStrength;
}

void fragment()
{
float mask = texture(alphaMask, UV).r;
ALPHA = mask;
vec3 grassColor = texture(albedoGradient, vec2(grassHeight, 0.5)).rgb;
vec2 noiseUV = grassWorldPosition.xz * (0.3 * hueNoiseScale);
float hueNoise = texture(hue_noise, noiseUV).r;
float hueVariation = (hueNoise - 0.5) * hueStrength;

grassColor = hue_shift(grassColor, hueVariation);

vec3 finalColor = mix(grassColor, ambientColor, ambientStrength * 0.5);

NORMAL = vec3(1.0, 1.0, 1.0);
ALBEDO = finalColor;
ALPHA_SCISSOR_THRESHOLD = 0.5;
}
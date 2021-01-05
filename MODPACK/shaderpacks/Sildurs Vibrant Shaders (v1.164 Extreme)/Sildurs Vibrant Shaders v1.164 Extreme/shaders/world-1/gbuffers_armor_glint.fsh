#version 120
/* DRAWBUFFERS:56 */

uniform sampler2D texture;

varying vec4 color;
varying vec2 texcoord;

uniform int worldTime;
uniform ivec2 eyeBrightness;

float cavelight = pow(eyeBrightness.y / 255.0, 6.0f) * 1.0 + 0.45;

void main() {

vec4 albedo = texture2D(texture, texcoord.st)*color;

vec3 lighting = vec3(1.0);
	 lighting /= cavelight;

	albedo.rgb = pow(albedo.rgb*0.33, lighting);

	gl_FragData[0] = albedo;

}
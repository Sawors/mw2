#version 120
/* DRAWBUFFERS:56 */
//Render hand, entities and particles in here, boost and fix enchanted armor effect in gbuffers_armor_glint
/*
                            _____ _____ ___________
                           /  ___|_   _|  _  | ___ \
                           \ `--.  | | | | | | |_/ /
                            `--. \ | | | | | |  __/
                           /\__/ / | | \ \_/ / |
                           \____/  \_/  \___/\_|
						Sildur's vibrant shaders v1.16 and newer
						Before editing anything here make sure you've
						read The agreement, which you accepted by downloading
						my shaderpack. The agreement can be found here:
			http://www.minecraftforum.net/topic/1953873-164-172-sildurs-shaders-pcmacintel/

*/
#define MobsFlashRed

#define SHADOW_MAP_BIAS 0.8
const float shadowMapResolution = 3072;		//set to same as main shadows [512 1024 2048 3072 4096 8192]

varying vec4 color;
varying vec2 texcoord;
varying vec3 normal;
varying vec3 ambientNdotL;
varying vec3 finalSunlight;
varying float skyL;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2DShadow shadow;

uniform float viewWidth;
uniform float viewHeight;
uniform vec4 entityColor;

uniform vec3 sunPosition;
uniform int worldTime;
uniform ivec2 eyeBrightness;

void main() {

	float diffuse = dot(normalize(sunPosition),normal);
		  diffuse = (worldTime > 12700 && worldTime < 23250)? -diffuse : diffuse;
		  diffuse = max(diffuse,0.0);
	
	vec4 albedo = texture2D(texture, texcoord.xy)*color;
#ifdef MobsFlashRed
	albedo.rgb = mix(albedo.rgb,entityColor.rgb,entityColor.a);
#endif
//don't do shading if transparent/translucent (not opaque)
if (albedo.a > 0.01){ 
vec4 fragposition = gbufferProjectionInverse*(vec4(gl_FragCoord.xy/vec2(viewWidth,viewHeight),gl_FragCoord.z,1.0)*2.0-1.0);
	
vec4 worldposition = gbufferModelViewInverse * fragposition;
	 worldposition = shadowModelView * worldposition;
	 worldposition = shadowProjection * worldposition;
	 worldposition /= worldposition.w;
	vec2 pos = abs(worldposition.xy * 1.165);
	float distb = pow(pow(pos.x, 12.0) + pow(pos.y, 12.0), 0.083);
	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
	worldposition.xy /= distortFactor*0.97; 

	if (max(abs(worldposition.x),abs(worldposition.y)) < 0.99) {
		const float diffthresh = 0.0004;
		worldposition = worldposition * vec4(0.5,0.5,0.2,0.5) + vec4(0.5,0.5,0.5-diffthresh,0.5);
	
		//Fast and simple shadow drawing for proper rendering of translucent blocks
		diffuse *= shadow2D(shadow,vec3(worldposition.st, worldposition.z)).x;
	}
	diffuse *= mix(skyL,1.0,clamp((eyeBrightness.y/255.0-2.0/16.)*4.0,0.0,1.0)); //quickly fix light in nether since it reloads the shaders
}
	vec3 finalColor = pow(albedo.rgb,vec3(2.2)) * (finalSunlight*diffuse+ambientNdotL.rgb);

	gl_FragData[0] = vec4(finalColor, albedo.a);
	gl_FragData[1] = vec4(normalize(albedo.rgb+0.00001), albedo.a);		
}
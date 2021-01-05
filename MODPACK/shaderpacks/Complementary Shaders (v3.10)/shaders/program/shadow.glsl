/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float mat;

varying vec2 texCoord;

varying vec4 color;

//Uniforms//
uniform int isEyeInWater;
uniform int blockEntityId;

uniform vec3 fogColor;

uniform sampler2D tex;

//Includes//
#include "/lib/color/waterColor.glsl"

//Program//
void main(){
    #if MC_VERSION >= 11300
		if (blockEntityId == 138) discard;
	#endif

	#if defined WRONG_MIPMAP_FIX
  		vec4 albedo = texture2DLod(tex, texCoord.xy, 0.0);
	#else
		vec4 albedo = texture2D(tex, texCoord.xy);
	#endif

	albedo.rgb *= color.rgb;

    float premult = float(mat > 0.95 && mat < 1.05);
	float water = float(mat > 1.95 && mat < 2.05);
	float ice = float(mat > 2.95 && mat < 3.05);
	
	float disable = float(mat > 3.95 && mat < 4.05);
	if (disable > 0.5) discard;

    #ifdef SHADOW_COLOR
		albedo.rgb = mix(vec3(1.0), albedo.rgb, pow(albedo.a, (1.0 - albedo.a) * 0.5) * 1.05);
		albedo.rgb *= 1.0 - pow(albedo.a, 64.0);

		if (water > 0.5) {
			if (isEyeInWater < 0.5) {
				vec3 waterShadowColor = waterColor.rgb * waterColor.rgb;
				albedo.rgb = waterShadowColor;
				float maxWater = max(waterShadowColor.b, max(waterShadowColor.r, waterShadowColor.g));
				albedo.rgb *= (1.0 / maxWater);
			} else {
				discard;
			}
		}

		if (ice > 0.5) {
			if (isEyeInWater < 0.5) {
				albedo.rgb *= albedo.rgb * albedo.rgb;
			} else {
				discard;
			}
		}
	#else
		if (water > 0.5) discard;
		if (premult > 0.5) {
			if (albedo.a < 0.51) discard;
		}
	#endif

	gl_FragData[0] = clamp(albedo, vec4(0.0), vec4(1.0));
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat;

varying vec2 texCoord, lmCoord;

varying vec4 color;

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main(){
	texCoord = gl_MultiTexCoord0.xy;
	color = gl_Color;
	
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);
	
	mat = 0;
	if (mc_Entity.x == 79) mat = 1; //premult
	if (mc_Entity.x == 7979) mat = 3; //ice
	if (mc_Entity.x == 8) mat = 2; //water

	#ifdef NO_GRASS_SHADOWS
		if (mc_Entity.x == 31 || mc_Entity.x == 6 || mc_Entity.x == 59 || mc_Entity.x == 175 || mc_Entity.x == 176) mat = 4; //disable
	#endif
	
	vec4 position = shadowModelViewInverse * shadowProjectionInverse * ftransform();
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz += WavingBlocks(position.xyz, istopv);

	#ifdef WORLD_CURVATURE
		position.y -= WorldCurvature(position.xz);
	#endif
	
	gl_Position = shadowProjection * shadowModelView * position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);
	
	gl_Position.xy *= 1.0 / distortFactor;
	gl_Position.z = gl_Position.z * 0.2;
}

#endif
/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 
//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 fogColor;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef LIGHT_SHAFT
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#ifdef LIGHTSHAFT_WATER_CAUSTICS
uniform sampler2D noisetex;
#endif
#endif

#if defined BLACK_OUTLINE || defined PROMO_OUTLINE || (defined LIGHTSHAFT_WATER_CAUSTICS && defined LIGHT_SHAFT)
uniform float shadowFade;
#endif

#if defined BLACK_OUTLINE || defined PROMO_OUTLINE
uniform float sunAngle;

uniform vec3 skyColor;
#endif

//Attributes//

//Optifine Constants//

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;

#ifdef LIGHT_SHAFT
#ifdef LIGHTSHAFT_WATER_CAUSTICS
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif
#endif
#endif

#if defined BLACK_OUTLINE || defined PROMO_OUTLINE
vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));
#endif

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/waterFog.glsl"
//#include "/lib/lighting/ambientOcclusion.glsl"
#include "/lib/color/dimensionColor.glsl"

#include "/lib/util/spaceConversion.glsl"

#ifdef LIGHT_SHAFT
#ifdef LIGHTSHAFT_WATER_CAUSTICS
#include "/lib/lighting/caustics.glsl"
#endif
#include "/lib/atmospherics/volumetricLight.glsl"
#endif

#if (defined BLACK_OUTLINE || defined PROMO_OUTLINE)
#ifdef OVERWORLD
#include "/lib/color/skyColor.glsl"
#include "/lib/atmospherics/sky.glsl"
#endif
#include "/lib/atmospherics/fog.glsl"
#endif

#ifdef PROMO_OUTLINE
#include "/lib/outline/promoOutline.glsl"
#endif

#ifdef BLACK_OUTLINE
#include "/lib/color/blocklightColor.glsl"
#include "/lib/outline/blackOutline.glsl"
#endif

//Program//
void main(){
    vec4 color = texture2D(colortex0, texCoord.xy);
    vec3 translucent = texture2D(colortex1,texCoord.xy).rgb;
	float z0 = texture2D(depthtex0, texCoord.xy).r;
	float z1 = texture2D(depthtex1, texCoord.xy).r;
    
	
	#if defined AO || defined LIGHT_SHAFT
		float dither = Bayer64(gl_FragCoord.xy);
	#endif

	/*
	#ifdef AO
		float lz0 = GetLinearDepth(z0) * far;
		if (z1 - z0 > 0.0 && lz0 < 32.0){
			if (dot(translucent, translucent) < 0.02){
				float ao = 1.0;
				ao = pow(ao, AO_STRENGTH);
				float aoMix = clamp(0.03125 * lz0, 0.0 , 1.0);
				color.rgb *= mix(ao, 1.0, aoMix);
			}
		}
	#endif
	*/

	#ifdef BLACK_OUTLINE
		float outlineMask = BlackOutlineMask(depthtex0, depthtex1);
		float wFogMult = 1.0 + eBS;
		if (outlineMask > 0.5 || isEyeInWater > 0.5)
			BlackOutline(color.rgb, depthtex0, wFogMult);
	#endif
	
	#ifdef PROMO_OUTLINE
		if (z1 - z0 > 0.0) PromoOutline(color.rgb, depthtex0);
	#endif

	if (isEyeInWater == 1.0 && z0 == 1.0) {
		color.rgb *= pow(rawWaterColor.rgb, vec3(0.5)) * 3;
		color.rgb = 0.8 * pow(rawWaterColor.rgb * (1.0 - blindFactor), vec3(2.0));
	}

	if (isEyeInWater == 2) color.rgb *= vec3(1.0, 0.25, 0.01);
	
	#ifdef LIGHT_SHAFT
		vec3 vl = getVolumetricRays(z0, z1, translucent, dither);
	#else
		vec3 vl = vec3(0.0);
    #endif
	
    /*DRAWBUFFERS:01*/
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(vl, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main(){
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif

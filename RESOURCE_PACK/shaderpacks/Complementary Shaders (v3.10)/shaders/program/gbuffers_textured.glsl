/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

#ifndef NO_PARTICLES

//Extensions//

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float far;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;
uniform float eyeAltitude;
uniform float sunAngle;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

#ifdef ADVANCED_MATERIALS
uniform sampler2D specular;
uniform sampler2D normals;
#endif

#ifdef WATER_CAUSTICS
#ifdef OVERWORLD
uniform vec3 cameraPosition;
uniform sampler2D noisetex;
#endif
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;

#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float InterleavedGradientNoise(){
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 8.0);
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/color/waterColor.glsl"

#ifdef OVERWORLD
#include "/lib/atmospherics/sky.glsl"
#endif

#include "/lib/atmospherics/fog.glsl"

#ifdef WATER_CAUSTICS
#ifdef OVERWORLD
#include "/lib/lighting/caustics.glsl"
#endif
#endif

#if AA == 2 || AA == 3
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
#include "/lib/util/jitter2.glsl"
#endif

#endif

//Program//
void main(){
	vec4 albedo = vec4(0.0);
	vec3 vlAlbedo = vec3(1.0);

	#ifndef NO_PARTICLES
		albedo = texture2D(texture, texCoord) * color;
		
		#ifdef GREY
			albedo.rgb = vec3((albedo.r + albedo.g + albedo.b) / 2);
		#endif
		
		float skymapMod = 0.0;
		
		if (albedo.a > 0.0) {
			vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));

			#if MC_VERSION >= 11500
				vlAlbedo = mix(vec3(1.0), albedo.rgb, sqrt(albedo.a)) * (1.0 - pow(albedo.a, 64.0));
			#endif

			float particleReduction = 1.0;

			vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
			#if AA > 1
				vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
			#else
				vec3 viewPos = ToNDC(screenPos);
			#endif
			vec3 worldPos = ToWorld(viewPos);

			#if defined FOG1 && defined FOG1_CHECK
				float lWorldPos = length(worldPos.xz);
				float fog1 = lWorldPos / far * 1.5 * (1 + rainStrength*0.3) * (10/FOG1_DISTANCE);
				fog1 = 1.0 - exp(-0.1 * pow(fog1, 10 - rainStrength*5));
				if (fog1 > 0.95) discard;
			#endif

			vec3 nViewPos = normalize(viewPos.xyz);
			float NdotU = dot(nViewPos, upVec);
			float lViewPos = length(viewPos);

			float emissive = 0.0;
			float metalness = 0.0;
			#ifdef ADVANCED_MATERIALS
				vec3 normalMap = texture2D(normals, texCoord).xyz;

				if (normalMap == vec3(1.0)) {
					metalness = texture2D(specular, texCoord).g;
				}

				if (normalMap == vec3(0.0)) {
					vec4 specularMap = texture2D(specular, texCoord);

					float sweep          = float(specularMap.r > 0.01 && specularMap.r < 0.05);
					float endAndRedstone = float(specularMap.r > 0.05 && specularMap.r < 0.1 && albedo.r / albedo.g > 2.9);
					float underWater     = float(specularMap.r > 0.05 && specularMap.r < 0.1 && albedo.r < 0.45 && isEyeInWater == 1);
					float water          = float(specularMap.g > 0.01 && specularMap.g < 0.05);
					float waterDrip      = float(specularMap.b > 0.01 && specularMap.b < 0.05 && albedo.r < 0.35);
					float lavaDrip       = float(specularMap.b > 0.01 && specularMap.b < 0.05 && albedo.r > 0.35 && albedo.b / albedo.g > 0.2);
					float bigSmoke       = float(specularMap.g > 0.05 && specularMap.g < 0.1);
					float enchant        = float(specularMap.b > 0.05 && specularMap.b < 0.1);

					particleReduction = 0.0;
					if (sweep          > 0.5) lightmap.x = 0.0, albedo.rgb = vec3(0.75);
					if (endAndRedstone > 0.5) lightmap = vec2(0.0), emissive = max(pow(albedo.r, 5.0), 0.1);
					if (underWater     > 0.5) albedo.rgb = rawWaterColor.rgb * rawWaterColor.a * 2.5, vlAlbedo = vec3(1.0);
					if (water          > 0.5) albedo.rgb = waterColor.rgb * 2.5;
					if (waterDrip      > 0.5) albedo.rgb = waterColor.rgb * 2.5;
					if (lavaDrip       > 0.5) emissive = 1.0 - albedo.g;
					if (bigSmoke       > 0.5) albedo.a *= 0.2;
					if (enchant        > 0.5) emissive = 0.125;
				}
			#endif

			albedo.rgb = pow(albedo.rgb, vec3(2.2));
			albedo.rgb *= (1.0 - metalness*0.75);

			#ifdef WHITE_WORLD
				albedo.rgb = vec3(0.5);
			#endif

			float NdotL = 1.0;
			NdotL = clamp(dot(normal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

			float quarterNdotU = clamp(0.25 * dot(normal, upVec) + 0.75, 0.5, 1.0);
				quarterNdotU*= quarterNdotU;
			
			vec3 shadow = vec3(0.0);
			GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, 1.0, NdotL, 1.0,
						1.0, emissive, 0.0, 0.0, 0.0, 0.0);
			
			//if (far > 50) albedo.a *= clamp(far - 30 - lViewPos, 0.0, 1.0);

			#ifndef COMPATIBILITY_MODE
				albedo.rgb *= 2;
			#endif

			#if !defined COMPATIBILITY_MODE && defined PARTICLE_VISIBILITY
				if (particleReduction > 0.5) {
					if (lViewPos < 2) albedo.a *= smoothstep(0.7, 2.0, lViewPos) + 0.0002;
					if (albedo.a < 0.1) discard;
				}
			#endif
			
			#if defined WATER_CAUSTICS && defined OVERWORLD
				if (isEyeInWater == 1){
				float skyLightMap = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);
				albedo.rgb = GetCaustics(albedo.rgb, worldPos.xyz, cameraPosition.xyz, shadow, skyLightMap, lightmap.x);
				}
			#endif

			albedo.rgb = startFog(albedo.rgb, nViewPos, lViewPos, worldPos, NdotU);
		} else discard;
	#endif
	
    /* DRAWBUFFERS:01 */
    gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(vlAlbedo, 1.0);

	#ifdef ADVANCED_MATERIALS
	/* DRAWBUFFERS:01367 */
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[4] = vec4(0.0, 0.0, 0.0, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

#ifndef NO_PARTICLES

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#if AA > 1
uniform int frameCounter;

uniform float viewWidth, viewHeight;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Common Functions//

//Includes//
#if AA == 2 || AA == 3
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
#include "/lib/util/jitter2.glsl"
#endif

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

#endif

//Program//
void main(){
	#ifndef NO_PARTICLES
		texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		
		lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
		lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);

		normal = normalize(gl_NormalMatrix * gl_Normal);
		
		color = gl_Color;

		const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
		float ang = fract(timeAngle - 0.25);
		ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
		sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

		upVec = normalize(gbufferModelView[1].xyz);

		#ifdef WORLD_CURVATURE
			vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
			position.y -= WorldCurvature(position.xz);
			gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
		#else
			gl_Position = ftransform();
		#endif
		
		#if AA > 1
			gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
		#endif
		
	#else
		
		gl_Position = vec4(0.0);
		
	#endif
}

#endif
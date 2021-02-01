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
uniform int worldDay;
uniform int worldTime;

uniform float blindFactor, nightVision;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;
uniform float shadowFade;
uniform float eyeAltitude;
uniform float sunAngle;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

#ifdef AO
uniform sampler2D colortex4;
#endif

#if defined ADVANCED_MATERIALS || defined GLOWING_ENTITY_FIX
uniform sampler2D colortex3;
#endif

#if (defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR) || (defined SEVEN)
uniform vec3 cameraPosition, previousCameraPosition;

uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D noisetex;
#endif

//Optifine Constants//
#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
const bool colortex0MipmapEnabled = true;
const bool colortex3MipmapEnabled = false;
const bool colortex5MipmapEnabled = false;
const bool colortex6MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;

vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

vec2 aoOffsets[4] = vec2[4](
	vec2( 1.0,  0.0),
	vec2( 0.0,  1.0),
	vec2(-1.0,  0.0),
	vec2( 0.0, -1.0)
);

#if WORLD_TIME_ANIMATION == 2
float modifiedWorldDay = worldDay - int(worldDay*0.01) * 100 + 9.5;
float frametime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
float cloudtime = frametime;
#endif
#if WORLD_TIME_ANIMATION == 1
float modifiedWorldDay = worldDay - int(worldDay*0.01) * 100 + 9.5;
float frametime = frameTimeCounter * ANIMATION_SPEED;
float cloudtime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
#endif
#if WORLD_TIME_ANIMATION == 0
float frametime = frameTimeCounter * ANIMATION_SPEED;
float cloudtime = frametime;
#endif

#ifdef END
vec3 lightNight = vec3(0.0);
#endif

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

float InterleavedGradientNoise(){
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 8.0);
}

#ifdef AO
float GetAmbientOcclusion(float z) {
	float ao = 0.0;
	float tw = 0.0;
	float lz = GetLinearDepth(z);

	#if AO_QUALITY == 1 && AA > 1
		vec2 halfView = vec2(viewWidth, viewHeight) / 2.0;
		vec2 coord1 = (floor(texCoord * halfView + 1.0)) / halfView;
		vec2 coord2 = texCoord * 0.5;
	#else
		vec2 coord1 = texCoord;
		vec2 coord2 = texCoord;
	#endif
	

	for(int i = 0; i < 4; i++) {
		vec2 offset = aoOffsets[i] / vec2(viewWidth, viewHeight);
		float samplez = GetLinearDepth(texture2D(depthtex0, coord1 + offset * 2.0).r);
		float wg = max(1.0 - 2.0 * far * abs(lz - samplez), 0.0);
		ao += texture2D(colortex4, coord2 + offset).r * wg;
		tw += wg;
	}
	ao /= tw;
	if(tw < 0.0001) ao = texture2D(colortex4, coord2).r;

	float aoStrength = AO_STRENGTH;

	#if AO_QUALITY == 2 || (AO_QUALITY == 1 && AA <= 1)
		aoStrength *= 0.75;
	#endif
	
	//return pow(texture2D(colortex4, coord2).r, AO_STRENGTH);
	return pow(ao, aoStrength);
}
#endif

//Includes//
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"

#ifdef OVERWORLD
#include "/lib/atmospherics/sky.glsl"
#endif

#include "/lib/atmospherics/fog.glsl"

#ifdef BLACK_OUTLINE
#include "/lib/outline/blackOutline.glsl"
#endif

#ifdef PROMO_OUTLINE
#include "/lib/outline/promoOutline.glsl"
#endif

#if (defined SEVEN) || (defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR && (defined OVERWORLD || defined END))
#include "/lib/atmospherics/clouds.glsl"
#endif

#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
#include "/lib/util/encode.glsl"
#include "/lib/reflections/raytrace.glsl"
#include "/lib/reflections/complexFresnel.glsl"
#include "/lib/surface/materialDeferred.glsl"
#include "/lib/reflections/roughReflections.glsl"
#endif

//Program//
void main(){
    vec4 color = texture2D(colortex0, texCoord);
	float z    = texture2D(depthtex0, texCoord).r;

	float dither = Bayer64(gl_FragCoord.xy);
	
	vec4 screenPos = vec4(texCoord, z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	if (z < 1.0) {
		vec3 nViewPos = normalize(viewPos.xyz);
		float NdotU = dot(nViewPos, upVec);
		float lViewPos = length(viewPos.xyz);
	
		#ifdef AO
			float ao = GetAmbientOcclusion(z);
			float ambientOcclusion = ao;
		#endif

		#if defined ADVANCED_MATERIALS || defined GLOWING_ENTITY_FIX
			float skymapMod = texture2D(colortex3, texCoord).b;
		#endif
	
		#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
			float smoothness = 0.0, metalness = 0.0, f0 = 0.0, materialFormat = 0.0;
			vec3 normal = vec3(0.0), rawAlbedo = vec3(0.0);

			GetMaterials(materialFormat, smoothness, metalness, f0, normal, rawAlbedo, texCoord);
			smoothness *= smoothness;
			
			float fresnel = pow(clamp(1.0 + dot(normal, nViewPos), 0.0, 1.0), 5.0);
			vec3 fresnel3 = vec3(0.0);
			
			if (materialFormat > 0.9) {
				fresnel3 = mix(mix(vec3(0.02), rawAlbedo*5, metalness), vec3(1.0), fresnel);
				if (metalness <= 0.004 && metalness > 0.0) fresnel3 = vec3(0.0);
				fresnel3 *= 0.25*smoothness;
			} else {
				#if MATERIAL_FORMAT == -1
					fresnel3 = mix(mix(vec3(0.02), rawAlbedo*5, metalness), vec3(1.0), fresnel);
					fresnel3 *= 0.25*smoothness;
				#endif
				#if MATERIAL_FORMAT == 0
					fresnel3 = mix(mix(vec3(f0), rawAlbedo*5, metalness), vec3(1.0), fresnel);
					if (f0 >= 0.9 && f0 < 1.0) {
						fresnel3 = ComplexFresnel(fresnel, f0);
						color.rgb *= pow(fresnel3, vec3(0.5));
					}
					fresnel3 *= 0.2*smoothness*(metalness*0.5+0.5);
				#endif
			}

			if (length(fresnel3) > 0.0025) {
				vec4 reflection = vec4(0.0);
				vec3 skyReflection = vec3(0.0);
				
				reflection = RoughReflection(viewPos.xyz, normal, dither, smoothness, colortex0);

				if (skymapMod > 0.0 && skymapMod < 0.55){
					#ifdef OVERWORLD
						fresnel3 = fresnel3 * 5.0 + vec3(0.05);

						skymapMod = skymapMod * 2.0;
						#if SKY_REF_FIX_1 == 1
							skymapMod = skymapMod * skymapMod;
						#elif SKY_REF_FIX_1 == 2
							skymapMod = max(skymapMod - 0.80, 0.0) * 5.0;
						#else
							skymapMod = max(skymapMod - 0.99, 0.0) * 100.0;
						#endif
						skymapMod = skymapMod * 0.5;

						vec3 skyReflectionPos = reflect(nViewPos, normal);
						float refNdotU = dot(skyReflectionPos, upVec);
						skyReflection = GetSkyColor(lightCol, refNdotU, skyReflectionPos, true);

						#ifdef CLOUDS
							vec4 cloud = DrawCloud(skyReflectionPos * 100.0, dither, lightCol, ambientCol, refNdotU);
							float cloudMixRate = smoothness * smoothness * (3.0 - 2.0 * smoothness);
							skyReflection = mix(skyReflection, cloud.rgb, cloud.a * cloudMixRate);
						#endif
						skyReflection = mix(vec3(0.001), skyReflection, skymapMod * 2.0);
					#endif
					#ifdef NETHER
						skyReflection = netherCol * 0.005;
					#endif
					#ifdef END
						skyReflection = endCol * 0.025;
						#if defined CLOUDS && defined END_CLOUDS
							vec3 skyReflectionPos = reflect(nViewPos, normal);
							vec4 cloud = DrawEndCloud(skyReflectionPos * 100.0, dither, endCol);
							skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
						#endif
						skyReflection *= 5.0;
					#endif
				}

				reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));
				
				#ifdef AO
					reflection.rgb *= pow(ao, 13.0 - skymapMod * 24.0);
				#endif
				
				color.rgb = color.rgb * (1.0 - fresnel3 * (1.0 - metalness)) +
							reflection.rgb * fresnel3;
			}
		#endif
		
		#ifdef GLOWING_ENTITY_FIX
			if (skymapMod > 0.85) {
				vec2 glowOutlineOffsets[8] = vec2[8](
									vec2(-1.0, 0.0),
									vec2( 0.0, 1.0),
									vec2( 1.0, 0.0),
									vec2( 0.0,-1.0),
									vec2(-1.0,-1.0),
									vec2(-1.0, 1.0),
									vec2( 1.0,-1.0),
									vec2( 1.0, 1.0)
									);

				float outline = 0.0;

				for(int i = 0; i < 64; i++){
					vec2 offset = vec2(0.0);
					offset = glowOutlineOffsets[i-8*int(i/8)] * 0.00025 * (int(i/8)+1);
					outline += clamp(1 - texture2D(colortex3, texCoord + offset).b, 0.0, 1.0);
				}
				
				color.rgb += outline * vec3(0.25);
			}
		#endif
		
		#ifdef AO
			if (skymapMod < 0.55 || skymapMod > 0.65) color.rgb *= ambientOcclusion;
		#endif
		
		#ifdef PROMO_OUTLINE
			PromoOutline(color.rgb, depthtex0);
		#endif
        
		vec3 worldPos = ToWorld(viewPos.xyz);
		color.rgb = startFog(color.rgb, nViewPos, lViewPos, worldPos, NdotU);
	
	} else {
		float NdotU = 0.0;

		#ifdef NETHER
			color.rgb = pow((netherCol * 2.5) / NETHER_I, vec3(2.2)) * 4;
		#endif
		
		#ifdef TWENTY
			color.rgb *= 0.1;
		#endif
		
		#ifdef SEVEN
			NdotU = max(dot(normalize(viewPos.xyz), upVec), 0.0);

			vec3 twilightPurple = vec3(0.005, 0.006, 0.018);
			vec3 twilightGreen = vec3(0.015, 0.03, 0.02);

			#ifdef TWENTY
				twilightPurple = twilightGreen * 0.1;
			#endif

			color.rgb = 2 * (twilightPurple * 2 * clamp(pow(NdotU, 0.7), 0.0, 1.0) + twilightGreen * (1-clamp(pow(NdotU, 0.7), 0.0, 1.0)));

			#ifndef TWENTY
				vec3 stars = DrawStars(color.rgb, viewPos.xyz, NdotU);
				color.rgb += stars.rgb;
			#endif
		#endif
		
		#ifdef TEN
			color.rgb = vec3(0.0, 0.0, 0.0);
		#endif
		
		#ifdef TWO
			NdotU = 1.0 - max(dot(normalize(viewPos.xyz), upVec), 0.0);
			NdotU *= NdotU;
			vec3 midnightPurple = vec3(0.0003, 0.0004, 0.002) * 1.25;
			vec3 midnightFogColor = fogColor * fogColor * 0.3;
			color.rgb = mix(midnightPurple, midnightFogColor, NdotU);
		#endif
		
		#ifdef END
			color.rgb *= pow(color.rgb, vec3(2.2));
			color.rgb += endCol * 0.055;
		#endif

		if (isEyeInWater == 1) {
			NdotU = max(dot(normalize(viewPos.xyz), upVec), 0.0);
			color.rgb = mix(color.rgb, 0.8 * pow(rawWaterColor.rgb * (1.0 - blindFactor), vec3(2.0)), 1 - NdotU*NdotU);
		}
		if (isEyeInWater == 2) color.rgb = vec3(0.5);
		if (blindFactor > 0.0) color.rgb *= 1.0 - blindFactor;
	}
    
	#ifdef BLACK_OUTLINE
		float wFogMult = 1.0 + eBS;
		BlackOutline(color.rgb, depthtex0, wFogMult);
	#endif

	#ifdef END
		z *= 0.0;
	#endif
	
	/*DRAWBUFFERS:05*/
    gl_FragData[0] = color;
	gl_FragData[1] = vec4(pow(color.rgb, vec3(0.125)) * 0.5, float(z < 1.0));
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

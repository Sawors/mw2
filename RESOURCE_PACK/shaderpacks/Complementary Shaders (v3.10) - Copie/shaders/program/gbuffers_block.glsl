/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

#if defined ENTITY_NORMAL_FIX && MC_VERSION >= 11500
#undef REFLECTION_ROUGH
#undef PARALLAX
#undef SELF_SHADOW
#endif

//Extensions//

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
#if defined PARALLAX || defined SELF_SHADOW
varying float dist;
varying vec3 viewVector;
#endif

#if !defined ENTITY_NORMAL_FIX || MC_VERSION < 11500
varying vec3 binormal, tangent;
#endif

varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int blockEntityId;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 fogColor;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

#if defined FOG1 && defined FOG1_CHECK
uniform float far;
#endif

#ifdef WATER_CAUSTICS
#ifdef OVERWORLD
uniform vec3 cameraPosition;
uniform sampler2D noisetex;
#endif
#endif

#ifdef ADVANCED_MATERIALS
uniform sampler2D specular;
uniform sampler2D normals;

#ifdef REFLECTION_ROUGH
uniform sampler2D depthtex0;
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

#ifdef ADVANCED_MATERIALS
vec2 dcdx = dFdx(texCoord.xy);
vec2 dcdy = dFdy(texCoord.xy);
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
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/lighting/forwardLighting.glsl"

#ifdef WATER_CAUSTICS
#ifdef OVERWORLD
#include "/lib/color/waterColor.glsl"
#include "/lib/lighting/caustics.glsl"
#endif
#endif

#if AA == 2 || AA == 3
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
#include "/lib/util/jitter2.glsl"
#endif

#ifdef ADVANCED_MATERIALS
#include "/lib/util/encode.glsl"
#include "/lib/surface/ggx.glsl"
#include "/lib/surface/materialGbuffers.glsl"

#if defined PARALLAX || defined SELF_SHADOW
#include "/lib/surface/parallax.glsl"
#endif
#endif

//Program//
void main(){
    vec4 albedo = texture2D(texture, texCoord) * color;
	
	vec3 materialFormatFlag = vec3(1.0);
	
	#ifdef GREY
		albedo.rgb = vec3((albedo.r + albedo.g + albedo.b) / 2);
	#endif
	
	vec3 newNormal = normal;
	vec3 newRough = normal;
	
	float skymapMod = 0.0;
	float emissive = 0.0;

	float signBlockEntity = float(blockEntityId == 63);

	#ifdef ADVANCED_MATERIALS
		vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
		
		#if defined PARALLAX || defined SELF_SHADOW
			float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
			float skipParallax = signBlockEntity;
		#endif
		
		#ifdef PARALLAX
			if (skipParallax < 0.5){
				float materialFormatParallax = 0.0;
				GetParallaxCoord(parallaxFade, newCoord, materialFormatParallax);
				if (materialFormatParallax < 0.5) albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * color;
			}
		#endif

		float smoothness = 0.0, metalData = 0.0;
		vec3 rawAlbedo = vec3(0.0);
	#endif
	
	#ifndef COMPATIBILITY_MODE
		float albedocheck = albedo.a;
	#else
		float albedocheck = 1.0;
	#endif

	if (albedocheck > 0.00001){
		if (albedo.a > 0.99) albedo.a = 1.0;

		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(0.85));

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

		float lViewPos = length(viewPos.xyz);

		float scattering = 0.0;
		#ifdef ADVANCED_MATERIALS
			float metalness = 0.0, f0 = 0.0, ao = 1.0; 
			vec3 roughMap = vec3(0.0);
			vec3 normalMap = vec3(0.0);
			float materialFormat = 0.0;
			GetMaterials(materialFormat, smoothness, metalness, f0, metalData, emissive, ao, scattering, normalMap, roughMap,
						newCoord, dcdx, dcdy);
			if (materialFormat > 0.5) {
				
			} else {
				materialFormatFlag = vec3(0.0);
			}
			
			#if !defined ENTITY_NORMAL_FIX || MC_VERSION < 11500
				mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
									tangent.y, binormal.y, normal.y,
									tangent.z, binormal.z, normal.z);

				if (normalMap.x > -0.999 && normalMap.y > -0.999)
					newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));

				#if defined REFLECTION_SPECULAR && defined REFLECTION_ROUGH
					if (roughMap.x > -0.999 && roughMap.y > -0.999)
						newRough = clamp(normalize(roughMap * tbnMatrix), vec3(-1.0), vec3(1.0));
				#endif
			#endif
		#endif

		#ifdef END_PORTAL_REWORK
			// End Portal fix by fayer3#2332 [Slightly Modified]
			if (blockEntityId == 200) {
				if (albedo.b < 0.1) {
					vec4[16] colors = vec4[](
						vec4(0.34724797, 0.6559956 , 0.73878384,1),
						vec4(0.10107807, 0.6153565 , 0.760625  ,1),
						vec4(0.42210903, 0.81350946, 0.9026056 ,1),
						vec4(0.34922913, 0.82412016, 0.86128217,1),
						vec4(0.4543085 , 0.8238697 , 0.6803233 ,1),
						vec4(0.4144472 , 0.56481653, 0.8037    ,1),
						vec4(0.508905  , 0.6719649 , 0.9982805 ,1),
						vec4(0.53619146, 0.8476583 , 0.5008522 ,1),
						vec4(0.5307609 , 0.655718  , 0.9759534 ,1),
						vec4(0.43974575, 0.4958458 , 0.8425293 ,1),
						vec4(0.53406537, 0.55311275, 1.5943265 ,1),
						vec4(0.24501994, 0.8516629 , 0.82527184,1),
						vec4(0.5902973 , 0.4286982 , 0.64408666,1),
						vec4(0.11820245, 0.7883446 , 0.8049257 ,1),
						vec4(0.40934908, 0.78002053, 0.96041328,1),
						vec4(0.1214321 , 0.47223094, 1.9922364 ,1));
					albedo.rgb = colors[15].rgb*0.001;  
					for (int i = 1; i < 16; i++) {
						float colormult = 1.0/(16-i+20.0);
						albedo.rgb *= 0.69 * (1.0 + float(i > 1));
						float rotation = (i - 0.1 * i + 0.71 * i - 11 * i + 21) * 0.01 + i * 0.01;
						float Cos = cos(radians(rotation));
						float Sin = sin(radians(rotation));
						vec2 offset = vec2(0.0, 1.0/(3600.0/24.0)) * pow(16.0 - i, 2.0) * 0.004;
						vec2 Coord = mat2(Cos, Sin, -Sin, Cos) * (gl_FragCoord.xy);
						albedo += texture2D(texture, Coord + fract(frameTimeCounter * offset) + vec2(-0.334,0))*colors[i-1]*colormult;
					}
					#ifdef ADVANCED_MATERIALS
						smoothness = 1.0;
					#endif
				} else {
					#ifndef COMPATIBILITY_MODE
						albedo.rgb *= 2.2;
					#endif
					emissive = 1.0;
				}
			}
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		#ifdef WHITE_WORLD
			albedo.rgb = vec3(0.5);
		#endif
		
		float NdotL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float quarterNdotU = clamp(0.25 * dot(newNormal, upVec) + 0.75, 0.5, 1.0);
			  quarterNdotU*= quarterNdotU;

		float parallaxShadow = 1.0;
		#ifdef ADVANCED_MATERIALS
			rawAlbedo = albedo.rgb * 0.999 + 0.001;
			albedo.rgb *= ao;

			#ifdef REFLECTION_SPECULAR
				albedo.rgb *= (1.0 - metalness*0.65);
			#endif

			float doParallax = 0.0;
			#ifdef SELF_SHADOW
				#ifdef OVERWORLD
					doParallax = float(lightmap.y > 0.0 && NdotL > 0.0);
				#endif
				#ifdef END
					doParallax = float(NdotL > 0.0);
				#endif
				if (materialFormat > 0.5) doParallax = 0.0;
				
				if (doParallax > 0.5){
					parallaxShadow = GetParallaxShadow(parallaxFade, newCoord, lightVec, tbnMatrix);
					NdotL *= parallaxShadow;
				}
			#endif
		#endif
		
		vec3 shadow = vec3(0.0);

		#if MC_VERSION >= 11500 && !defined COMPATIBILITY_MODE
			if (color.r + color.g + color.b > 2.99 || signBlockEntity < 0.5) {} else {
				albedo.rgb *= 15.0;
				shadow = vec3(1.0);
			}
		#endif

		GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, color.a, NdotL, quarterNdotU,
					parallaxShadow, emissive, 0.0, 0.0, 0.0, scattering);

		#ifdef ADVANCED_MATERIALS
			#if defined OVERWORLD || defined END
				#ifdef OVERWORLD
					vec3 lightME = mix(lightMorning, lightEvening, mefade);
					vec3 lightDayTint = lightDay * lightME * LIGHT_DI;
					vec3 lightDaySpec = mix(lightME, sqrt(lightDayTint), timeBrightness);
					vec3 specularColor = mix(sqrt(lightNight),
												lightDaySpec,
												sunVisibility);
					specularColor *= specularColor;
				#endif
				#ifdef END
					vec3 specularColor = endCol;
				#endif
				
				#ifdef LIGHT_LEAK_FIX
					albedo.rgb += lightmap.y * GetSpecularHighlight(smoothness, metalness, f0, specularColor, rawAlbedo,
													shadow, newNormal, viewPos, materialFormat);
				#else
					albedo.rgb += GetSpecularHighlight(smoothness, metalness, f0, specularColor, rawAlbedo,
													shadow, newNormal, viewPos, materialFormat);
				#endif
			#endif

			#if defined REFLECTION_SPECULAR && defined REFLECTION_ROUGH
				normalMap = mix(vec3(0.0, 0.0, 1.0), roughMap, smoothness);
				newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
			#endif
		#endif
		
		#if defined WATER_CAUSTICS && defined OVERWORLD
			if (isEyeInWater == 1){
			float skyLightMap = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);
			albedo.rgb = GetCaustics(albedo.rgb, worldPos.xyz, cameraPosition.xyz, shadow, skyLightMap, lightmap.x);
			}
		#endif
		
		#ifdef SHOW_LIGHT_LEVELS
			float showLightLevelFactor = fract(frameTimeCounter);
			if (showLightLevelFactor > 0.5) showLightLevelFactor = 1 - showLightLevelFactor;
			if (lmCoord.x < 0.5 && quarterNdotU > 0.99) albedo.rgb += vec3(0.5, 0.0, 0.0) * showLightLevelFactor;
		#endif
	} else discard;

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:03567 */
	gl_FragData[1] = vec4(smoothness, metalData, skymapMod, 1.0);
    gl_FragData[2] = vec4(materialFormatFlag, 1.0);
	gl_FragData[3] = vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[4] = vec4(rawAlbedo, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
#if defined PARALLAX || defined SELF_SHADOW
varying float dist;
varying vec3 viewVector;
#endif

#if !defined ENTITY_NORMAL_FIX || MC_VERSION < 11500
varying vec3 binormal, tangent;
#endif

varying vec4 vTexCoord, vTexCoordAM;
#endif

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

#ifdef ADVANCED_MATERIALS
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;
#endif

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

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

//Program//
void main(){
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp(lmCoord, 0.0, 0.825);

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADVANCED_MATERIALS
		#if !defined ENTITY_NORMAL_FIX || MC_VERSION < 11500
			binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
			tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
			
			#if defined PARALLAX || defined SELF_SHADOW
				mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
									tangent.y, binormal.y, normal.y,
									tangent.z, binormal.z, normal.z);
											
				viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
				dist = length(gl_ModelViewMatrix * gl_Vertex);
			#endif
		#endif

		vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texMinMidCoord = texCoord - midCoord;

		vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
		vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);

		vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
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
}

#endif
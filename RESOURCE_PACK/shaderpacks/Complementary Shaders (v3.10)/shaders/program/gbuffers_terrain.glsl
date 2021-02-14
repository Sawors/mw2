/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Extensions//

//Varyings//
varying float mat, quarterNdotUfactor, eminMat, leaves;
varying float mipMapDisabling;

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
#if defined PARALLAX || defined SELF_SHADOW
varying float dist;
varying vec3 viewVector;
#endif

varying vec3 binormal, tangent;

varying vec4 vTexCoord, vTexCoordAM;
#endif

#ifdef SNOW_MODE
varying float grass;
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
uniform vec3 cameraPosition;

#if defined FOG1 && defined FOG1_CHECK
uniform float far;
#endif

#ifdef WATER_CAUSTICS
#ifdef OVERWORLD
uniform sampler2D noisetex;
#endif
#endif

#ifdef ADVANCED_MATERIALS
uniform sampler2D specular;
uniform sampler2D normals;

#ifdef REFLECTION_ROUGH
uniform sampler2D depthtex0;
#endif

#ifdef REFLECTION_RAIN
uniform float wetness;

uniform mat4 gbufferModelView;
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
#include "/lib/color/waterColor.glsl"

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

#ifdef ADVANCED_MATERIALS
#include "/lib/util/encode.glsl"
#include "/lib/surface/directionalLightmap.glsl"
#include "/lib/surface/ggx.glsl"
#include "/lib/surface/materialGbuffers.glsl"

#if defined PARALLAX || defined SELF_SHADOW
#include "/lib/surface/parallax.glsl"
#endif

#ifdef REFLECTION_RAIN
#include "/lib/reflections/rainPuddles.glsl"
#endif
#endif

//Program//
void main(){
	vec4 albedo = vec4(0.0);
	if (mipMapDisabling < 0.5) albedo.rgb = texture2D(texture, texCoord).rgb * color.rgb;
	if (mipMapDisabling > 0.5) albedo.rgb = texture2DLod(texture, texCoord, 0.0).rgb * color.rgb;
	#if !defined END || !defined COMPATIBILITY_MODE
		albedo.a = texture2D(texture, texCoord).a;
	#else
		albedo.a = texture2DLod(texture, texCoord, 0.0).a;
	#endif
	
	vec3 materialFormatFlag = vec3(1.0);
	
	#ifdef GREY
		albedo.rgb = vec3((albedo.r + albedo.g + albedo.b) / 2);
	#endif
	
	vec3 newNormal = normal;
	vec3 newRough = normal;
	
	float skymapMod = 0.0;

	#ifdef ADVANCED_MATERIALS
		vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
		
		#if defined PARALLAX || defined SELF_SHADOW
			float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
			float skipParallax = float(blockEntityId == 63) + float(mat > 2.98 && mat < 3.02);
		#endif

		#ifdef PARALLAX
			float materialFormatParallax = 0.0;
			GetParallaxCoord(parallaxFade, newCoord, materialFormatParallax);
			if (materialFormatParallax + skipParallax < 0.5) {
				if (mipMapDisabling < 0.5) albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
				if (mipMapDisabling > 0.5) albedo = texture2DLod(texture, newCoord, 0.0) * vec4(color.rgb, 1.0);
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

	if (albedocheck > 0.00001) {
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		
		float subsurface        = float(mat > 0.98 && mat < 1.02);
		float emissive          = float(mat > 1.98 && mat < 2.02) * 0.25;
		float definite_emissive = float(mat > 2.98 && mat < 3.02);
		float custom_emissive   = float(mat > 3.98 && mat < 4.02);

		if (custom_emissive > 0.5) {
			emissive = GetLuminance(albedo.rgb);
			emissive *= emissive;
			#ifndef COMPATIBILITY_MODE
				emissive *= emissive;
				lightmap.x = 0.95;
			#else
				emissive *= 0.5;
			#endif
		}
		
		#if SHADOW_SUBSURFACE == 0
			subsurface = 0.0;
		#endif

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

		float scattering = 0.0;
		#ifdef ADVANCED_MATERIALS
			float metalness = 0.0, f0 = 0.0, ao = 1.0; 
			vec3 roughMap = vec3(0.0);
			vec3 normalMap = vec3(0.0);
			float materialFormat = 0.0;
			GetMaterials(materialFormat, smoothness, metalness, f0, metalData, emissive, ao, scattering, normalMap, roughMap,
						newCoord, dcdx, dcdy);
			if (materialFormat > 0.5) {
				materialFormatFlag = vec3(1.0);

				float glowstone      = float(eminMat > 0.98  && eminMat < 1.02 );
				float seaLantern     = float(eminMat > 1.98  && eminMat < 2.02 );
				float torches        = float(eminMat > 2.98  && eminMat < 3.02 );
				float beacon         = float(eminMat > 3.98  && eminMat < 4.02 );
				float shroomlight    = float(eminMat > 4.98  && eminMat < 5.02 );
				float redstoneLamp   = float(eminMat > 5.98  && eminMat < 6.02 );
				float dragonEgg      = float(eminMat > 6.98  && eminMat < 7.02 );
				float magmaBlock     = float(eminMat > 7.98  && eminMat < 8.02 );
				float overworldOres  = float(eminMat > 8.98  && eminMat < 9.02 );
				float litRedstoneOre = float(eminMat > 9.98  && eminMat < 10.02);
				float netherStems    = float(eminMat > 10.98 && eminMat < 11.02);
				float cauldron       = float(eminMat > 11.98 && eminMat < 12.02);
				float ancientDebris  = float(eminMat > 12.98 && eminMat < 13.02);
				float fire           = float(eminMat > 13.98 && eminMat < 14.02);

				float emissiveBoost = float(eminMat > 86.98 && eminMat < 87.02);

				if (glowstone      > 0.5) emissive *= 1.1;
				if (seaLantern     > 0.5) lightmap.x = 1.0, albedo.b *= 1.07, albedo.rgb *= 0.8, emissive *= 1.25, ao = pow(ao, 1.5);
				if (torches        > 0.5) lightmap.x = min(lightmap.x, 0.86);
				if (beacon         > 0.5) lightmap = vec2(0.0), emissive *= 20.0;
				if (shroomlight    > 0.5) albedo.rgb *= 1.05;
				if (redstoneLamp   > 0.5) lightmap.x = 0.925, albedo.rgb *= 1.1, emissive *= 4.2;
				if (dragonEgg      > 0.5) albedo.rgb *= 1.5, emissive *= 20.0;
				if (magmaBlock     > 0.5) lightmap.x *= 0.9, emissive *= LAVA_BRIGHTNESS*LAVA_BRIGHTNESS;
				if (litRedstoneOre > 0.5) emissive *= 1.00; //unused fn
				if (fire           > 0.5) albedo.rgb = albedo.rgb * (1.0 - float(length(albedo.rgb) > 1.5)) + vec3(0.75) * float(length(albedo.rgb) > 1.5);
				if (cauldron       > 0.5) {
					if (smoothness > 0.9) {
						skymapMod = lmCoord.y * 0.5 + 0.001;
						#if WATER_TYPE == 0
							albedo.rgb = waterColor.rgb;
						#elif WATER_TYPE == 1
							albedo.rgb = pow(albedo.rgb, vec3(1.3));
						#else
							albedo.rgb = vec3(0.4, 0.5, 0.4) * (pow(albedo.rgb, vec3(2.8)) + 4 * waterColor.rgb * pow(albedo.r, 1.8)
														+ 16 * waterColor.rgb * pow(albedo.g, 1.8) + 4 * waterColor.rgb * pow(albedo.b, 1.8));
							albedo.rgb = pow(albedo.rgb * 1.5, vec3(0.5, 0.6, 0.5)) * 0.6;
							albedo.rgb *= 1 + length(albedo.rgb) * pow(WATER_A, 32.0) * 2.0;
						#endif
					}
				}
				#ifndef EMISSIVE_ORES
					if (overworldOres  > 0.5) emissive *= 0.0, metalness *= 0.0;
				#endif
				#ifndef EMISSIVE_NETHER_STEMS
					if (netherStems    > 0.5) emissive *= 0.0;
				#endif
				#ifdef GLOWING_DEBRIS
					if (ancientDebris  > 0.5) emissive = pow(length(albedo.rgb), 5.0) * 5.0;
				#endif

				if (emissiveBoost > 0.5) emissive *= 3.0;
			} else {
				materialFormatFlag = vec3(0.0);
			}
			
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

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		#ifdef SNOW_MODE
			vec3 snowColor = vec3(0.5, 0.5, 0.65);
			float grassFactor = (1.0 - abs(albedo.g - 0.3) * 4.0) * max(grass, leaves);
			float snowFactor = clamp(dot(newNormal, upVec), 0.0, 1.0);
			if (grassFactor > 0.0) snowFactor = max(snowFactor * 0.75, grassFactor);
			snowFactor *= pow(lightmap.y, 16.0) * (1.0 - lightmap.x * lightmap.x * lightmap.x * 1.5);
			albedo.rgb = mix(albedo.rgb, snowColor, clamp(snowFactor, 0.0, 0.85));
		#endif

		#ifdef WHITE_WORLD
			albedo.rgb = vec3(0.5);
		#endif

		float NdotL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float quarterNdotU = clamp(0.25 * dot(newNormal, upVec) + 0.75, 0.5, 1.0);
			  quarterNdotU*= quarterNdotU * (subsurface > 0.5 ? 1.0+lmCoord.y*0.8 : 1.0);
			  quarterNdotU = mix(1.0, quarterNdotU, quarterNdotUfactor);

		float parallaxShadow = 1.0;
		#ifdef ADVANCED_MATERIALS
			rawAlbedo = albedo.rgb * 0.999 + 0.001;
			albedo.rgb *= ao;

			albedo.rgb *= (1.0 - metalness*0.65);

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
				}
			#endif

			#ifdef DIRECTIONAL_LIGHTMAP
				if (materialFormat < 0.5) {
					mat3 lightmapTBN = GetLightmapTBN(viewPos);
					lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, newNormal, lightmapTBN);
					lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, newNormal, lightmapTBN);
				}
			#endif
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, color.a, NdotL, quarterNdotU,
					parallaxShadow, emissive + definite_emissive, subsurface, mat, leaves, scattering);

		#ifdef ADVANCED_MATERIALS
			#if defined OVERWORLD || defined END
				#ifdef OVERWORLD
					vec3 lightME = mix(lightMorning, lightEvening, mefade);
					vec3 lightDayTint = lightDay * lightME * LIGHT_DI;
					vec3 lightDaySpec = mix(lightME, sqrt(lightDayTint), timeBrightness);
					vec3 specularColor = mix(sqrt(lightNight*0.3),
												lightDaySpec,
												sunVisibility);
					specularColor *= specularColor;
				#endif
				#ifdef END
					vec3 specularColor = endCol;
					if (skymapMod > 0.0) skymapMod = min(length(shadow), 0.5);
				#endif
				
				#if defined LIGHT_LEAK_FIX && !defined END
					vec3 specularHighlight = lightmap.y * GetSpecularHighlight(smoothness, metalness, f0, specularColor, rawAlbedo,
													shadow, newNormal, viewPos, materialFormat);
				#else
					vec3 specularHighlight = GetSpecularHighlight(smoothness, metalness, f0, specularColor, rawAlbedo,
													shadow, newNormal, viewPos, materialFormat);
				#endif
				albedo.rgb += specularHighlight * color.a;
			#endif
			
			#if defined REFLECTION_SPECULAR && defined REFLECTION_ROUGH
				if (normalMap.x > -0.999 && normalMap.y > -0.999){
					newNormal = clamp(normalize(newRough), vec3(-1.0), vec3(1.0));
				}
			#endif
		#endif
		
		#if defined WATER_CAUSTICS && defined OVERWORLD
			if (isEyeInWater == 1){
			float skyLightMap = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);
			albedo.rgb = GetCaustics(albedo.rgb, worldPos.xyz, cameraPosition.xyz, shadow, skyLightMap, lightmap.x);
			}
		#endif
		
		#ifdef SHOW_LIGHT_LEVELS
		if (lmCoord.x < 0.533334 && quarterNdotU > 0.99 && subsurface + leaves < 0.1) {
			float showLightLevelFactor = fract(frameTimeCounter);
			if (showLightLevelFactor > 0.5) showLightLevelFactor = 1 - showLightLevelFactor;
			albedo.rgb += vec3(0.5, 0.0, 0.0) * showLightLevelFactor;
		}
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
varying float mat, quarterNdotUfactor, eminMat, leaves;
varying float mipMapDisabling;

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
#if defined PARALLAX || defined SELF_SHADOW
varying float dist;
varying vec3 viewVector;
#endif

varying vec3 binormal, tangent;

varying vec4 vTexCoord, vTexCoordAM;
#endif

#ifdef SNOW_MODE
varying float grass;
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
attribute vec4 mc_midTexCoord;

#ifdef ADVANCED_MATERIALS
attribute vec4 at_tangent;
#endif

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

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
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADVANCED_MATERIALS
		binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
		tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
		
		#if defined PARALLAX || defined SELF_SHADOW
			mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
								tangent.y, binormal.y, normal.y,
								tangent.z, binormal.z, normal.z);
		
			viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
			dist = length(gl_ModelViewMatrix * gl_Vertex);
		#endif

		vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
		vec2 texMinMidCoord = texCoord - midCoord;

		vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
		vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
		
		vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
	color = gl_Color;
	
	
	float compatibilityFactor = 0.0;
	#ifdef COMPATIBILITY_MODE
		compatibilityFactor = 1.0;
	#endif
	
	
	mat = 0.0; quarterNdotUfactor = 1.0; mipMapDisabling = 0.0; eminMat = 0.0, leaves = 0.0;

	if (mc_Entity.x ==  31 || mc_Entity.x ==   6 || mc_Entity.x ==  59 || mc_Entity.x == 175 ||
	    mc_Entity.x == 176 || mc_Entity.x ==  83 || mc_Entity.x == 104 || mc_Entity.x == 105) // Grass+
		mat = 1.0, lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
	if (mc_Entity.x == 18 || mc_Entity.x == 10600 || mc_Entity.x == 11100) // Leaves, Vine, Lily Pad
		#if SHADOW_SUBSURFACE == 2
			leaves = 1.0, mat = 1.0, color.a -= 0.10*lmCoord.y;
		#else
			leaves = 1.0, mat = 1.5, color.a += 0.15*lmCoord.y;
		#endif
	if (mc_Entity.x ==  10) // Lava
		mat = 3.0, quarterNdotUfactor = 0.0, color.a *= 0.40, color.rgb *= sqrt(LAVA_BRIGHTNESS);
	if (mc_Entity.x ==  1010) // Fire
		mat = 3.0, lmCoord.x = 0.5, color.a *= 0.40 - compatibilityFactor * 0.10, color.rgb *= sqrt(FIRE_BRIGHTNESS), eminMat = 14.0;
	if (mc_Entity.x ==  210) // Soul Fire
		mat = 3.0, lmCoord.x = 0.0, color.a *= 0.20 - compatibilityFactor * 0.10, color.rgb *= sqrt(sqrt(FIRE_BRIGHTNESS));
		
	if (mc_Entity.x == 300) // Lectern
		color.a = 1.0;

	//if (mc_Entity.x == 12345) // Custom Emissive
	//	mat = 0.1, lmCoord.x = 1.0;

	#if !defined COMPATIBILITY_MODE && defined ADVANCED_MATERIALS
		if (mc_Entity.x == 91) // Glowstone
			lmCoord.x = 0.885, eminMat = 1.0;
		if (mc_Entity.x == 92) // Sea Lantern
			lmCoord.x = 0.865, eminMat = 2.0;
		if (mc_Entity.x == 95) // Torches
			lmCoord.x = min(lmCoord.x, 0.9), eminMat = 3.0;
		if (mc_Entity.x == 75) // End Rod
			;
		if (mc_Entity.x == 911) // Lantern
			lmCoord.x = min(lmCoord.x, 0.9);
		if (mc_Entity.x == 912) // Soul Lantern
			lmCoord.x = min(lmCoord.x, 0.885);
		if (mc_Entity.x == 93) // Jack o'Lantern
			lmCoord.x = 0.87;
		if (mc_Entity.x == 917) // Magma Block
			lmCoord = vec2(0.87, 0.0), eminMat = 8.0;
		if (mc_Entity.x == 138) // Beacon
			lmCoord.x = 0.885, eminMat = 4.0;
		if (mc_Entity.x == 191) // Shroomlight
			lmCoord.x = 0.865, eminMat = 5.0;
		if (mc_Entity.x == 901) // Redstone Lamp Lit=True
			lmCoord.x = 0.865, eminMat = 6.0;
		if (mc_Entity.x == 94) // Campfire Lit=True, Soul Campfire Lit=True
		    lmCoord.x = min(lmCoord.x, 0.885);
		if (mc_Entity.x == 96) // Sea Pickle
			lmCoord.x = min(lmCoord.x, 0.885);
		if (mc_Entity.x == 866) // Carpets, Wools
			color.a *= (1 - pow(lmCoord.x, 6)*0.5);
		if (mc_Entity.x == 871) // Respawn Anchor Charges=1
			lmCoord.x = 0.8;
		if (mc_Entity.x == 872) // Respawn Anchor Charges=2
			lmCoord.x = 0.82;
		if (mc_Entity.x == 873) // Respawn Anchor Charges=3
			lmCoord.x = 0.84;
		if (mc_Entity.x == 874) // Respawn Anchor Charges=4
			lmCoord.x = 0.87;
		if (mc_Entity.x == 139) // Dragon Egg
			eminMat = 7.0;
		if (mc_Entity.x == 97) // Jigsaw Block, Structure Block
			eminMat = 87.0;
		if (mc_Entity.x == 98) // Command Blocks
			eminMat = 87.0;
		if (mc_Entity.x == 62) // Furnaces Lit=True
			lmCoord.x = pow(lmCoord.x, 1.5);
		if (mc_Entity.x == 77) // Overworld Ores
			eminMat = 9.0;
		if (mc_Entity.x == 777) // Lit Redstone Ore
			eminMat = 10.0;
		if (mc_Entity.x == 880) // Nether Stems
			eminMat = 11.0;
		if (mc_Entity.x == 993) // Cauldron
			eminMat = 12.0;
		if (mc_Entity.x == 1090) // Ancient Debris
			eminMat = 13.0;

		// Too bright near a light source fix
		if (mc_Entity.x == 99 || mc_Entity.x == 991 || mc_Entity.x == 919 || mc_Entity.x == 993 || mc_Entity.x == 12345)
			lmCoord.x = clamp(lmCoord.x, 0.0, 0.87);
		
		// No shading
		if (mc_Entity.x == 91 || mc_Entity.x == 901 || mc_Entity.x == 92 || mc_Entity.x == 97 || mc_Entity.x == 191 || mc_Entity.x == 917 || mc_Entity.x == 12345)
			quarterNdotUfactor = 0.0;

		#ifdef WRONG_MIPMAP_FIX
			if (mc_Entity.x == 917 || mc_Entity.x == 991 || mc_Entity.x == 992 || mc_Entity.x == 880 || mc_Entity.x == 76 || mc_Entity.x == 77 || 
				mc_Entity.x == 919 || mc_Entity.x == 98 || mc_Entity.x ==  96 || mc_Entity.x ==  95 || mc_Entity.x ==  93 || mc_Entity.x ==  901 || 
				mc_Entity.x ==  902 || mc_Entity.x ==  91 || mc_Entity.x ==  92 || mc_Entity.x == 777)
				mipMapDisabling = 1.0;
		#endif
	#endif

	#ifdef SNOW_MODE
		grass = float(mc_Entity.x == 31 || mc_Entity.x == 175 || mc_Entity.x == 176 || mc_Entity.x == 6 || mc_Entity.x == 3737);
	#endif
	
	#ifdef COMPATIBILITY_MODE
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		if (lightmap.x > 0.5) lightmap.x = smoothstep(0.0, 1.0, lightmap.x);
		float newLightmap = pow(lightmap.x, 10.0);
		quarterNdotUfactor = 1.0 - newLightmap;
	#endif
	
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz += WavingBlocks(position.xyz, istopv);

    #ifdef WORLD_CURVATURE
		position.y -= WorldCurvature(position.xz);
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	#if AA > 1
		gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif
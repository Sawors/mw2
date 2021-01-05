/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float vanillaStars;

varying vec3 upVec, sunVec;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;
uniform int worldDay;

uniform float blindFactor;
uniform float frameCounter;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float shadowFade;
uniform float screenBrightness; 
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;
uniform float eyeAltitude;
uniform float sunAngle;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform vec3 fogColor;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D noisetex;

//Optifine Constants//

//Common Variables//
#if WORLD_TIME_ANIMATION >= 1
float modifiedWorldDay = worldDay - int(worldDay*0.01) * 100 + 9.5;
float frametime = (worldTime + modifiedWorldDay * 24000) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;

vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

vec3 RoundSunMoon(vec3 nViewPos, vec3 sunColor, vec3 moonColor, float NdotU){
	float cosS = dot(nViewPos,sunVec);
	float isMoon = float(cosS < 0.0);
	float sun = pow(abs(cosS), 2600.0 * isMoon + 1800.0 * (1 - isMoon));

	float horizonFactor = clamp((NdotU+0.02)*20, 0.0, 1.0);
	sun *= horizonFactor;

	vec3 sunMoonCol = mix(moonColor * (1.0 - sunVisibility), sunColor * sunVisibility, float(cosS > 0.0));

	vec3 finalSunMoon = sun * sunMoonCol * 32.0;
	finalSunMoon = pow(finalSunMoon, vec3(2.0 - min(finalSunMoon.r + finalSunMoon.g + finalSunMoon.b, 1.0)));

	#ifdef COMPATIBILITY_MODE
		finalSunMoon = min(finalSunMoon, vec3(1.0));
	#endif

	return finalSunMoon * (1.0 - rainStrength);
}

//Includes//
#include "/lib/color/lightColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/endColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/clouds.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/sunGlare.glsl"

//Program//
void main(){
	float vanillaStarFactor = 1.0;
	vec3 vanillaStarImage = vec3(0.0);
	
	vec3 albedo = vec3(0.0);

	vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;
	
	float NdotU = dot(normalize(viewPos.xyz), upVec);
	
	#ifdef OVERWORLD
		float cloudMask = 0.0;
		#ifdef CLOUDS
			float dither = Bayer64(gl_FragCoord.xy);
			vec4 cloud = DrawCloud(viewPos.xyz, dither, lightCol, ambientCol, NdotU);
			float cloudOpacity = CLOUD_OPACITY;
			if (cloudOpacity > 0.35) {
				cloudMask = min((cloud.a / (CLOUD_OPACITY * 2.0)), 0.25) + (cloud.a / (CLOUD_OPACITY * 2.0)) * 0.5; 
			}
		#endif
		
		vec3 nViewPos = normalize(viewPos.xyz);
		if (vanillaStars < 0.5) albedo = GetSkyColor(lightCol, NdotU, nViewPos, false);
		
		/*
		#ifdef STARS
			vec3 stars = DrawStars(albedo.rgb, viewPos.xyz, max(NdotU, 0.0));
			#ifdef CLOUDS
				albedo.rgb += stars.rgb * (1 - cloudMask*1.99);
			#else
				albedo.rgb += stars.rgb;
			#endif
		#else
		*/
		float starDeletionTime = min(timeBrightness * 7.15, 1.0) * 0.5 + sunVisibility * 0.5;
		vanillaStarFactor = (1.0 - cloudMask*1.99) * max(NdotU+0.05, 0.0) * (1.0 - starDeletionTime) * (1.0 - sqrt(rainStrength));
		vanillaStarFactor = vanillaStars * clamp(vanillaStarFactor, 0.0, 1.0);
		vanillaStarImage = lightNight * lightNight;
		vanillaStarImage *= vanillaStarFactor * 16.0;
		//#endif
		
		#ifdef ROUND_SUN_MOON
			if (rainStrength < 1.0) {
				vec3 sunColor = vec3(0.9, 0.35, 0.05);
				vec3 moonColor = sqrt(lightNight * 0.75);
				
				
				#ifdef CLOUDS
					sunColor *= 1.0 - cloudMask;
					moonColor *= 1.0 - cloudMask;
				#endif
				
				vec3 roundSunMoon = RoundSunMoon(nViewPos, sunColor, moonColor, NdotU);
				albedo.rgb += roundSunMoon;
			}
		#endif

		if (vanillaStars < 0.5) albedo = SunGlare(albedo, nViewPos, lightCol);
		
		#ifdef CLOUDS
			if (vanillaStars < 0.5) albedo.rgb = mix(albedo.rgb, cloud.rgb, cloud.a);
		#endif

		albedo.rgb *= (1.0 + nightVision);
		if (eyeAltitude < 2.0) albedo.rgb *= min(clamp((eyeAltitude-1.0), 0.0, 1.0) + pow(max(NdotU, 0.0), 4.0), 1.0);
	#endif

    /* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(albedo + vanillaStarImage, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float vanillaStars;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main(){
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	
	gl_Position = ftransform();

	vec3 color = gl_Color.rgb;
	
	//Vanilla Star Dedection by Builderb0y
	vanillaStars = float(color.r == color.g && color.g == color.b && color.r > 0.0);
}

#endif
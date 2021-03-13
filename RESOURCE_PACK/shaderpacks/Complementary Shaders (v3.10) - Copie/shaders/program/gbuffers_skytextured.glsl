/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
#if (defined END) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
varying vec2 texCoord;

varying vec4 color;
#endif

#if (defined END && defined CLOUDS) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
varying vec3 upVec, sunVec;
#endif

//Uniforms//
uniform float screenBrightness;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform sampler2D texture;

#if (defined END && defined CLOUDS) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
uniform float nightVision;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;
#endif

#ifdef END
uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;

uniform sampler2D noisetex;
#endif

//Common Variables//
#if defined END && defined CLOUDS
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#if (defined END && defined CLOUDS) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
#endif

//Common Functions//
#if defined END && defined CLOUDS
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}
#endif

//Includes//
#if defined OVERWORLD && !defined ROUND_SUN_MOON
#include "/lib/color/lightColor.glsl"
#endif
#if defined END && defined CLOUDS
#include "/lib/color/lightColor.glsl"
#include "/lib/color/endColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/clouds.glsl"
#endif

//Program//
void main(){
	#if (defined END) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
		vec4 albedo = texture2D(texture, texCoord.xy);
	#else
		vec4 albedo = vec4(0.0);
	#endif
	
	#if (defined END && defined CLOUDS) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
		vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
		vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;
	#endif
	
	#if defined OVERWORLD && !defined ROUND_SUN_MOON
		vec3 nViewPos = normalize(viewPos.xyz);
		float NdotU = dot(nViewPos, upVec);
		albedo.a *= clamp((NdotU+0.02)*10, 0.0, 1.0);
		albedo *= color;
		albedo.rgb = pow(albedo.rgb, vec3(2.2 + sunVisibility * 2.2)) * (1.0 + sunVisibility * 4.0) * SKYBOX_BRIGHTNESS * albedo.a;
    #endif

	#ifdef END
		//albedo *= color;
		//albedo.rgb *= sqrt(albedo.a);
		//albedo.a = clamp(length(albedo.rgb), 0.0, 1.0);
		//albedo.rgb = pow(albedo.rgb,vec3(2.2)) * SKYBOX_BRIGHTNESS * 0.01;
		
		if (length(color) > 1.015 && length(color) < 1.05) {
			albedo.rgb = albedo.rgb * SKYBOX_BRIGHTNESS * 0.1;
			#if defined CLOUDS && defined END_CLOUDS
				float dither = Bayer64(gl_FragCoord.xy);
				vec4 cloud = DrawEndCloud(viewPos.xyz, dither, endCol);
				cloud = pow(cloud, vec4(1.0 / 2.2));
				albedo.rgb = mix(albedo.rgb, cloud.rgb, cloud.a);
				albedo.a = 1.0;
			#endif
		} else {
			#if defined CLOUDS && defined END_CLOUDS
				if (albedo.a < 0.003929 && !(albedo.a == 0.0) && length(albedo.rgb) < 0.32) albedo.rgb *= 4.0, albedo.a = 1.0;
				albedo *= color;
				albedo.rgb *= sqrt(albedo.a) * 8.0;
				albedo.a = clamp(length(albedo.rgb) * 0.025, 0.0, 1.0);
			#else
				albedo.a = 0.0;
			#endif
		}
		
	#endif
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
#if (defined END) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
varying vec2 texCoord;

varying vec4 color;
#endif

#if (defined END && defined CLOUDS) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
varying vec3 upVec, sunVec;
#endif

//Uniforms//
#if (defined END && defined CLOUDS) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
uniform float timeAngle;

uniform mat4 gbufferModelView;

#if AA == 2 || AA == 3
uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;
#include "/lib/util/jitter.glsl"
#endif
#if AA == 4
uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;
#include "/lib/util/jitter2.glsl"
#endif
#endif

//Program//
void main(){
	#if (defined END) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
		texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		color = gl_Color;
		
		gl_Position = ftransform();
	#endif
	
	#if (defined END && defined CLOUDS) || (defined OVERWORLD && !defined ROUND_SUN_MOON)
		const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
		float ang = fract(timeAngle - 0.25);
		ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
		sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

		upVec = normalize(gbufferModelView[1].xyz);
		
		#if AA > 1
			gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
		#endif
	#else	
		#if !defined END
			vec4 color = vec4(0.0);
			gl_Position = color;
		#endif	
	#endif
}

#endif
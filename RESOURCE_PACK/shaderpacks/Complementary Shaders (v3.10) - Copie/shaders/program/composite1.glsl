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
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;

uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex0;
uniform sampler2D colortex1;

#if LIGHT_SHAFT_MODE == 2
uniform float viewWidth, viewHeight;

uniform mat4 gbufferProjectionInverse;
#endif

//Optifine Constants//
const bool colortex1MipmapEnabled = true;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;

//Includes//
#include "/lib/color/dimensionColor.glsl"

//Program//
void main(){
    vec4 color = texture2D(colortex0,texCoord.xy);

	#if LIGHT_SHAFT_MODE == 1 || defined END
		vec3 vl = texture2DLod(colortex1, texCoord.xy, 1.5).rgb;
		vl *= vl;
	#else
		/*
		vec2 texCoordM = texCoord;
		float checkerBoard = fract(floor(texCoord.x * viewWidth + 1.0 * (float (fract(floor(texCoord.y * viewHeight) / 2.0) > 0.0))) / 2.0);
		if (checkerBoard < 0.1) {
			texCoordM.x -= 1.0 / viewWidth;
		}
		*/

		vec3 vl = texture2DLod(colortex1, texCoord.xy, 1.5).rgb;
		vl = vl * 0.5 + texture2DLod(colortex1, texCoord.xy, 0.5).rgb * 0.5;

		vl *= vl;
	#endif

	#ifdef OVERWORLD
		#if LIGHT_SHAFT_MODE == 1 || defined END
			if (isEyeInWater == 0) {
				vl *= lightCol * lightCol * 0.5;

				vl *= mix(1.0, LIGHT_SHAFT_NOON_MULTIPLIER * 0.5, timeBrightness*timeBrightness);
				vl *= mix(LIGHT_SHAFT_NIGHT_MULTIPLIER * 10.0, 2.0, sunVisibility);
				vl *= mix(1.0, LIGHT_SHAFT_RAIN_MULTIPLIER * 0.25, rainStrength*rainStrength);
			}
			else vl *= length(lightCol) * 0.2 * LIGHT_SHAFT_UNDERWATER_MULTIPLIER  * (1.0 - rainStrength * 0.85);
		#else
			if (isEyeInWater == 0) {
				float lightShaftEndurance = LIGHTSHAFT_ENDURANCE;
				if ((lightShaftEndurance < 5.40 || lightShaftEndurance > 5.60) && rainStrength < 1.0) {
					vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
					vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
					viewPos /= viewPos.w;
					vec3 nViewPos = normalize(viewPos.xyz);

					float NdotU = dot(nViewPos, upVec);
					NdotU = max(NdotU, 0.0);
					//if (NdotU >= 0.9) NdotU = (NdotU - 0.9) * 0.25 + 0.9;
					NdotU = 1.0 - NdotU;
					if (NdotU > 0.5) NdotU = smoothstep(0.0, 1.0, NdotU);
					//NdotU *= NdotU;
					if (rainStrength > 0.0) NdotU = pow(NdotU, 1.0 - rainStrength);
					vl *= NdotU * NdotU * NdotU;
				}

				vec3 dayLightCol = lightCol*lightCol*lightCol;
				vec3 nightLightCol = lightCol * lightCol * 20.0;
				vl *= mix(nightLightCol, dayLightCol, sunVisibility);

				vl *= mix(1.0, LIGHT_SHAFT_NOON_MULTIPLIER * 0.5, timeBrightness*timeBrightness);
				vl *= mix(LIGHT_SHAFT_NIGHT_MULTIPLIER * 0.35, 2.0, sunVisibility);
				vl *= mix(1.0, LIGHT_SHAFT_RAIN_MULTIPLIER * 0.5, rainStrength*rainStrength);
			} else vl *= length(lightCol) * 0.2 * LIGHT_SHAFT_UNDERWATER_MULTIPLIER  * (1.0 - rainStrength * 0.85);
		#endif
	#endif

	#ifdef END
   		vl *= endCol * 0.025;
	#endif

	#if LIGHT_SHAFT_MODE == 1 || defined END
    	vl *= LIGHT_SHAFT_STRENGTH * (1.0 - rainStrength * eBS * 0.875) * shadowFade * (1 + isEyeInWater*1.5) * (1.0 - blindFactor);
	#else
		vl *= LIGHT_SHAFT_STRENGTH * shadowFade * (1.0 - blindFactor);

		float vlFactor = (1.0 - min((timeBrightness)*2.0, 0.75));
		vlFactor = mix(vlFactor, 0.05, rainStrength);
		if (isEyeInWater == 1) vlFactor = 3.0;
		vl *= vlFactor * 1.15;
	#endif

	color.rgb += vl;

	
	/*DRAWBUFFERS:0*/
	gl_FragData[0] = color;
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
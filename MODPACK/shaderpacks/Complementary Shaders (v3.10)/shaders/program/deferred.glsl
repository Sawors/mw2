/* 
BSL Shaders v7.2.01 by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
#ifdef AO
varying vec2 texCoord;
#endif

//Uniforms//
#ifdef AO
uniform float far, near;
uniform float frameTimeCounter;
uniform float viewWidth, viewHeight, aspectRatio;

uniform mat4 gbufferProjection;

uniform sampler2D depthtex0;
uniform sampler2D noisetex;
#endif

//Common Functions//
#ifdef AO
float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}
#endif

//Includes//
#ifdef AO
	#include "/lib/util/dither.glsl"
	#include "/lib/lighting/ambientOcclusion.glsl"
#endif

//Program//
void main() {
	#ifdef AO
    	float ao = AmbientOcclusion(depthtex0, texCoord, Bayer64(gl_FragCoord.xy));
	#else
		float ao = 1.0;
	#endif
    
    /* DRAWBUFFERS:4 */
    gl_FragData[0] = vec4(ao, 0.0, 0.0, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
#ifdef AO
varying vec2 texCoord;

varying vec3 sunVec, upVec, eastVec;
#endif

//Uniforms//
#ifdef AO
uniform float timeAngle;

uniform mat4 gbufferModelView;
#endif

//Program//
void main() {
	#ifdef AO
		texCoord = gl_MultiTexCoord0.xy;
		
		gl_Position = ftransform();

		const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
		float ang = fract(timeAngle - 0.25);
		ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
		sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

		upVec = normalize(gbufferModelView[1].xyz);
		eastVec = normalize(gbufferModelView[0].xyz);
	#else
		gl_Position = vec4(0.0);
		return;
	#endif
}

#endif

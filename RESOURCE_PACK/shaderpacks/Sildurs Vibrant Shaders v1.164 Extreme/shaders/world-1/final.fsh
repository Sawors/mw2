#version 120
/*
                            _____ _____ ___________ 
                           /  ___|_   _|  _  | ___ \
                           \ `--.  | | | | | | |_/ /
                            `--. \ | | | | | |  __/ 
                           /\__/ / | | \ \_/ / |    
                           \____/  \_/  \___/\_|
						Sildur's vibrant shaders v1.16 and newer
						Before editing anything here make sure you've 
						read The agreement, which you accepted by downloading
						my shaderpack. The agreement can be found here:
			http://www.minecraftforum.net/topic/1953873-164-172-sildurs-shaders-pcmacintel/
						   
				This code is from Chocapic13' shaders adapted, modified and tweaked by Sildur 
		http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/1293898-chocapic13s-shaders			
*/

/*--------------------
//ADJUSTABLE VARIABLES//
---------------------*/

//#define Depth_of_Field				//Simulates eye focusing on objects. Low performance impact
	//#define Distance_Blur				//Requires Depth of Field to be enabled. Replaces eye focusing effect with distance being blurred instead.

//#define Motionblur					//Blurres your view/camera during movemenent. Low performance impact. Doesn't work with Depth of Field.

/*---------------------------
//END OF ADJUSTABLE VARIABLES//
----------------------------*/	
	
//Defined values for Optifine
#define DoF_Strength 90					//[60 70 80 90 100 110 120 130 140 150]
#define Dof_Distance_View 256			//[128 256 384 512]
#define MB_strength 0.014				//[0.008 0.014 0.020]
#define Colorboost 0.2					//[0.04 0.2 0.35] //0.02 = Old color boost off. 0.2 = default (recommended). 0.35 = old color boost on
/*----------------------------*/	
varying vec2 texcoord;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D composite;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
bool hand = texture2D(gaux3, texcoord.xy).x < 0.005;
float depth0 = texture2D(depthtex0, texcoord).x;
float depth1 = texture2D(depthtex1, texcoord).x;
uniform int isEyeInWater;

uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

#ifdef Depth_of_Field
//Dof constant values
const float focal = 0.024;
float aperture = 0.008;	
const float sizemult = DoF_Strength;

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

	//hexagon pattern
	const vec2 hex_offsets[60] = vec2[60] (	vec2(  0.2165,  0.1250 ),
											vec2(  0.0000,  0.2500 ),
											vec2( -0.2165,  0.1250 ),
											vec2( -0.2165, -0.1250 ),
											vec2( -0.0000, -0.2500 ),
											vec2(  0.2165, -0.1250 ),
											vec2(  0.4330,  0.2500 ),
											vec2(  0.0000,  0.5000 ),
											vec2( -0.4330,  0.2500 ),
											vec2( -0.4330, -0.2500 ),
											vec2( -0.0000, -0.5000 ),
											vec2(  0.4330, -0.2500 ),
											vec2(  0.6495,  0.3750 ),
											vec2(  0.0000,  0.7500 ),
											vec2( -0.6495,  0.3750 ),
											vec2( -0.6495, -0.3750 ),
											vec2( -0.0000, -0.7500 ),
											vec2(  0.6495, -0.3750 ),
											vec2(  0.8660,  0.5000 ),
											vec2(  0.0000,  1.0000 ),
											vec2( -0.8660,  0.5000 ),
											vec2( -0.8660, -0.5000 ),
											vec2( -0.0000, -1.0000 ),
											vec2(  0.8660, -0.5000 ),
											vec2(  0.2163,  0.3754 ),
											vec2( -0.2170,  0.3750 ),
											vec2( -0.4333, -0.0004 ),
											vec2( -0.2163, -0.3754 ),
											vec2(  0.2170, -0.3750 ),
											vec2(  0.4333,  0.0004 ),
											vec2(  0.4328,  0.5004 ),
											vec2( -0.2170,  0.6250 ),
											vec2( -0.6498,  0.1246 ),
											vec2( -0.4328, -0.5004 ),
											vec2(  0.2170, -0.6250 ),
											vec2(  0.6498, -0.1246 ),
											vec2(  0.6493,  0.6254 ),
											vec2( -0.2170,  0.8750 ),
											vec2( -0.8663,  0.2496 ),
											vec2( -0.6493, -0.6254 ),
											vec2(  0.2170, -0.8750 ),
											vec2(  0.8663, -0.2496 ),
											vec2(  0.2160,  0.6259 ),
											vec2( -0.4340,  0.5000 ),
											vec2( -0.6500, -0.1259 ),
											vec2( -0.2160, -0.6259 ),
											vec2(  0.4340, -0.5000 ),
											vec2(  0.6500,  0.1259 ),
											vec2(  0.4325,  0.7509 ),
											vec2( -0.4340,  0.7500 ),
											vec2( -0.8665, -0.0009 ),
											vec2( -0.4325, -0.7509 ),
											vec2(  0.4340, -0.7500 ),
											vec2(  0.8665,  0.0009 ),
											vec2(  0.2158,  0.8763 ),
											vec2( -0.6510,  0.6250 ),
											vec2( -0.8668, -0.2513 ),
											vec2( -0.2158, -0.8763 ),
											vec2(  0.6510, -0.6250 ),
											vec2(  0.8668,  0.2513 ));								
#endif

vec3 Uncharted2Tonemap(vec3 x) {
	float A = 0.25;		
	float B = 0.29;		
	float C = 0.10;
	float D = Colorboost;
	float E = 0.03;
	float F = 0.35;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

void main() {

	vec3 color = texture2D(composite, texcoord.xy).rgb*50.0;
	vec3 blur = texture2D(gaux4, texcoord.xy/4.0).rgb;

#ifdef Depth_of_Field
	float pw = 1.0/ viewWidth;
	float z = ld(texture2D(depthtex0, texcoord.st).r)*far;
	float focus = ld(texture2D(depthtex0, vec2(0.5)).r)*far;
	float pcoc = min(abs(aperture * (focal * (z - focus)) / (z * (focus - focal)))*sizemult,pw*15.0);
#ifdef Distance_Blur
	float getdist = 1-(exp(-pow(ld(texture2D(depthtex1, texcoord.st).r)/Dof_Distance_View*far,4.0-(2.7*rainStrength))*4.0));	
	if(depth0 < depth1 || hand || depth1 < 1.0-near/far/far)pcoc = min(getdist*pw*20.0,pw*20.0);
#endif
	vec3 bcolor = vec3(0.0);
		for ( int i = 0; i < 60; i++) {
			bcolor += texture2D(composite, texcoord.xy + hex_offsets[i]*pcoc*vec2(1.0,aspectRatio)).rgb;
			}
		color.rgb = bcolor/61.0*50.0;

#endif
if(depth0 < depth1 || hand){
#ifdef Motionblur
	vec4 currentPosition = vec4(texcoord, depth1, 1.0)*2.0-1.0;
	
	vec4 fragposition = gbufferProjectionInverse * currentPosition;
		 fragposition = gbufferModelViewInverse * fragposition;
		 fragposition /= fragposition.w;
		 fragposition.xyz += cameraPosition;
	
	vec4 previousPosition = fragposition;
		 previousPosition.xyz -= previousCameraPosition;
		 previousPosition = gbufferPreviousModelView * previousPosition;
		 previousPosition = gbufferPreviousProjection * previousPosition;
		 previousPosition /= previousPosition.w;

	vec2 velocity = (currentPosition - previousPosition).st * MB_strength;
	vec2 coord = texcoord.st + velocity;

	vec3 mcolor = vec3(0.0);
	for (int i = 0; i < 15; ++i, coord += velocity) {
		mcolor += texture2D(composite, coord).xyz;
	}
		color = mcolor*3.4;
#endif
}
	color.rgb += blur;
	vec3 curr = Uncharted2Tonemap(color*4.7);
	color = pow(curr/Uncharted2Tonemap(vec3(15.0)),vec3(0.454));

	gl_FragColor = vec4(color,1.0);
}

#version 120
/*
                            _____ _____ ___________
                           /  ___|_   _|  _  | ___ \
                           \ `--.  | | | | | | |_/ /
                            `--. \ | | | | | |  __/
                           /\__/ / | | \ \_/ / |
                           \____/  \_/  \___/\_|

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

#define WAVING_LEAVES
#define WAVING_VINES
#define WAVING_GRASS
#define WAVING_FIRE
#define WAVING_LAVA
#define WAVING_WATER
#define WAVING_LILYPAD
#define WAVING_ENTITIES		//Saplings, small flowers, wheat, carrots, potatoes

/*---------------------------
//END OF ADJUSTABLE VARIABLES//
----------------------------*/

//Moving entities IDs
#define ENTITY_LEAVES        18.0
#define ENTITY_VINES        106.0
#define ENTITY_TALLGRASS     31.0
#define ENTITY_DANDELION     37.0
#define ENTITY_ROSE          38.0
#define ENTITY_WHEAT         59.0
#define ENTITY_LILYPAD      111.0
#define ENTITY_FIRE          51.0
#define ENTITY_LAVAFLOWING   10.0
#define ENTITY_LAVASTILL     11.0

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

attribute vec4 mc_Entity;
uniform float frameTimeCounter;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

const float PI = 3.141592653589793;
const float PI48 = 150.796447372;
float pi2wt = PI48*frameTimeCounter;

vec3 calcWave(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {
    vec3 ret;
    float magnitude,d0,d1,d2,d3;
    magnitude = sin(pi2wt*fm + pos.x*0.5 + pos.z*0.5 + pos.y*0.5) * mm + ma;
    d0 = sin(pi2wt*f0);
    d1 = sin(pi2wt*f1);
    d2 = sin(pi2wt*f2);
    ret.x = sin(pi2wt*f3 + d0 + d1 - pos.x + pos.z + pos.y) * magnitude;
    ret.z = sin(pi2wt*f4 + d1 + d2 + pos.x - pos.z + pos.y) * magnitude;
	ret.y = sin(pi2wt*f5 + d2 + d0 + pos.z + pos.y - pos.y) * magnitude;
    return ret;
}

vec3 calcMove(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWave(pos      , 0.0027, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
	vec3 move2 = calcWave(pos+move1, 0.0348, 0.0400, 0.0400, f0, f1, f2, f3, f4, f5) * amp2;
    return move1+move2;
}
void main() {

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	bool istopv = gl_MultiTexCoord0.t < gl_MultiTexCoord3.t;

	/* un-rotate */
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec3 worldpos = position.xyz + cameraPosition;

	//Waving entities
	if (istopv) {
	#ifdef WAVING_GRASS
	if ( mc_Entity.x == ENTITY_TALLGRASS)
			position.xyz += calcMove(worldpos.xyz,
				0.0041,
				0.0070,
				0.0044,
				0.0038,
				0.0063,
				0.0000,
				vec3(3.0,1.6,3.0),
				vec3(0.0,0.0,0.0));
	#endif
	#ifdef WAVING_ENTITIES
	if ( mc_Entity.x == ENTITY_WHEAT || mc_Entity.x == 6.0 || mc_Entity.x == ENTITY_DANDELION || mc_Entity.x == ENTITY_ROSE || mc_Entity.x == 141.0 || mc_Entity.x == 142.0)
			position.xyz += calcMove(worldpos.xyz,
			0.0041,
			0.0070,
			0.0044,
			0.0038,
			0.0240,
			0.0000,
			vec3(0.8,0.0,0.8),
			vec3(0.4,0.0,0.4));
	#endif
	#ifdef WAVING_FIRE
	if ( mc_Entity.x == ENTITY_FIRE)
			position.xyz += calcMove(worldpos.xyz,
			0.0105,
			0.0096,
			0.0087,
			0.0063,
			0.0097,
			0.0156,
			vec3(1.2,0.4,1.2),
			vec3(0.8,0.8,0.8));
	#endif
	}
	#ifdef WAVING_LEAVES
	if ( mc_Entity.x == ENTITY_LEAVES || mc_Entity.x == 161.0)
			position.xyz += calcMove(worldpos.xyz,
			0.0040,
			0.0064,
			0.0043,
			0.0035,
			0.0037,
			0.0041,
			vec3(1.0,0.2,1.0),
			vec3(0.5,0.1,0.5));
	#endif
	#ifdef WAVING_VINES
	if ( mc_Entity.x == ENTITY_VINES )
			position.xyz += calcMove(worldpos.xyz,
			0.0040,
			0.0064,
			0.0043,
			0.0035,
			0.0037,
			0.0041,
			vec3(0.5,1.0,0.5),
			vec3(0.25,0.5,0.25));
	#endif
	#ifdef WAVING_LAVA
	if(mc_Entity.x == ENTITY_LAVAFLOWING || mc_Entity.x == ENTITY_LAVASTILL){
		float l_fy = fract(worldpos.y + 0.001);
		float l_wave = 0.05 * sin(2 * PI * (frameTimeCounter*0.2 + worldpos.x /  7.0 + worldpos.z / 13.0))
				   + 0.05 * sin(2 * PI * (frameTimeCounter*0.15 + worldpos.x / 11.0 + worldpos.z /  5.0));
		float l_displacement = clamp(l_wave, -l_fy, 1.0-l_fy);
		position.y += l_displacement*0.5;
	}
	#endif
	#ifdef WAVING_WATER
	if(mc_Entity.x == 8 || mc_Entity.x == 9){
		float w_fy = fract(worldpos.y + 0.001);
		float w_wave = 0.05 * sin(2 * PI * (frameTimeCounter*0.4 + worldpos.x /  7.0 + worldpos.z / 13.0))
				   + 0.05 * sin(2 * PI * (frameTimeCounter*0.3 + worldpos.x / 11.0 + worldpos.z /  5.0));
		float w_displacement = clamp(w_wave, -w_fy, 1.0-w_fy);
		position.y += w_displacement*0.5;
	}
	#endif
	//----------------------------------

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	//Fog
	float distance = sqrt(position.x * position.x + position.y * position.y + position.z * position.z);
	gl_FogFragCoord = distance;

	color = gl_Color;
}

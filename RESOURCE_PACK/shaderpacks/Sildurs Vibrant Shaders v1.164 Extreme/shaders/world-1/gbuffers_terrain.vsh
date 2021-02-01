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

//#define POM				//Parallax mapping, must also be enabled/disabled in gbuffers_terrain.fsh (fragment)

#define Waving_Leaves
#define Waving_Vines
#define Waving_Grass		//Does not include tallgrass due some issues with it.
#define Waving_Fire
#define Waving_Lava
#define Waving_Lilypads
#define Waving_Entities		//Includes: Saplings, small flowers, wheat, carrots, potatoes and beetroot.

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

varying vec4 normal;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;
const float PI = 3.1415927;
const float PI48 = 150.796447372;
float pi2wt = PI48*frameTimeCounter;

#ifdef POM
attribute vec4 at_tangent;                      //xyz = tangent vector, w = handedness, added in 1.7.10
varying float dist;
varying vec3 viewVector;
varying mat3 tbnMatrix;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;
#endif

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

/* If you reached this line, then you're probably about to break the agreement which you accepted by downloading Sildur's shaders!
So stop your doing and ask Sildur before copying anything which would break the agreement, unless you're Chocapic then go ahead ;)
--------------------------------------------------------------------------------------------------------------------------------*/

void main() {

	//Unpack material
	normal.a = 0.02;
	
	//Positioning
	normal.xyz = normalize(gl_NormalMatrix * gl_Normal);
	texcoord = vec4((gl_MultiTexCoord0).xy,(gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
	
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec3 worldpos = position.xyz + cameraPosition;
	bool istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t;

if (istopv) {
	#ifdef Waving_Grass
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
	#ifdef Waving_Entities
	if ( mc_Entity.x == ENTITY_WHEAT || mc_Entity.x == 6.0 || mc_Entity.x == ENTITY_DANDELION || mc_Entity.x == ENTITY_ROSE || mc_Entity.x == 141.0 || mc_Entity.x == 142.0 || mc_Entity.x == 207.0)
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
	#ifdef Waving_Fire
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

	#ifdef Waving_Leaves
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
	#ifdef Waving_Vines
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

	#ifdef Waving_Lava
	if(mc_Entity.x == ENTITY_LAVAFLOWING || mc_Entity.x == ENTITY_LAVASTILL){
		float fy = fract(worldpos.y + 0.001);
		float wave = 0.05 * sin(2 * PI * (frameTimeCounter*0.2 + worldpos.x /  7.0 + worldpos.z / 13.0))
				   + 0.05 * sin(2 * PI * (frameTimeCounter*0.15 + worldpos.x / 11.0 + worldpos.z /  5.0));
		position.y += clamp(wave, -fy, 1.0-fy)*0.5;
	}
	#endif
	
	#ifdef Waving_Lilypads
	if(mc_Entity.x == 111.0){
	float fy = fract(worldpos.y + 0.001);
	float wave = 0.05 * sin(2 * PI * (frameTimeCounter*0.75 + worldpos.x /  7.0 + worldpos.z / 13.0))
			   + 0.05 * sin(2 * PI * (frameTimeCounter*0.6 + worldpos.x / 11.0 + worldpos.z /  5.0));
	position.y += clamp(wave, -fy, 1.0-fy)*1.0-0.11;
	}
	#endif
	
	color = gl_Color;

	//Fix colors on emissive blocks
	if (mc_Entity.x == 50.0
	|| mc_Entity.x == 51.0
	|| mc_Entity.x == 10.0
	|| mc_Entity.x == 11.0
	|| mc_Entity.x == 62.0
	|| mc_Entity.x == 76.0
	|| mc_Entity.x == 91.0
	|| mc_Entity.x == 89.0
	|| mc_Entity.x == 124.0
	|| mc_Entity.x == 138.0){
	normal.a = 0.6;	
	color = vec4(1.0);
	}

	//Translucent blocks
	if (mc_Entity.x == ENTITY_VINES
	|| mc_Entity.x == ENTITY_DANDELION
	|| mc_Entity.x == ENTITY_ROSE
	|| mc_Entity.x == ENTITY_WHEAT
	|| mc_Entity.x == 207.0 //beetroot
	|| mc_Entity.x == 30.0
	|| mc_Entity.x == 31.0
	|| mc_Entity.x == 175.0
	|| mc_Entity.x == 115.0
	|| mc_Entity.x == 32.0
	|| mc_Entity.x == 141.0
	|| mc_Entity.x == 142.0
	|| mc_Entity.x == ENTITY_LILYPAD
	|| mc_Entity.x == ENTITY_LAVAFLOWING
	|| mc_Entity.x == ENTITY_LAVASTILL
	|| mc_Entity.x == ENTITY_LEAVES  
	|| mc_Entity.x == 161.0		//1.8+ Leaves
	|| mc_Entity.x == ENTITY_TALLGRASS
	|| mc_Entity.x == 6.0){
	normal.a = 0.7;
	}

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	#ifdef POM
	vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.xy-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid)*2;
	vtexcoordam.st  = min(texcoord.xy ,midcoord-texcoordminusmid);
	vtexcoord.xy    = sign(texcoordminusmid)*0.5+0.5;
	
	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	
	tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
					 tangent.y, binormal.y, normal.y,
					 tangent.z, binormal.z, normal.z);
	
	viewVector = normalize(tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz);
	
	dist = length(gl_ModelViewMatrix * gl_Vertex);
	#endif
}
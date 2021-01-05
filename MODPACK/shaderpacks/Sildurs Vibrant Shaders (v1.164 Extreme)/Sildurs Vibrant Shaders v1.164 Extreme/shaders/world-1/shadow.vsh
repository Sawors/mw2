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

#define SHADOW_MAP_BIAS 0.80
varying vec4 texcoord;
varying float istransparent;

attribute vec4 mc_Entity;

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;

vec4 BiasShadowProjection(in vec4 projectedShadowSpacePosition) {
	vec2 pos = abs(projectedShadowSpacePosition.xy * 1.165);
	float dist = pow(pow(pos.x, 12.) + pow(pos.y, 12.), 0.0833);

	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	
	projectedShadowSpacePosition.xy /= distortFactor*0.97;
	projectedShadowSpacePosition.z /= 2.5;

	return projectedShadowSpacePosition;
}

void main() {

	vec4 position = ftransform();
		 position = shadowProjectionInverse * position;
		 position = shadowModelViewInverse * position;
		 position = shadowModelView * position;
		 position = shadowProjection * position;
	
	gl_Position = BiasShadowProjection(position);

	texcoord = gl_MultiTexCoord0;
	
	gl_FrontColor = gl_Color;

	texcoord.z = 1.0;
	if(mc_Entity.x == 8.0 || mc_Entity.x == 9.0) texcoord.z = 0.0;

	istransparent = 0.0;
	if(mc_Entity.x == 95.0 || mc_Entity.x == 160.0 || mc_Entity.x == 165.0) istransparent = 1.0;
}

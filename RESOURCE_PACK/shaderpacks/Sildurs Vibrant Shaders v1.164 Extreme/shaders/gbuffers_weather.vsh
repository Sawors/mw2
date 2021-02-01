#version 120
/*
                            _____ _____ ___________
                           /  ___|_   _|  _  | ___ \
                           \ `--.  | | | | | | |_/ /
                            `--. \ | | | | | |  __/
                           /\__/ / | | \ \_/ / |
                           \____/  \_/  \___/\_|
This code is from Chocapic13' shaders v6.2, modified, tweaked and changed by Sildur for vibrant shaders v1.15 and newer.
						Before editing anything here make sure you've
						read The agreement, which you accepted by downloading
						my shaderpack. The agreement can be found here:
			http://www.minecraftforum.net/topic/1953873-164-172-sildurs-shaders-pcmacintel/

*/

#define WeatherAngle			//Toggle alternative weather angler

varying vec4 color;

varying vec2 texcoord;
varying float lmcoord;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

void main() {

#ifdef WeatherAngle
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	float worldpos = position.y + cameraPosition.y;
	bool istopv = worldpos > cameraPosition.y+5.0;
	if (!istopv) position.xz += vec2(3.0,1.0);
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
#else
	gl_Position = ftransform();
#endif
	
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).s;
	color = gl_Color;

}

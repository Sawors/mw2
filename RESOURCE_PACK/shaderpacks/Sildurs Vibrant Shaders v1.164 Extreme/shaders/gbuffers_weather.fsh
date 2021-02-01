#version 120
/* DRAWBUFFERS:7 */
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

varying vec4 color;

varying vec2 texcoord;
varying float lmcoord;

uniform sampler2D texture;

void main() {

	vec4 tex = texture2D(texture, texcoord.xy)*color;

	gl_FragData[0] = vec4(vec3(1.0,lmcoord,1.0),tex.a*length(tex.rgb)/sqrt(3.0));
}

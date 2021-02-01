#version 120
/* DRAWBUFFERS:7 */
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

#define Bloom					//Also disables sun glare
#define bloom_strength 0.75		//Adjust bloom strength [0.5 0.75 1.0 2.0]
/*--------------------------------*/
varying vec2 texcoord;

uniform sampler2D gaux4;

uniform int isEyeInWater;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;
/*--------------------------------*/

void main() {

#ifdef Bloom
	const int nSteps = 17;
	const int center = 8;		//=nSteps-1 / 2

	//huge gaussian blur for glare
	vec3 blur = vec3(0.0);
	float tw = 0.0;
	for (int i = 0; i < nSteps; i++) {
		float dist = abs(i-float(center))/center;
		float weight = (exp(-(dist*dist)/ 0.28));

		vec3 bsample = texture2D(gaux4,(texcoord.xy + vec2(pw,ph)*vec2(0.0,i-center))).rgb*3.0;

		blur += bsample*weight;
		tw += weight;
	}
	blur /= tw;

	vec3 glow = blur * bloom_strength;
	vec3 overglow = glow*pow(length(glow)*2.0,2.8)*2.0;

	vec3 finalColor = (overglow+glow*1.15)*(1+isEyeInWater*5.0+(pow(rainStrength,3.0)*7.0/pow(10.0,1.0)))*1.2;

	gl_FragData[0] = vec4(finalColor, 1.0);
#else
	gl_FragData[0] = vec4(0.0);
#endif
}

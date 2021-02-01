#version 120
const bool gaux1MipmapEnabled = true;
/* DRAWBUFFERS:3 */
/*
                            _____ _____ ___________
                           /  ___|_   _|  _  | ___ \
                           \ `--.  | | | | | | |_/ /
                            `--. \ | | | | | |  __/
                           /\__/ / | | \ \_/ / |
                           \____/  \_/  \___/\_|
						Sildur's vibrant shaders 1.16 and newer
						Before editing anything here make sure you've
						read The agreement, which you accepted by downloading
						my shaderpack. The agreement can be found here:
			http://www.minecraftforum.net/topic/1953873-164-172-sildurs-shaders-pcmacintel/

*/

varying vec2 texcoord;

uniform sampler2D composite;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform int worldTime;
uniform float near;
uniform float far;

/*------------------------------------------*/
float comp = 1.0-near/far/far;
float tmult = mix(min(abs(worldTime-6000.0)/6000.0,1.0),1.0,0.0);

float getAirDensity (float h) {
	return max(h/10.,6.0);
}

float calcFog(vec3 fposition) {
	const float density = 50.0;

	vec3 worldpos = (gbufferModelViewInverse*vec4(fposition,1.0)).rgb+cameraPosition;
	float height = mix(getAirDensity(worldpos.y),6.0,0.0);
	float d = length(fposition);

	return clamp(0.75/exp(-6.0/density)*exp(-getAirDensity(cameraPosition.y)/density) * (1.0-exp( -pow(d,2.712)*height/density/(6000.0-tmult*tmult*2000.0)/13.0))/height,0.0,1.0);
}/*---------------------------------*/

/* If you reached this line, then you're probably about to break the agreement which you accepted by downloading Sildur's shaders!
So stop your doing and ask Sildur before copying anything which would break the agreement, unless you're Chocapic then go ahead ;)
--------------------------------------------------------------------------------------------------------------------------------*/

void main() {

vec3 c = pow(texture2D(gaux1,texcoord).xyz,vec3(2.2))*257.;

//Depth and fragpos
float depth0 = texture2D(depthtex0, texcoord).x;
float depth1 = texture2D(depthtex1, texcoord).x;
vec4 fragpos1 = gbufferProjectionInverse * (vec4(texcoord, depth1, 1.0) * 2.0 - 1.0);
	 fragpos1 /= fragpos1.w;
/*--------------------------------------------------------------------------------------------*/

if (depth0 > comp){
	c.r = 0.0025; //draw nether sky
}

//Land
if (depth0 < comp){
vec4 trp = texture2D(gaux3,texcoord.xy);
bool transparency = dot(trp.xyz,trp.xyz) > 0.000001;
if (transparency) {
	//Draw transparency
	vec3 finalAc = texture2D(gaux2, texcoord.xy).rgb;
	float alphaT = clamp(length(trp.rgb)*1.02,0.0,1.0);

	c = mix(c,c*(trp.rgb*0.9999+0.0001)*sqrt(3.0),alphaT)*(1.0-alphaT) + finalAc;
	/*-----------------------------------------------------------------------------*/
  }
	//Draw land fog
	vec3 fogColor = vec3(0.05, 0.0, 0.0);
	float fogLand = calcFog(fragpos1.xyz);
	c = mix(c, fogColor, fogLand);
}

	c = c/50.0*pow(10.0,0.88);

	gl_FragData[0] = vec4(c,1.0);
}

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

*/

#define Waving_Water

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 ambientNdotL;
varying vec3 sunlight;
varying float skyL;
varying vec4 vposition;
varying vec3 vworldpos;
varying vec3 VertexModelView;

varying vec3 normal;
varying mat3 tbnMatrix;
varying float NdotL;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;                      //xyz = tangent vector, w = handedness, added in 1.7.10

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform int worldTime;
uniform float frameTimeCounter;
const float PI = 3.1415927;
uniform float rainStrength;

const vec3 ToD[7] = vec3[7](  vec3(0.58597,0.16,0.005),
								vec3(0.58597,0.31,0.05),
								vec3(0.58597,0.45,0.16),
								vec3(0.58597,0.5,0.35),
								vec3(0.58597,0.5,0.36),
								vec3(0.58597,0.5,0.37),
								vec3(0.58597,0.5,0.38));
								
void main() {

	normal = normalize(gl_NormalMatrix * gl_Normal);
	vposition = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vworldpos = vposition.xyz + cameraPosition;

	ambientNdotL.a = 0.0;	//iswater
	if(mc_Entity.x == 8.0 || mc_Entity.x == 9.0) { //water
		ambientNdotL.a = 1.0;
		
		#ifdef Waving_Water
		float fy = fract(vworldpos.y + 0.001);
		float wave = 0.05 * sin(2 * PI * (frameTimeCounter*0.75 + vworldpos.x /  7.0 + vworldpos.z / 13.0))
				   + 0.05 * sin(2 * PI * (frameTimeCounter*0.6 + vworldpos.x / 11.0 + vworldpos.z /  5.0));
		vposition.y += clamp(wave, -fy, 1.0-fy)*0.8-0.01;
		#endif
	}
	if(mc_Entity.x == 79.0) ambientNdotL.a = 0.5; //ice
	/*------------------------------------------------*/
	
	color = gl_Color;
	gl_Position = gl_ProjectionMatrix * gbufferModelView * vposition;
	
	texcoord = (gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	/*---------------------------------------------*/
	
	//reduced the sun color to a 7 array
	float hour = max(mod(worldTime/1000.0+2.0,24.0)-2.0,0.0);  //-0.1
	float cmpH = max(-abs(floor(hour)-6.0)+6.0,0.0); //12
	float cmpH1 = max(-abs(floor(hour)-5.0)+6.0,0.0); //1
	vec3 temp = ToD[int(cmpH)];
	vec3 temp2 = ToD[int(cmpH1)];
	
	//Colors
	sunlight = mix(temp,temp2,fract(hour));
	const vec3 rainC = vec3(0.01,0.01,0.01);
	sunlight = mix(sunlight,rainC*sunlight,rainStrength);
	
	vec3 sunVec = normalize(sunPosition);
	vec3 upVec = normalize(upPosition);
	
	vec2 visibility = vec2(dot(sunVec,upVec),dot(-sunVec,upVec));
		 visibility = pow(clamp(visibility+0.15,0.0,0.15)/0.15,vec2(4.0));	

	NdotL = dot(normal,sunVec);
	float NdotU = dot(normal,upVec);

	vec2 trCalc = min(abs(worldTime-vec2(23250.0,12700.0)),750.0);
	float tr = max(min(trCalc.x,trCalc.y)/375.0-1.0,0.0);
	
	//fix colors on translucent blocks near lightsources
	float torch_lightmap = 16.0-min(15.,(lmcoord.s-0.5/16.)*16.*16./15);
	float fallof1 = clamp(1.0 - pow(torch_lightmap/16.0,4.0),0.0,1.0);
	torch_lightmap = fallof1*fallof1/(torch_lightmap*torch_lightmap+1.0);
	vec3 emissiveLightC = vec3(1.0,0.42,0.045)*torch_lightmap*0.66;
	if(mc_Entity.x == 8.0 || mc_Entity.x == 9.0) emissiveLightC *= 0.0;
	
	skyL = max(lmcoord.t-2./16.0,0.0)*1.14285714286;
	float SkyL2 = skyL*skyL;
	float skyc2 = mix(1.0,SkyL2,skyL);

	vec4 bounced = vec4(NdotL,NdotL,NdotL,NdotU) * vec4(-0.14*skyL*skyL,0.33,0.7,0.1) + vec4(0.6,0.66,0.7,0.25);
	bounced *= vec4(skyc2,skyc2,visibility.x-tr*visibility.x,0.8);

	vec3 sun_ambient = bounced.w * (vec3(0.1, 0.5, 1.1)*2.4+rainStrength*2.3*vec3(0.05,-0.33,-0.9))+ 1.6*sunlight*(sqrt(bounced.w)*bounced.x*2.4 + bounced.z)*(1.0-rainStrength*0.99);
	const vec3 moonlight = vec3(0.0024, 0.00432, 0.0078);	
	vec3 moon_ambient = (moonlight*0.7 + moonlight*bounced.y)*(4.0-rainStrength*0.95)*0.2;

	vec3 amb1 = (sun_ambient*visibility.x + moon_ambient*visibility.y)*SkyL2*(0.03*0.65+tr*0.17*0.65);
	ambientNdotL.rgb =  amb1 + emissiveLightC + 0.003*min(skyL+6/16.,9/16.)*normalize(amb1+0.0001);

	sunlight = mix(sunlight,moonlight*(1.0-rainStrength*0.9),visibility.y)*tr;

	NdotL = (worldTime > 12700 && worldTime < 23250)? -NdotL : NdotL;
	
	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	vec3 binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
					 tangent.y, binormal.y, normal.y,
					 tangent.z, binormal.z, normal.z);
	
	VertexModelView = normalize(tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz);
}
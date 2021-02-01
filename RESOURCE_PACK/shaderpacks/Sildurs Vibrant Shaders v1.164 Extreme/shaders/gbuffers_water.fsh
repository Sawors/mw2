#version 120
/* DRAWBUFFERS:526 */
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
#define SHADOW_MAP_BIAS 0.80
const float shadowMapResolution = 3072;		//set to same as main shadowres [512 1024 2048 3072 4096 8192]

#define WaterParallax

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

uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2DShadow shadow;

uniform float frameTimeCounter;
uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D noisetex;
float noisetexture(vec2 coord, float offset, float speed){
return texture2D(noisetex, fract((coord*0.0005)*offset + frameTimeCounter*speed)).x/offset;
}

float genWaves(vec2 pos){
	float wave = noisetexture(pos, 0.5, 0.00225);
		  wave -= noisetexture(pos, 0.5, -0.00225);
		  wave += noisetexture(pos, 2.0, 0.003375);
		  wave -= noisetexture(pos, 2.0, -0.003375);
#ifndef WaterParallax	
		  wave += noisetexture(pos, 3.5, 0.0045);
		  wave -= noisetexture(pos, 3.5, -0.0045);
#endif
	return wave;
}

vec3 calcBump(vec2 pos){
	const vec2 deltaPos = vec2(0.3, 0.0);
	float h0 = genWaves(pos);
	float h1 = genWaves(pos + deltaPos.xy);
	float h2 = genWaves(pos - deltaPos.xy);
	float h3 = genWaves(pos + deltaPos.yx);
	float h4 = genWaves(pos - deltaPos.yx);

	float xDelta = ((h1-h0)+(h0-h2));
	float yDelta = ((h3-h0)+(h0-h4));
#ifndef WaterParallax
	return vec3(vec2(xDelta,yDelta)*0.14, 0.86f); //z = 1.0-0.14
#else	
	return vec3(vec2(xDelta,yDelta)*0.16, 0.84f); //z = 1.0-0.16
#endif	
}

#ifdef WaterParallax
vec2 calcParallax(vec2 pos) {
	for (int i = 0; i < 6; i++) {
		pos += VertexModelView.xy * genWaves(pos);
	}
	return pos;
}
#endif

vec4 encode (vec3 n,float dif){
    float p = sqrt(n.z*8+8);
	
	float vis = lmcoord.t;
	if (ambientNdotL.a > 0.9) vis = vis / 4.0;
	if (ambientNdotL.a > 0.4 && ambientNdotL.a < 0.6) vis = vis/4.0+0.25;
	if (ambientNdotL.a < 0.1) vis = vis/4.0+0.5;	
	
    return vec4(n.xy/p + 0.5,vis,1.0);
}

void main() {

	float iswater = ambientNdotL.a;
	float diffuse = NdotL;

	vec4 albedo = texture2D(texture, texcoord.xy)*color;
		 albedo.rgb = pow(albedo.rgb,vec3(2.2));
	
//only apply shading to blocks with a lower alpha than 1.0 (=transparent)
if (albedo.a < 1.0 && diffuse > 0.0 && iswater < 0.9){
	vec4 worldposition = vposition;
		 worldposition = shadowModelView * worldposition;
		 worldposition = shadowProjection * worldposition;
	vec2 pos = pow(abs(worldposition.xy * 1.165), vec2(12.0));
	float dist = pow(pos.x + pos.y, 0.0833);
	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	worldposition.xy /= distortFactor*0.97; 

	if (max(abs(worldposition.x),abs(worldposition.y)) < 0.99) {
		const float diffthresh = 0.0004;
		worldposition = worldposition * vec4(0.5,0.5,0.2,0.5) + vec4(0.5,0.5,0.5-diffthresh,0.5);
	
		//Fast and simple shadow drawing for proper rendering of translucent blocks
		diffuse *= shadow2D(shadow,vec3(worldposition.st, worldposition.z)).x;
	}
	diffuse *= mix(skyL,1.0,clamp((eyeBrightnessSmooth.y/255.0-2.0/16.)*4.0,0.0,1.0)); //avoid light leaking underground
}

vec3 newnormal = normal;
if (iswater > 0.9){
	albedo.rgb = mix(albedo.rgb,vec3(0.5, 1.5, 2.0),0.7);
	
	vec2 waterpos = vworldpos.xz*7.0;
#ifdef WaterParallax
	waterpos = calcParallax(waterpos);
#endif	
	//Bump mapping
	newnormal = normalize(calcBump(waterpos) * tbnMatrix);
}

	vec3 sunlightC = (1.0-iswater)*sunlight.rgb*clamp(diffuse,0.0,1.0);
	vec3 finalColor = albedo.rgb*(sunlightC+ambientNdotL.rgb);
	float alpha = mix(albedo.a,0.11,max(iswater*2.0-1.0,0.0));

	gl_FragData[0] = vec4(finalColor, alpha);
	gl_FragData[1] = encode(newnormal.xyz, diffuse);
	gl_FragData[2] = vec4(normalize(albedo.rgb+0.00001), alpha);
}
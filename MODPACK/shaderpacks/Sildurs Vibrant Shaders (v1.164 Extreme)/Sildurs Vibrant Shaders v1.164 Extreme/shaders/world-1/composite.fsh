#version 120
/* DRAWBUFFERS:34 */
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

*/
/*--------------------
//ADJUSTABLE VARIABLES//
---------------------*/
const int shadowMapResolution = 3072;		//Shadows resolution. [512 1024 2048 3072 4096 8192]
const float shadowDistance = 120.0;			//Draw distance of shadows.[60.0 90.0 120.0 150.0 180.0 210.0]

#define SSDO								//Ambient Occlusion, makes lighting more realistic. High performance impact.

//#define Celshading						//Cel shades everything, making it look somewhat like Borderlands. Zero performance impact.
	#define BORDER 1.0

//#define Whiteworld						//Makes the ground white, screenshot -> https://i.imgur.com/xziUB8O.png
/*---------------------------
//END OF ADJUSTABLE VARIABLES//
----------------------------*/	

//Constants
const bool 	shadowHardwareFiltering0 = true;
const float	sunPathRotation	= -40.0f;

varying vec2 texcoord;

uniform sampler2D depthtex1;
uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D composite;

uniform mat4 gbufferProjectionInverse;

uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;

float comp = 1.0-near/far/far;			//distance above that are considered as sky

const vec2 check_offsets[25] = vec2[25](vec2(-0.4894566f,-0.3586783f),
									vec2(-0.1717194f,0.6272162f),
									vec2(-0.4709477f,-0.01774091f),
									vec2(-0.9910634f,0.03831699f),
									vec2(-0.2101292f,0.2034733f),
									vec2(-0.7889516f,-0.5671548f),
									vec2(-0.1037751f,-0.1583221f),
									vec2(-0.5728408f,0.3416965f),
									vec2(-0.1863332f,0.5697952f),
									vec2(0.3561834f,0.007138769f),
									vec2(0.2868255f,-0.5463203f),
									vec2(-0.4640967f,-0.8804076f),
									vec2(0.1969438f,0.6236954f),
									vec2(0.6999109f,0.6357007f),
									vec2(-0.3462536f,0.8966291f),
									vec2(0.172607f,0.2832828f),
									vec2(0.4149241f,0.8816f),
									vec2(0.136898f,-0.9716249f),
									vec2(-0.6272043f,0.6721309f),
									vec2(-0.8974028f,0.4271871f),
									vec2(0.5551881f,0.324069f),
									vec2(0.9487136f,0.2605085f),
									vec2(0.7140148f,-0.312601f),
									vec2(0.0440252f,0.9363738f),
									vec2(0.620311f,-0.6673451f)
									);


vec3 decode (vec2 enc){
    vec2 fenc = enc*4-2;
    float f = dot(fenc,fenc);
    float g = sqrt(1-f/4.0);
    vec3 n;
    n.xy = fenc*g;
    n.z = 1-f/2;
    return n;
}

vec3 YCoCg2RGB(vec3 c){
	c.y-=0.5;
	c.z-=0.5;
	return vec3(c.r+c.g-c.b, c.r + c.b, c.r - c.g - c.b);
}

#ifdef Celshading
float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

float edepth(vec2 coord) {
	return texture2D(depthtex1,coord).z;
}

vec3 celshade(vec3 clrr) {
	//edge detect
	float d = edepth(texcoord.xy);
	float dtresh = 1/(far-near)/5000.0;
	vec4 dc = vec4(d);
	vec4 sa;
	vec4 sb;
	sa.x = edepth(texcoord.xy + vec2(-pw,-ph));
	sa.y = edepth(texcoord.xy + vec2(pw,-ph));
	sa.z = edepth(texcoord.xy + vec2(-pw,0.0));
	sa.w = edepth(texcoord.xy + vec2(0.0,ph));

	//opposite side samples
	sb.x = edepth(texcoord.xy + vec2(pw,ph));
	sb.y = edepth(texcoord.xy + vec2(-pw,ph));
	sb.z = edepth(texcoord.xy + vec2(pw,0.0));
	sb.w = edepth(texcoord.xy + vec2(0.0,-ph));

	vec4 dd = abs(2.0* dc - sa*BORDER - sb*BORDER) - dtresh;
		 dd = step(dd.xyzw, vec4(0.0));

	float e = clamp(dot(dd,vec4(0.25f)),0.0,1.0);
	return clrr*e;
}
#endif

vec3 normalT = decode(texture2D(gdepth, texcoord).xy);

#ifdef SSDO
//modified version of Yuriy O'Donnell's SSDO (License MIT -> https://github.com/kayru/dssdo)
vec4 calcSSDO(vec3 fragpos){
	vec4 occlusion_sh2 = vec4(0.0);

	float radius = 0.06 / (fragpos.z);
	const float attenuation_angle_threshold = 0.2;
	const int num_samples = 25;	
	const float sh2_weight_l0 = 0.5*sqrt(0.31847133758);
	const vec3 sh2_weight_l1 = vec3(0.5)*sqrt(0.95541401273);
	const vec4 sh2_weight = vec4(sh2_weight_l1, sh2_weight_l0) / num_samples;

	for( int i=0; i<num_samples; ++i ){
	    vec2 texOffset = pow(length((check_offsets[i].xy)),0.5)*radius*vec2(1.0,aspectRatio)*normalize(check_offsets[i].xy);
		vec2 sample_tex = texcoord + texOffset;

		vec4 t0 = gbufferProjectionInverse*vec4(vec3(sample_tex,texture2D(depthtex1,sample_tex).x)*2.0-1.0,1.0);
		t0 /= t0.w;

		vec3 center_to_sample = t0.rgb - fragpos.rgb;

		float dist = length(center_to_sample);

		vec3 center_to_sample_normalized = center_to_sample / dist;
		float attenuation = 1.0-clamp(dist/6.0,0.0,1.0);
		float dp = dot(normalT, center_to_sample_normalized);

		attenuation = sqrt(max(dp,0.0))*attenuation*attenuation * step(attenuation_angle_threshold, dp);
		occlusion_sh2 += attenuation * sh2_weight*vec4(center_to_sample_normalized,1);
	}
	return occlusion_sh2;
}
#endif

void main() {

//sample half-resolution buffer with correct texture coordinates
vec4 hr = pow(texture2D(composite,(floor(gl_FragCoord.xy/2.)*2+1.0)/vec2(viewWidth,viewHeight)/2.0),vec4(2.2,2.2,2.2,1.0))*vec4(257.,257,257,1.0);

float Depth = texture2D(depthtex1, texcoord).x;
vec4 albedo = texture2D(gcolor,texcoord);
bool land = !(dot(albedo.rgb,vec3(1.0))<0.00000000001 || (Depth > comp));
bool translucent = albedo.b > 0.69 && albedo.b < 0.71;
bool emissive = albedo.b > 0.59 && albedo.b < 0.61;
vec3 color = vec3(albedo.rg,0.0);

if (land && dot(albedo.rgb,vec3(1.0))>0.00000000001){
vec2 a0 = texture2D(gcolor,texcoord + vec2(1.0/viewWidth,0.0)).rg;
vec2 a1 = texture2D(gcolor,texcoord - vec2(1.0/viewWidth,0.0)).rg;
vec2 a2 = texture2D(gcolor,texcoord + vec2(0.0,1.0/viewHeight)).rg;
vec2 a3 = texture2D(gcolor,texcoord - vec2(0.0,1.0/viewHeight)).rg;
vec4 lumas = vec4(a0.x,a1.x,a2.x,a3.x);
vec4 chromas = vec4(a0.y,a1.y,a2.y,a3.y);

const vec4 THRESH = vec4(30./255.);

vec4 w = 1.0-step(THRESH, abs(lumas - color.x));
float W = dot(w,vec4(1.0));
w.x = (W==0.0)? 1.0:w.x;  W = (W==0.0)? 1.0:W;

bool pattern = (mod(gl_FragCoord.x,2.0)==mod(gl_FragCoord.y,2.0));
color.b= dot(w,chromas)/W;
color.rgb = (pattern)?color.rbg:color.rgb;
color.rgb = YCoCg2RGB(color.rgb);
color = pow(color,vec3(2.2));

vec4 fragpos = gbufferProjectionInverse * (vec4(texcoord,Depth,1.0) * 2.0 - 1.0);
fragpos /= fragpos.w;

#ifdef Whiteworld
	color += vec3(1.5);
#endif

#ifdef Celshading
	color = celshade(color);
#endif

float ao = 1.0;
#ifdef SSDO
if (!translucent){
	float occlusion = calcSSDO(fragpos.xyz).a;
	ao = pow(1.0-occlusion, 3.0);
}
#endif
	
	//Emissive blocks lighting and colors
	float torch_lightmap = 16.0-min(15.,(texture2D(gdepth,texcoord).z-0.5/16.)*16.*16./15);
	float fallof1 = clamp(1.0 - pow(torch_lightmap/16.0,4.0),1.0,1.0);
	torch_lightmap = fallof1*fallof1/(torch_lightmap*torch_lightmap+1.0);
	float c_emitted = dot((color.rgb),vec3(1.0,0.6,0.4))/2.0;
	float emitted 		= emissive? clamp(c_emitted*c_emitted,0.0,1.0)*torch_lightmap : 0.0;
	vec3 emissiveLightC = vec3(1.5,0.42,0.045);
	/*------------------------------------------------------------------------------------------*/
	
	color *= emissiveLightC*(emitted*15.0*color + torch_lightmap*ao)*0.66;
}

//Draw sky (color)
if (!land)color = hr.rgb;
/*-------------------------*/

gl_FragData[1] = vec4(pow(color/257.0,vec3(0.454)), 0.0);
}

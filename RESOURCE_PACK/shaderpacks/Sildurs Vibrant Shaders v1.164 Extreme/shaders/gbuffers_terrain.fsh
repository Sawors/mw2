#version 120
/* DRAWBUFFERS:01 */
//Specular buffer 012

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
/*--------------------
//ADJUSTABLE VARIABLES//
---------------------*/

//#define POM				//Parallax mapping, must also be enabled/disabled in gbuffers_terrain.vsh (vertex)
#define POM_RES 64			//Texture / Resourcepack resolution. [64 128 256 512]

/*---------------------------
//END OF ADJUSTABLE VARIABLES//
----------------------------*/

/* Don't remove me
const int compositeFormat = RGBA16;
const int gaux2Format = RGBA16;
const int gaux3Format = RGBA16;		
const int gaux4Format = RGBA16;	

const int gcolorFormat = RGBA8;
const int gdepthFormat = RGBA16;
const int gnormalFormat = RGBA16;
const int compositeFormat = R11F_G11F_B10F;
const int gaux1Format = RGBA16;
const int gaux2Format = R11F_G11F_B10F;
const int gaux3Format = R11F_G11F_B10F;		
const int gaux4Format = R11F_G11F_B10F;	
-----------------------------------------*/

varying vec4 color;
varying vec4 texcoord;
varying vec4 normal;

uniform sampler2D texture;
//uniform sampler2D specular;

//encode normal in two channel (xy),torch and material(z) and sky lightmap (w)
vec4 encode (vec3 n){
    float p = sqrt(n.z*8+8);
    return vec4(n.xy/p + 0.5,texcoord.z,texcoord.w);
}

vec3 RGB2YCoCg(vec3 c){
		return vec3( 0.25*c.r+0.5*c.g+0.25*c.b, 0.5*c.r-0.5*c.b +0.5, -0.25*c.r+0.5*c.g-0.25*c.b +0.5);
}

#ifdef POM
#extension GL_ARB_shader_texture_lod : enable
#if POM_RES == 64
const vec3 pomDepth = vec3(0.015625, 0.015625, 0.10703125);
#endif
#if POM_RES == 128
const vec3 pomDepth = vec3(0.0078125, 0.0078125, 0.045703125);
#endif
#if POM_RES == 256
const vec3 pomDepth = vec3(0.00390625, 0.00390625, 0.0189453125);
#endif
#if POM_RES == 512
const vec3 pomDepth = vec3(0.001953125, 0.001953125, 0.00751953125);
#endif

uniform sampler2D normals;
varying float dist;
varying vec3 viewVector;
varying mat3 tbnMatrix;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;

vec2 dcdx = dFdx(vtexcoord.st*vtexcoordam.pq);
vec2 dcdy = dFdy(vtexcoord.st*vtexcoordam.pq);

vec4 readNormal(in vec2 coord){
	return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}
#endif

void main() {

vec4 newnormal = normal;

#ifdef POM
vec2 newCoord = vtexcoord.st*vtexcoordam.pq+vtexcoordam.st;
if (dist < 18.0) {
	if ( viewVector.z < 0.0 && readNormal(vtexcoord.st).a < 0.99 && readNormal(vtexcoord.st).a > 0.01){
		vec3 coord = vec3(vtexcoord.st, 1.0);
		for (int i= 0; i < 50 && (readNormal(coord.st).a < coord.p); ++i) coord = coord + viewVector.xyz * pomDepth;
	
		newCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st, newCoord, max(dist-18.0,0.0) * 0.25);
	}
}
vec4 albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy)*color;
//vec4 specularity = texture2DGradARB(specular, newCoord, dcdx, dcdy);

vec3 bumpMapping = texture2DGradARB(normals, newCoord, dcdx, dcdy).rgb*2.0-1.0;
newnormal = vec4(normalize(bumpMapping * tbnMatrix), 1.0);
#else
vec4 albedo = texture2D(texture,texcoord.xy)*color;
#endif

vec4 cAlbedo = vec4(RGB2YCoCg(albedo.rgb),albedo.a);

bool pattern = (mod(gl_FragCoord.x,2.0)==mod(gl_FragCoord.y,2.0));
cAlbedo.g = (pattern)?cAlbedo.b: cAlbedo.g;
cAlbedo.b = normal.a;

	gl_FragData[0] = cAlbedo;
	gl_FragData[1] = encode(newnormal.xyz);
	//gl_FragData[2] = specularity;
}
#version 120
#extension GL_ARB_shader_texture_lod : enable
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

/*--------------------
//ADJUSTABLE VARIABLES//
---------------------*/
	#define Godrays
		#define Godrays_Density 1.15			//[0.575 1.15 2.3 4.6 9.2]
	//#define Lens_Flares

	//#define Volumetric_Lighting					//Disable godrays before enabling volumetric lighting.
	
	#define Fog									//Toggle fog
		#define wFogDensity	100.0				//adjust fog density [1.0 50.0 100.0 150.0 200.0]		
	#define Underwater_Fog						//Toggle underwater fog. 
		#define uFogDensity 40.0				//adjust underwater fog density [20.0 40.0 80.0 160.0]		
		
	#define Clouds								//Toggle clouds
		#define Cloud_reflection				//Toggle clouds reflection in water	

	#define IceGlassReflections					//Toggle stained glass and ice reflections
	
	#define Moonshading							//Toggle moon drawn by shaderpack. If disabled, enable default moon in: video settings -> details -> Sun & Moon: on		

	//#define MC189							//Don't enable unless you use MC 1.8 or 1.8.9
/*---------------------------
//END OF ADJUSTABLE VARIABLES//
----------------------------*/

const int maxf = 6;				//number of refinements
const float ref = 0.07;			//refinement multiplier
const float inc = 2.2;			//increasement factor at each step
/*--------------------------------*/
const int noiseTextureResolution = 512;

varying vec2 texcoord;
varying vec2 lightPos;

varying vec3 sunVec;
varying vec3 upVec;
varying vec3 lightColor;
varying vec3 sky1;
varying vec3 sky2;
varying vec3 nsunlight;
varying vec3 sunlight;
const vec3 moonlight = vec3(0.0025, 0.0045, 0.007);
varying vec3 rawAvg;
varying vec3 avgAmbient2;
varying vec3 cloudColor;
varying vec3 cloudColor2;

varying float fading;
varying float tr;
varying float eyeAdapt;
varying float SdotU;
varying float sunVisibility;
varying float moonVisibility;

uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;

uniform sampler2D noisetex;
uniform sampler2D gaux3;
uniform sampler2D gaux2;
uniform sampler2D gaux4;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform int worldTime;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float frameTimeCounter;

/*------------------------------------------*/
float comp = 1.0-near/far/far;
float tmult = mix(min(abs(worldTime-6000.0)/6000.0,1.0),1.0,rainStrength);
float night = clamp((worldTime-13000.0)/300.0,0.0,1.0)-clamp((worldTime-22800.0)/200.0,0.0,1.0);

//Used for Raytracing
vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}/*-----------------------------------------------------*/

//Draw sun and moon
vec3 drawSun(vec3 fposition, vec3 color, float vis) {
	vec3 sVector = normalize(fposition);
	float angle = (1.0-max(dot(sVector,sunVec),0.0))* 650.0;
	float sun = exp(-angle*angle*angle);
			sun *= (1.0-rainStrength*1.0)*sunVisibility;
	vec3 sunlightB = mix(pow(sunlight,vec3(1.0))*44.0,vec3(0.25,0.3,0.4),rainStrength*0.8);

	return mix(color,sunlightB,sun*vis);
}
vec3 drawMoon(vec3 fposition, vec3 color, float vis) {
	vec3 sVector = normalize(fposition);
	float angle = (1.0-max(dot(sVector,-sunVec),0.0))* 2000.0;
	float moon = exp(-angle*angle*angle);
			moon *= (1.0-rainStrength*1.0)*moonVisibility;
	vec3 moonlightC = mix(pow(moonlight*40.0,vec3(1.0))*44.0,vec3(0.25,0.3,0.4),rainStrength*0.8);

	return mix(color,moonlightC,moon*vis);
}/**--------------------------------------*/

float getAirDensity (float h) {
	return max(h/10.,6.0);
}

float calcFog(vec3 fposition) {
	float density = wFogDensity*(1.0-rainStrength*0.115);

	vec3 worldpos = (gbufferModelViewInverse*vec4(fposition,1.0)).rgb+cameraPosition;
	float height = mix(getAirDensity (worldpos.y),6.,rainStrength);
	float d = length(fposition);
#ifdef Fog
	return pow(clamp((2.625+rainStrength*3.4)/exp(-60/10./density)*exp(-getAirDensity (cameraPosition.y)/density) * (1.0-exp( -pow(d,2.712)*height/density/(6000.-tmult*tmult*2000.)/13))/height,0.0,1.),1.0-rainStrength*0.63)*clamp((eyeBrightnessSmooth.y/255.-2/16.)*4.,0.0,1.0);
#else
	return 0.0;
#endif
}/*---------------------------------*/


//Skycolor
vec3 getSkyc(vec3 fposition) {
vec3 sVector = normalize(fposition);

float invRain07 = 1.0-rainStrength*0.6;
float cosT = dot(sVector,upVec);
float mCosT = max(cosT,0.0);
float absCosT = 1.0-max(cosT*0.82+0.26,0.2);
float cosY = dot(sunVec,sVector);
float Y = acos(cosY);

const float a = -1.;
const float b = -0.22;
const float c = 8.0;
const float d = -3.5;
const float e = 0.3;

//luminance
float L =  (1.0+a*exp(b/(mCosT)));
float A = 1.0+e*cosY*cosY;

//gradient
vec3 grad1 = mix(sky1,sky2,absCosT*absCosT);
float sunscat = max(cosY,0.0);
vec3 grad3 = mix(grad1,nsunlight,sunscat*sunscat*(1.0-mCosT)*(0.9-rainStrength*0.5*0.9)*(clamp(-(SdotU)*4.0+3.0,0.0,1.0)*0.65+0.35)+0.1);

float Y2 = 3.14159265359-Y;
float L2 = L * (8.0*exp(d*Y2)+A);

const vec3 moonlight2 = pow(normalize(moonlight),vec3(3.0))*length(moonlight);
const vec3 moonlightRain = normalize(vec3(0.25,0.3,0.4))*length(moonlight);
vec3 gradN = mix(moonlight,moonlight2,1.-L2/2.0);
gradN = mix(gradN,moonlightRain,rainStrength);

return pow(L*(c*exp(d*Y)+A),invRain07)*sunVisibility *length(rawAvg) * (0.85+rainStrength*0.425)*grad3+ 0.2*pow(L2*1.2+1.2,invRain07)*moonVisibility*gradN;
}/*---------------------------------*/

//Raytracing
vec4 raytrace(vec3 fragpos, vec3 skycolor, vec3 rvector, float mulfov) {
    vec4 color = vec4(0.0);
    vec3 start = fragpos;

    fragpos += rvector;
	vec3 tvector = rvector;
    int sr = 0;

    for(int i=0;i<25;i++){
        vec3 pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5/vec3(mulfov,mulfov,1.0) + 0.5;
        if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;
        vec3 fragpos0 = vec3(pos.st, texture2D(depthtex1, pos.st).r);
        fragpos0 = nvec3(gbufferProjectionInverse * nvec4(fragpos0 * 2.0 - 1.0));
		fragpos0.xy *= mulfov;
        float err = distance(fragpos,fragpos0);
		if(err < pow(length(rvector)*1.85,1.15)){
                sr++;
                if(sr >= maxf){
					bool land = texture2D(depthtex1, pos.st).r < comp;
                    color = pow(texture2DLod(gaux1, pos.st, 1),vec4(2.2))*257.0;
					if (isEyeInWater == 0) color.rgb = land ? mix(color.rgb,skycolor*(0.7+0.3*tmult)*(1.33-rainStrength*0.8),calcFog(fragpos0.xyz)) : drawSun(rvector,skycolor,1.0);
					color.a = clamp(1.0 - pow(cdist(pos.st), 20.0), 0.0, 1.0);
					break;
                }
				tvector -= rvector;
                rvector *= ref;

}
        rvector *= inc;
        tvector += rvector;
		fragpos = start + tvector;
    }
    return color;
}/*--------------------------------------*/


#ifdef Clouds
float subSurfaceScattering(vec3 vec,vec3 pos, float N) {
	return pow(max(dot(vec,normalize(pos)),0.0),N)*(N+1)/6.28;
}

float noisetexture(vec2 coord){
	return texture2D(noisetex, coord).x;
}

vec3 drawCloud(vec3 fposition, vec3 color) {
const float r = 3.2;
const vec4 noiseC = vec4(1.0,r,r*r,r*r*r);
const vec4 noiseWeights = 1.0/noiseC/dot(1.0/noiseC,vec4(1.0));

vec3 tpos = vec3(gbufferModelViewInverse * vec4(fposition, 0.0));
tpos = normalize(tpos);

float cosT = max(dot(fposition, upVec),0.0);

float wind = abs(frameTimeCounter/2000.0-0.5)+0.5;
float distortion = wind * 0.045;
	
float iMult = -log(cosT)*2.0+2.0;
float heightA = (400.0+300.0*sqrt(cosT))/(tpos.y);

for (int i = 1;i<22;i++) {
	vec3 intersection = tpos*(heightA-4.0*i*iMult); 			//curved cloud plane
	vec2 coord1 = intersection.xz/200000.0+wind*0.05;
	vec2 coord = fract(coord1/1.5);
	
	vec4 noiseSample = vec4(noisetexture(coord+distortion),
							noisetexture(coord*noiseC.y+distortion),
							noisetexture(coord*noiseC.z+distortion),
							noisetexture(coord*noiseC.w+distortion));

	float j = i / 22.0;
	coord = vec2(j+0.5,-j+0.5)/noiseTextureResolution + coord.xy + sin(coord.xy*3.14*j)/10.0 + wind*0.02*(j+0.5);
	
	vec2 secondcoord = 1.0 - coord.yx;
	vec4 noiseSample2 = vec4(noisetexture(secondcoord),
							 noisetexture(secondcoord*noiseC.y),
							 noisetexture(secondcoord*noiseC.z),
							 noisetexture(secondcoord*noiseC.w));

	float finalnoise = dot(noiseSample*noiseSample2,noiseWeights);
	float cl = max((sqrt(finalnoise*max(1.0-abs(i-11.0)/11*(0.15-1.7*rainStrength),0.0))-0.55)/(0.65+2.0*rainStrength)*clamp(cosT*cosT*2.0,0.0,1.0),0.0);

	float cMult = max(pow(30.0-i,3.5)/pow(30.,3.5),0.0)*6.0;

	float sunscattering = subSurfaceScattering(sunVec, fposition, 75.0)*pow(cl, 3.75);
	float moonscattering = subSurfaceScattering(-sunVec, fposition, 75.0)*pow(cl, 5.0);
	
	color = color*(1.0-cl)+cl*cMult*mix(cloudColor2,cloudColor,min(cMult,1.0)) * 0.05 + sunscattering+moonscattering;
	}
return color;
}/*---------------------------*/
#endif


//Refractions
float waterH(vec3 posxz, float time) {
vec4 waveXYZW = vec4(posxz.xz,posxz.xz)/vec4(250.,50.,-250.,-150.)+vec4(50.,250.,50.,-250.);
vec2 fpxy = abs(fract(waveXYZW.xy*20.0)-0.5)*2.0;

float d = 0.2*length(fpxy);
float wave = cos(waveXYZW.x*waveXYZW.y+time) + 0.5 * cos(2.0*waveXYZW.x*waveXYZW.y+time) + 0.25 * cos(4.0*waveXYZW.x*waveXYZW.y+time);

return d*wave + d*(cos(waveXYZW.z*waveXYZW.w+time) + 0.5 * cos(2.0*waveXYZW.z*waveXYZW.w+time) + 0.25 * cos(4.0*waveXYZW.z*waveXYZW.w+time));
}/*--------------------------------*/

vec3 decode (vec2 enc){
    vec2 fenc = enc*4-2;
    float f = dot(fenc,fenc);
    float g = sqrt(1-f/4.0);
    vec3 n;
    n.xy = fenc*g;
    n.z = 1-f/2;
    return n;
}


/* If you reached this line, then you're probably about to break the agreement which you accepted by downloading Sildur's shaders!
So stop your doing and ask Sildur before copying anything which would break the agreement, unless you're Chocapic then go ahead ;)
--------------------------------------------------------------------------------------------------------------------------------*/

void main() {

vec3 c = pow(texture2D(gaux1,texcoord).xyz,vec3(2.2))*257.;
vec3 hr = texture2D(composite,(floor(texcoord*vec2(viewWidth,viewHeight)/2.0)*2.0+1.0)/vec2(viewWidth,viewHeight)/2.0).rgb;

#ifdef MC189 
	hr.rgb = pow(hr.rgb, vec3(2.0))*25.0;
#else
	hr.rgb = hr.rgb*30.0;
#endif

//Depth and fragpos
float depth0 = texture2D(depthtex0, texcoord).x;
vec4 fragpos0 = gbufferProjectionInverse * (vec4(texcoord, depth0, 1.0) * 2.0 - 1.0);
fragpos0 /= fragpos0.w;
vec3 normalfragpos0 = normalize(fragpos0.xyz);

float depth1 = texture2D(depthtex1, texcoord).x;
vec4 fragpos1 = gbufferProjectionInverse * (vec4(texcoord, depth1, 1.0) * 2.0 - 1.0);
	 fragpos1 /= fragpos1.w;
vec3 normalfragpos1 = normalize(fragpos1.xyz);
/*--------------------------------------------------------------------------------------------*/

//Sky
if (depth1 > comp){
	c = hr.rgb;
#ifdef Clouds	
	c = drawCloud(normalfragpos1.xyz, c);
#endif	
	c = drawSun(fragpos1.xyz, c, 1.0);
#ifdef Moonshading	
	c = drawMoon(fragpos1.xyz, c, 1.0);
#endif
}/*--------------------------------------*/
	
bool land = depth0 < comp;
if (land){
	//Draw fog
	vec3 fogC = hr.rgb*(0.7+0.3*tmult)*(1.33-rainStrength*0.67);
	float fogF = calcFog(fragpos1.xyz);
	/*----------------------------------------------------------------*/
	
  vec4 trp = texture2D(gaux3,texcoord.xy);
  bool transparency = dot(trp.xyz,trp.xyz) > 0.000001;
  if (transparency) {
	vec3 normal = texture2D(gnormal,texcoord).xyz;
	float sky = normal.z;

	bool iswater = sky < 0.2499;
	bool isice = sky > 0.2499 && sky < 0.4999;

	if (iswater) sky *= 4.0;
	if (isice) sky = (sky - 0.25)*4.0;

	if (!iswater && !isice) sky = (sky - 0.5)*4.0;

	sky = clamp(sky*1.2-2./16.0*1.2,0.,1.0);
	sky *= sky;

	normal = decode(normal.xy);

	bool reflective = dot(normal.xyz,normal.xyz) > 0.0;

	normal = normalize(normal);
	
	bool getlight = (eyeBrightness.y / 255.0) > 0.1;
	//Refractions
		if (iswater) {
			vec3 wpos = (gbufferModelViewInverse*fragpos0).rgb+cameraPosition;
				 wpos.x *= tan(12.0);
				 wpos.z *= 0.2;
				 
			float ft = iswater? frameTimeCounter*4.0:0.0;
			const float deltaPos = 0.4;
			float h0 = waterH(wpos,ft);
			float h1 = waterH(wpos - vec3(deltaPos,0.0,0.0),ft);
			float h2 = waterH(wpos - vec3(0.0,0.0,deltaPos),ft);

			float dX = ((h0-h1))/deltaPos;
			float dY = ((h0-h2))/deltaPos;

			vec3 refract = normalize(vec3(dX,dY,1.0));
			float refMult = sqrt(1.0-dot(normal, normalfragpos0)*dot(normal, normalfragpos0))*0.005;

			vec2 newtc = texcoord.xy + refract.xy*refMult;
			c = pow(texture2D(gaux1,newtc).xyz,vec3(2.2))*257.;
						
			float caustics = waterH((wpos.xyz)*2.0,ft)*0.2+0.98;
			if(getlight)c *= caustics*caustics*caustics;
		
			//Draw sky related things again for water
			if(depth1 > comp){
				c = hr.rgb;
			#ifdef Clouds
				c = drawCloud(normalfragpos0.xyz, c);
			#endif
				c = drawSun(fragpos1.xyz, c, 1.0);
			#ifdef Moonshading	
				c = drawMoon(fragpos1.xyz, c, 1.0);
			#endif
			}
		}/*----------------------------------------------------------------*/
		
		//draw fog for transparency
		float iswater2 = float(iswater);
		if(!getlight)c = mix(c,fogC,fogF-fogF)/ (1.0 + 1.0*iswater2);
		else c = mix(c,fogC,fogF-fogF)/ (1.0 + 5.0*night*iswater2);

		//Draw transparency
		vec3 finalAc = texture2D(gaux2, texcoord.xy).rgb;
		float alphaT = clamp(length(trp.rgb)*1.02,0.0,1.0);

		c = mix(c,c*(trp.rgb*0.9999+0.0001)*1.732,alphaT)*(1.0-alphaT) + finalAc;
		/*-----------------------------------------------------------------------------------------*/
	
	//Reflections
	if (reflective) {
		vec3 reflectedVector = reflect(normalfragpos1, normal);
		vec3 hV= normalize(reflectedVector - normalfragpos1);

		float normalDotEye = dot(hV, normalfragpos1);

		float F0 = 0.09;

		float fresnel = pow(clamp(1.0 + normalDotEye,0.0,1.0), 4.0) ;
		fresnel = fresnel+F0*(1.0-fresnel);
	
	#ifdef Cloud_reflection	
		vec3 sky_c = getSkyc(reflectedVector*620.)*1.7 +drawCloud(reflectedVector, vec3(0.0))*2.0;
	#else
		vec3 sky_c = getSkyc(reflectedVector*620.)*1.7;
	#endif

		vec4 reflection = raytrace(fragpos0.xyz, sky_c, reflectedVector, 1.0); //1.0 = mulfov
		sky_c = (isEyeInWater == 0)? ((drawSun(reflectedVector, sky_c, 1.0)+drawMoon(reflectedVector, sky_c, 1.0)) * 0.5)*sky : pow(vec3(0.25,0.5,0.72),vec3(2.2))*rawAvg*0.1;
		reflection.rgb = mix(sky_c, reflection.rgb, reflection.a)*0.5;

	#ifdef IceGlassReflections
		fresnel *= 0.5 + 0.5*iswater2;
	#else
		fresnel *= 1.0*iswater2;
	#endif
		c = mix(c,reflection.rgb,fresnel);
	}
  }
	//Draw land and underwater fog
	c = mix(c,fogC*(1.0-isEyeInWater),fogF);
	#ifdef Underwater_Fog
	if (isEyeInWater > 0.9) c = mix(c*0.4,vec3(0.25,0.5,0.72)*rawAvg*0.07,1.-exp(-length(fragpos0.xyz)/uFogDensity));
	#endif
}

//Draw rain
bool hand = texture2D(gaux3, texcoord.xy).x < 0.005;
vec4 rain = texture2D(gaux4, texcoord);
if (rain.r > 0.0001 && rainStrength > 0.01 && depth0 < depth1 || hand){
	float rainRGB = 0.25;
	float rainA = rain.r;

	float torch_lightmap = 6.4 - min(rain.g/rain.r * 6.16,5.6);
	torch_lightmap = 0.1 / torch_lightmap / torch_lightmap - 0.002595;

	vec3 rainC = rainRGB*(pow(max(dot(normalfragpos0, sunVec)*0.1+0.9,0.0),6.0)*(0.1+tr*0.9)*pow(sunlight,vec3(0.25))*sunVisibility+pow(max(dot(normalfragpos0, -sunVec)*0.05+0.95,0.0),6.0)*48.0*moonlight*moonVisibility)*0.04 + 0.05*rainRGB*length(avgAmbient2);
	rainC += torch_lightmap*vec3(1.0,0.4,0.04)*2.05/2.4;
	c = c*(1.0-rainA*0.3)+rainC*1.5*rainA;
}

#ifdef Godrays
	float sunpos = abs(dot(normalfragpos0,normalize(sunPosition.xyz)));
	float illuminationDecay = pow(sunpos,30.0)+pow(sunpos,16.0)*0.8+pow(sunpos,2.0)*0.125;
	
	vec2 deltaTextCoord = (lightPos-texcoord)*0.01;
	vec2 textCoord = texcoord*0.5+0.5;

	float gr = texture2DLod(gaux1, textCoord + deltaTextCoord,1).a;
		  gr += texture2DLod(gaux1, textCoord + 2.0 * deltaTextCoord,1).a;
		  gr += texture2DLod(gaux1, textCoord + 3.0 * deltaTextCoord,1).a;
		  gr += texture2DLod(gaux1, textCoord + 4.0 * deltaTextCoord,1).a;
		  gr += texture2DLod(gaux1, textCoord + 5.0 * deltaTextCoord,1).a;
		  gr += texture2DLod(gaux1, textCoord + 6.0 * deltaTextCoord,1).a;
		  gr += texture2DLod(gaux1, textCoord + 7.0 * deltaTextCoord,1).a;

	vec3 grC = lightColor*Godrays_Density;
	c += grC*gr/7.0*illuminationDecay*(1.0-isEyeInWater);
#endif

#ifdef Volumetric_Lighting
const float exposure = 1.05;

//sun-moon switch
vec3 lightVec = -sunVec;
vec3 lightcol = moonlight*5.0;
if (sunVisibility > 0.2){
	lightVec = sunVec;
	lightcol = sunlight;
}

float phase = 2.5+exp(dot(normalfragpos0,lightVec)*3.0)/3.0;
float vgr = texture2DLod(gaux1, texcoord, 1).a;

vec3 vgrC = lightcol*exposure*phase*0.08*(0.25+0.75*tmult*tmult)*tr*(1.0+pow(1.0-eyeBrightnessSmooth.y/255.0,2.0))*(1.0-rainStrength*0.9);
if (depth0 > comp)vgrC *= 0.2;
c += vgrC*vgr*(1.0-isEyeInWater)*(float(land)*0.2+0.8);
#endif

#ifdef Lens_Flares
#ifdef MC189
c += pow(texture2D(composite,texcoord.xy*0.5+0.5+1.0/vec2(viewWidth,viewHeight)).rgb, vec3(2.0))*fading*30*30/100*pow(dot(texture2D(gaux1, vec2(1.0)/vec2(viewWidth,viewHeight)).w, 1.0), 2.0);
#else
c += texture2D(composite,texcoord.xy*0.5+0.5+1.0/vec2(viewWidth,viewHeight)).rgb*fading*30*30/100*pow(dot(texture2D(gaux1, vec2(1.0)/vec2(viewWidth,viewHeight)).w, 1.0), 2.0);
#endif
#endif

#ifdef MC189
	c = pow(c/50.0*pow(eyeAdapt,0.88), vec3(0.5));
#else
	c = (c/50.0*pow(eyeAdapt,0.88));
#endif

	gl_FragData[0] = vec4(c,1.0);
}

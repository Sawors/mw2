float waterH(vec3 pos) {
	float noise = 0;
	noise+= texture2D(noisetex,(pos.xz+vec2(frametime)*0.5-pos.y*0.7)/1024.0* 1.1).r*1.0;
	noise+= texture2D(noisetex,(pos.xz-vec2(frametime)*0.5-pos.y*0.7)/1024.0* 1.5).r*0.8;
	noise-= texture2D(noisetex,(pos.xz+vec2(frametime)*0.5+pos.y*0.7)/1024.0* 2.5).r*0.6;
	noise+= texture2D(noisetex,(pos.xz-vec2(frametime)*0.5-pos.y*0.7)/1024.0* 5.0).r*0.4;
	noise-= texture2D(noisetex,(pos.xz+vec2(frametime)*0.5+pos.y*0.7)/1024.0* 8.0).r*0.2;

	return noise;
	}

float getCausticWaves(vec3 pos){
	float deltaPos = 0.1;
	float caustic_h0 = waterH(pos);
	float caustic_h1 = waterH(pos + vec3(deltaPos,0.0,0.0));
	float caustic_h2 = waterH(pos + vec3(-deltaPos,0.0,0.0));
	float caustic_h3 = waterH(pos + vec3(0.0,0.0,deltaPos));
	float caustic_h4 = waterH(pos + vec3(0.0,0.0,-deltaPos));

	float caustic = max((1.0-abs(0.5-caustic_h0))*(1.0-(abs(caustic_h1-caustic_h2)+abs(caustic_h3-caustic_h4))),0.0);
		  caustic = max(pow(caustic,3.5),0.0)*2.0;
		  
	return caustic;
}

vec3 GetCaustics(vec3 albedo, vec3 worldPos, vec3 cameraPosition, vec3 shadow, float skymapMod, float lightmapX){
    float causticfactor = pow(skymapMod, 0.5) * 50 * (1 - pow(skymapMod, 0.5)) * (1 - rainStrength*0.5) * (1 - lightmapX*0.8);
	vec3 causticcol = rawWaterColor.rgb;
	vec3 causticpos = worldPos.xyz+cameraPosition.xyz;
	float caustic = getCausticWaves(causticpos);
	vec3 lightcaustic = caustic*causticfactor*causticcol*shadowFade*shadow;
	albedo.rgb *= 0.20 + lightmapX*0.80;
	albedo.rgb += (1 - lightmapX) * (albedo.rgb * rawWaterColor.rgb * rawWaterColor.rgb * 100 + 100 * shadow * albedo.rgb * rawWaterColor.rgb * rawWaterColor.rgb);
	albedo.rgb *= 1 + lightcaustic;
	return albedo.rgb;
}
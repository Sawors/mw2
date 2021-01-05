vec3 GetExperimentalSkyColor(vec3 lightCol, float NdotU, vec3 nViewPos, bool doGround){    
    float invNdotU = 1.0 - NdotU;
    float invNdotU2 = invNdotU * invNdotU;
    float invNdotU4 = invNdotU2 * invNdotU2;
    float NdotU2 = NdotU * NdotU;
    float NdotU4 = NdotU2 * NdotU2;

    float smoothNdotU = smoothstep(0.0, 1.0, (NdotU + 1.0) * 0.5);

    vec3 sky = skyCol*skyCol;
    vec3 middle = vec3(1.0, 0.0, 0.0);
    vec3 bottom = sqrt(fogCol);

    if (NdotU > 0.0) sky = sky * (invNdotU2 * 0.75 + 0.25);
    sky *= vec3(2.0, 1.5, 1.0);
    //sky = mix(middle, sky, max(1.0 - invNdotU2, 0.0));
    sky = mix(bottom*bottom*5.0, sky, max(smoothNdotU, 0.0));

    return sky * 0.25;
}

vec3 GetSkyColor(vec3 lightCol, float NdotU, vec3 nViewPos, bool doGround){
    vec3 sky = skyCol;

    float NdotS = clamp(dot(nViewPos, sunVec) * 0.5 + 0.5, 0.001, 1.0);

    NdotU = min(NdotU + 0.015, 1.0);
	
	float sunVisibilityTimeBrightness = timeBrightness * 0.2 + sunVisibility * 0.8;

    float horizonExponent = 3.0 * ((1.0 - NdotS) * sunVisibility * (1.0 - rainStrength) *
                            (1.0 - 0.5 * timeBrightness)) + HORIZON_DISTANCE * 2.5 * (1.5 - rainStrength*0.5);
    float horizon = pow(1.0 - max(NdotU, 0.0)*0.5, horizonExponent);
    horizon *= (0.5 * sunVisibilityTimeBrightness + 0.3) * (1 - rainStrength * 0.75);

    float timeBrightnessModified = 1.0 - timeBrightness;
    timeBrightnessModified *= timeBrightnessModified;
    timeBrightnessModified = 1.0 - timeBrightnessModified * timeBrightnessModified;
    
    float lightmix = NdotS * NdotS * max(1.0 - abs(NdotU) * 2.0, 0.0) * pow(1.0 - timeBrightnessModified, 3.0) * 0.5 +
                     horizon * 0.075 * (6.0 - timeBrightnessModified*5.0) + 0.05 * (1.0 - timeBrightnessModified);
    lightmix *= sunVisibility * (1.0 - rainStrength);

    sky = mix(fogCol, sky, max(NdotU, 0.0));
	
	float ground = 0.0;

    #ifndef SKY_REF_FIX_2
        doGround = false;
    #endif

	if (doGround == true) {
	float invNdotU = clamp(dot(nViewPos, -upVec), 0.0, 1.0);
    float groundFactor = 0.5 * (11.0 * rainStrength + 1.0) * (-5.0 * sunVisibility + 6.0);
    ground = exp(-groundFactor / (invNdotU * 6));
    ground = smoothstep(0.0, 1.0, ground);
    }
    
    float mult = (0.1 * (1.0 + rainStrength) + horizon) * (1 - ground);
	
	float meFactor = 0.06;
	if (sunAngle > 0.5) {
		if (sunAngle >  0.75) meFactor = max(sunAngle - 0.94, 0.0);
		if (sunAngle <= 0.75) meFactor = max(0.56 - sunAngle, 0.0);
	}
	vec3 meSkyColor = (1 - sunVisibility) * pow(mix(lightMorning, lightEvening, mefade), vec3(4.0)) *NdotS*NdotS*NdotS * 8 * meFactor;
	if (NdotU < 0.0) meSkyColor *= ((1 + NdotU)*(1 + NdotU)) * ((1 + NdotU)*(1 + NdotU));
	if (NdotU >= 0.0) meSkyColor *= 1 - NdotU;
	
    sky = mix(sky * pow(max(1.0 - lightmix, 0.0), 2.0 * sunVisibility), lightCol * sqrt(lightCol), lightmix) * sunVisibility
	      + (lightNight * lightNight * 0.4)
		  + (1.0 - sunVisibility) *lightNight*lightNight*lightNight* 90 * (1 - pow(NdotS, 0.01) * 0.975)
		  + meSkyColor * 0.8;
    
    vec3 weatherSky = weatherCol * weatherCol;
    weatherSky *= GetLuminance(ambientCol / (weatherSky)) * 1.4;
    sky = mix(sky, weatherSky, rainStrength) * mult;

    #ifdef FOG_DESATURATION
        if (NdotU < 0.0) {
            vec3 gray = vec3(0.299, 0.587, 0.114);
            gray = vec3(dot(gray, sky));
            sky = mix(sky, gray, min(0.0 - NdotU*2, 0.5) * 0.5 * (1-rainStrength) * (0.5 + (sunVisibility*0.5 + timeBrightness)));
        }
    #endif

    return pow(sky, vec3(1.125));
}
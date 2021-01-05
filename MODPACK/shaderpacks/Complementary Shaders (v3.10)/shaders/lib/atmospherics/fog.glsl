#ifdef OVERWORLD

#include "/lib/atmospherics/sunGlare.glsl"

#endif

vec3 Fog1(vec3 color, float lWorldPos, float lViewPos, vec3 nViewPos, vec3 skyFogColor){
    #if defined OVERWORLD && !defined ONESEVEN && !defined TWO
		float fog = lWorldPos / far * 1.5 * (1 + rainStrength*0.3) * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 10 - rainStrength*5));
		vec3 artificialFogColor = skyFogColor;
		if (eyeAltitude < 2.0) artificialFogColor.rgb *= clamp((eyeAltitude-1.0), 0.0, 1.0);
		color.rgb = mix(color.rgb, artificialFogColor, fog);
	#endif

    #ifdef NETHER
		float fog = lWorldPos / far * 1.5;
		fog = 1.0 - exp(-6.0 * pow(fog, 5));
		vec3 artificialFogColor = pow((netherCol * 2.5) / NETHER_I, vec3(2.2)) * 4;
		color.rgb = mix(color.rgb, artificialFogColor, fog);
    #endif

    #ifdef END
		float fog = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 10));
		vec3 artificialFogColor = endCol * 0.051 * pow(2.5 / END_I, 1.3);
		color.rgb = mix(color.rgb, artificialFogColor, fog);
    #endif

    #ifdef TWO
		float fog = lWorldPos / far * 4.0 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 3));

		float NdotU = 1.0 - max(dot(nViewPos, upVec), 0.0);
		NdotU *= NdotU;
		vec3 midnightPurple = vec3(0.0003, 0.0004, 0.002) * 1.25;
		vec3 midnightFogColor = fogColor * fogColor * 0.3;
		vec3 artificialFogColor = mix(midnightPurple, midnightFogColor, NdotU);

		color.rgb = mix(color.rgb, artificialFogColor, fog);
    #endif
	
    #ifdef SEVEN
		float fog = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 10));
		float cosT = dot(nViewPos, upVec);
		vec3 twilightPurple  = vec3(0.005, 0.006, 0.018);
		vec3 twilightGreen = vec3(0.015, 0.03, 0.02);
		#ifdef TWENTY
		twilightPurple = twilightGreen * 0.1;
		#endif
		vec3 artificialFogColor = 2 * (twilightPurple * 2 * clamp(pow(cosT, 0.7), 0.0, 1.0) + twilightGreen * (1-clamp(pow(cosT, 0.7), 0.0, 1.0)));
		color.rgb = mix(color.rgb, artificialFogColor, fog);
    #endif
	
    #ifdef TEN
		float fog = lWorldPos / far * 1.5 * (10/FOG1_DISTANCE);
		fog = 1.0 - exp(-0.1 * pow(fog, 10));
		vec3 artificialFogColor = vec3(0.0, 0.0, 0.0);
		color.rgb = mix(color.rgb, artificialFogColor, fog);
    #endif
	
    #ifdef ONESEVEN
		float fogoneseven = lWorldPos / 16 * (1.35-sunVisibility*0.35);
		fogoneseven = 1.0 - exp(-0.1 * pow(fogoneseven, 3));
		vec3 fogColoroneseven = skyFogColor;
		color.rgb = mix(color.rgb, fogColoroneseven, fogoneseven);
    #endif
	
	return vec3(color.rgb);
}

vec3 Fog2(vec3 color, float lViewPos, vec3 worldPos, vec3 skyFogColor){

    #ifdef OVERWORLD
		#if defined FOG2_ALTITUDE_MODE || defined COMPATIBILITY_MODE
			float altitudeFactor = (worldPos.y + eyeAltitude + 1000 - FOG2_ALTITUDE) * 0.001;
			if (altitudeFactor > 0.965 && altitudeFactor < 1.0) altitudeFactor = pow(altitudeFactor, 1.0 - (altitudeFactor - 0.965) * 28.57);
			altitudeFactor = clamp(pow(altitudeFactor, 20.0), 0.0, 1.0);
		#endif
		
		float fog2 = lViewPos / pow(far, 0.25) * 0.035 * (1.0 + rainStrength) * (1.0 - sunVisibility*0.25*(1.0 - rainStrength)) * (32.0/(FOG2_DISTANCE + 0.01));
		fog2 = (1.0 - (exp(-50.0 * pow(fog2*0.125, 3.25) * eBS)));
		fog2 *= min(FOG2_OPACITY * (3.0 + rainStrength * 2.0 - sunVisibility * 2.0), 1.0);
		#if defined FOG2_ALTITUDE_MODE || defined COMPATIBILITY_MODE
			fog2 *= pow(clamp((eyeAltitude - FOG2_ALTITUDE*0.2) / FOG2_ALTITUDE, 0.0, 1.0), 2.0);
			fog2 *= 1.0 - altitudeFactor * (1.0 - rainStrength*0.25);
		#endif
		
		vec3 fogColor2 = skyFogColor;
		if (eyeAltitude < 2.0) fogColor2.rgb *= clamp((eyeAltitude-1.0), 0.0, 1.0);
		color.rgb = mix(color.rgb, fogColor2, fog2);
    #endif

    #ifdef END
		float fog2 = lViewPos / pow(far, 0.25) * 0.035 * (32.0/FOG2_END_DISTANCE);
		fog2 = 1.0 - (exp(-50.0 * pow(fog2*0.125, 4)));
		#if defined FOG2_ALTITUDE_MODE || defined COMPATIBILITY_MODE
			float altitudeFactor = clamp((worldPos.y + eyeAltitude + 100 - FOG2_END_ALTITUDE) * 0.01, 0.0, 1.0);
			if (altitudeFactor > 0.75 && altitudeFactor < 1.0) altitudeFactor = pow(altitudeFactor, 1.0 - (altitudeFactor - 0.75) * 4.0);
			fog2 *= 1.0 - altitudeFactor;
		#endif
		fog2 = clamp(fog2, 0.0, 0.125) * (7.0 + fog2);
		fog2 = 1 - pow(1 - fog2, 2.0 - fog2);
		vec3 fogColor2 = endCol * 0.051 * pow(2.5 / END_I, 1.3);
		color.rgb = mix(color.rgb, fogColor2, fog2 * FOG2_END_OPACITY);
    #endif
	
    #if defined SEVEN && !defined TWENTY
		float fog2 = lViewPos / pow(far, 0.25) * 0.035 * (1 + rainStrength) * (32.0/(FOG2_DISTANCE + 0.01));
		fog2 = 1.0 - (exp(-50.0 * pow(fog2*0.125, 4) * eBS));
		float altitudeFactor = (worldPos.y + eyeAltitude + 1000 - 90 * (1 + rainStrength*0.5)) * 0.001;
		if (altitudeFactor > 0.965 && altitudeFactor < 1.0) altitudeFactor = pow(altitudeFactor, 1.0 - (altitudeFactor - 0.965) * 28.57);
		fog2 *= 1.0 - altitudeFactor;
		fog2 = clamp(fog2, 0.0, 0.125) * (7.0 + fog2);
		vec3 fogColor2 = vec3(0.015, 0.03, 0.02);
		if (eyeAltitude < 2.0) fogColor2.rgb *= clamp((eyeAltitude-1.0), 0.0, 1.0);
		color.rgb = mix(color.rgb, fogColor2, fog2 * 0.80);
    #endif
	
	return vec3(color.rgb);
}

void WaterFog(inout vec3 color, float lViewPos, float fogrange){
    float fog = lViewPos / fogrange;
    fog = 1.0 - exp(-3.0 * fog * fog);
	color *= pow(rawWaterColor.rgb, vec3(0.5)) * 3.0;
    color = mix(color, 0.8 * pow(rawWaterColor.rgb * (1.0 - blindFactor), vec3(2.0)), fog);
}

vec3 BlindFog(vec3 color, float lViewPos){
	float fog = lViewPos *0.04* (5.0 / blindFactor);
	fog = (1.0 - exp(-6.0 * fog * fog * fog)) * blindFactor;
	color.rgb = mix(color.rgb, vec3(0.0), fog);
	
	return vec3(color.rgb);
}

vec3 LavaFog(inout vec3 color, float lViewPos){
	#ifndef LAVA_VISIBILITY
		float fog = lViewPos * 0.3;
		fog = (1.0 - exp(-4.0 * fog * fog * fog));
		color.rgb = mix(color.rgb, vec3(0.5), fog);
	#else
		float fog = lViewPos * 0.02;
		fog = 1.0 - exp(-3.0 * fog);
		color.rgb = mix(color.rgb, vec3(0.5), fog);
	#endif

	return vec3(color.rgb);
}

vec3 startFog(vec3 color, vec3 nViewPos, float lViewPos, vec3 worldPos, float NdotU){

	vec3 skyFogColor = vec3(0.0);
	#if (defined FOG1 || defined FOG2) && (defined OVERWORLD || defined ONESEVEN)
		skyFogColor = GetSkyColor(lightCol, NdotU, nViewPos, false);
		skyFogColor = SunGlare(skyFogColor, nViewPos, lightCol);
	#endif
	
	#ifdef FOG2
		if (isEyeInWater == 0) color.rgb = Fog2(color.rgb, lViewPos, worldPos, skyFogColor);
	#endif
	
	#ifdef FOG1
		if (isEyeInWater == 0) color.rgb = Fog1(color.rgb, length(worldPos.xz) * 1.025, lViewPos, nViewPos, skyFogColor);
	#endif
	
	if (isEyeInWater == 1 && blindFactor == 0) WaterFog(color.rgb, lViewPos, waterFog * (1.0 + eBS));
	if (isEyeInWater == 2 && blindFactor == 0) color.rgb = LavaFog(color.rgb, lViewPos);
	if (blindFactor > 0.0) color.rgb = BlindFog(color.rgb, lViewPos);
	
	return vec3(color.rgb);
}
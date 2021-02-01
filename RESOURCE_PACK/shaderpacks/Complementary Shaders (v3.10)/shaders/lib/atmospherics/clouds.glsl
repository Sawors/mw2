#if !defined END && !defined SEVEN

float CloudNoise(vec2 coord, vec2 wind) {
	//float noise = texture2D(noisetex, coord*0.5      + wind * 0.45).x * 1.0;
	//float noise = texture2D(noisetex, coord*0.25     + wind * 0.35).x * 3.0;
	float noise = texture2D(noisetex, coord*0.125    + wind * 0.25).x * 7.0;
		  noise+= texture2D(noisetex, coord*0.0625   + wind * 0.15).x * 12.0;
		  noise+= texture2D(noisetex, coord*0.03125  + wind * 0.05).x * 12.0;
		  noise+= texture2D(noisetex, coord*0.015625 + wind * 0.05).x * 24.0;
	return noise*0.34;
}

float CloudCoverage(float noise, float coverage, float NdotU, float cosS) {
	float noiseCoverageFactor = abs(cosS) * 0.5;
	noiseCoverageFactor *= sqrt(timeBrightness) + (1.0 - sunVisibility);
	float noiseCoverage = coverage * coverage + CLOUD_AMOUNT
							* (1.0 + pow(noiseCoverageFactor, 3.0) * 2.0) 
							* (1.0 + NdotU * 0.0625 * (1.0-rainStrength*9.0))
							- 2.0;

	return max(noise - noiseCoverage, 0.0);
}

vec4 DrawCloud(vec3 viewPos, float dither, vec3 lightCol, vec3 ambientCol, float NdotU) {
	float cosS = dot(normalize(viewPos), sunVec);
	
	#if AA > 1
		dither = fract(16.0 * frameTimeCounter + dither);
	#endif
	
	float cloud = 0.0;
	float cloudGradient = 0.0;
	float gradientMix = dither * 0.1667;
	float colorMultiplier = CLOUD_BRIGHTNESS * (0.25 + 0.25 * timeBrightness);
	float noiseMultiplier = CLOUD_THICKNESS * 0.125;
	float scattering = pow(cosS * 0.5 * (2.0 * sunVisibility - 1.0) + 0.5, 6.0);

	float cloudHeightFactor = max(1.14 - 0.002 * eyeAltitude, 0.0);
	cloudHeightFactor *= cloudHeightFactor;
	float cloudHeight = CLOUD_HEIGHT * cloudHeightFactor * 0.5;

	#if !defined GBUFFERS_WATER && !defined DEFERRED
		float cloudframetime = frametime;
	#else
		float cloudframetime = cloudtime;
	#endif
	float cloudSpeedFactor = 0.003;
	vec2 wind = vec2(sin(cloudframetime * CLOUD_SPEED * 0.1) * cloudSpeedFactor * 10.0 + cloudframetime * CLOUD_SPEED * cloudSpeedFactor,
					cloudframetime * CLOUD_SPEED * cloudSpeedFactor);
		 wind = vec2(-1.0 * wind.y, 0.5 * wind.x);
	#ifdef SEVEN
		wind *= 8;
	#endif

	vec3 cloudcolor = vec3(0.0);

	float stretchFactor = 2.5;
	float coordFactor = 0.009375;

	if (NdotU > 0.0) {
		vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
		for(int i = 0; i < 6; i++) {
			if (cloud > 0.99) break;
			vec3 planeCoord = wpos * ((cloudHeight + (i + dither) * stretchFactor) / wpos.y) * 0.0085;
			vec2 coord = cameraPosition.xz * 0.0005 + planeCoord.xz;
			/**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ 
			if (coordFactor > 0.0) {
				float ang1 = (i + frametime * 0.025) * 2.391;
				float ang2 = ang1 + 2.391;
				coord += mix(vec2(cos(ang1),sin(ang1)),vec2(cos(ang2),sin(ang2)), dither * 0.25 + 0.75) * coordFactor;
			}
			/**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ /**/ 
			float coverage = float(i - 3.0 + dither) * 0.667;

			float noise = CloudNoise(coord, wind);
				  noise = CloudCoverage(noise, coverage, NdotU, cosS) * noiseMultiplier;
				  noise = noise / pow(pow(noise, 2.5) + 1.0, 0.4);

			cloudGradient = mix(cloudGradient,
			                    mix(gradientMix * gradientMix, 1.0 - noise, 0.25),
								noise * (1.0 - cloud));
			cloud = mix(cloud, 1.0, noise);
			gradientMix += 0.2;
		}

		float meFactor = 0.06;
		if (sunAngle > 0.5) {
			if (sunAngle >  0.75) meFactor = max(sunAngle - 0.94, 0.0);
			if (sunAngle <= 0.75) meFactor = max(0.56 - sunAngle, 0.0);
		}
		vec3 meSkyColor = vec3(0.0);
		if (cosS > 0.0) meSkyColor = pow(mix(lightMorning, lightEvening, mefade), vec3(4.0)) *cosS * cosS * 8 * meFactor;
		meSkyColor *= 1.0 - NdotU;
		meSkyColor *= 1.0 - rainStrength;

		vec3 cloudUpColor = mix(ambientNight * ambientNight * 5.5, lightCol * 1.55, clamp(sunVisibility - meFactor * 8.0, 0.0, 1.0));
		cloudUpColor *= 1.0 + scattering;
		cloudUpColor += max(meSkyColor, vec3(0.0));
		vec3 cloudDownColor = skyCol * 0.15 * sunVisibility * sunVisibility;
		cloudGradient = min(cloudGradient, 0.8) * cloud;
		cloudcolor = mix(cloudDownColor, cloudUpColor, cloudGradient);

		cloud *= 1.0 - 0.7 * rainStrength;
		cloud *= 1.0 - exp(-10.0 * NdotU);
	}

	return vec4(cloudcolor * colorMultiplier, cloud * cloud * CLOUD_OPACITY);
}

#endif

#ifdef SEVEN

float GetNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.54953);
}

vec3 DrawStars(inout vec3 color, vec3 viewPos, float NdotU) {
	vec3 wpos = vec3(gbufferModelViewInverse * vec4(viewPos, 1.0));
	vec3 planeCoord = 0.75 * wpos / (wpos.y + length(wpos.xz));
	vec2 wind = 0.75 * vec2(frametime, 0.0);
	#ifdef SEVEN
		wind = vec2(0.0);
	#endif
	vec2 coord = planeCoord.xz * 0.5 + wind * 0.00125;
	coord = floor(coord*1024.0) / 1024.0;
	
	float multiplier = 5.0 * (1.0 - rainStrength) * (1 - (sunVisibility*0.9 + pow(timeBrightness, 0.05)*0.1)) * pow(NdotU, 2.0);
	
	#ifdef SEVEN
		multiplier = sqrt(sqrt(NdotU)) * 5.0 * (1.0 - rainStrength);	
	#endif
	
	float star = 1.0;
	if (NdotU > 0.0) {
		star *= GetNoise(coord.xy);
		star *= GetNoise(coord.xy+0.1);
        star *= GetNoise(coord.xy+0.23);
	}
	star = max(star - 0.825, 0.0) * multiplier;
	
	#ifdef COMPATIBILITY_MODE
		vec3 stars = star * lightNight * lightNight * 160;
	#else
		vec3 stars = star * lightNight * lightNight * 320;
	#endif

	return vec3(stars);
}

#endif

#ifdef END

float CloudCoverageEnd(float noise, float cosT, float coverage) {
	float noiseMix = mix(noise, 21.0, 0.33 * rainStrength);
	float noiseFade = clamp(sqrt(cosT * 10.0), 0.0, 1.0);
	float noiseCoverage = ((coverage) + CLOUD_AMOUNT - 2);
	float multiplier = 1.0 - 0.5 * rainStrength;

	return max(noiseMix * noiseFade - noiseCoverage, 0.0) * multiplier;
}

float CloudNoiseEnd(vec2 coord, vec2 wind) {
	float noise = texture2D(noisetex, coord*1        + wind * 0.55).x;
		  noise+= texture2D(noisetex, coord*0.5      + wind * 0.45).x * -2.0;
		  noise+= texture2D(noisetex, coord*0.25     + wind * 0.35).x * 2.0;
		  noise+= texture2D(noisetex, coord*0.125    + wind * 0.25).x * -5.0;
		  noise+= texture2D(noisetex, coord*0.0625   + wind * 0.15).x * 20.0;
		  noise+= texture2D(noisetex, coord*0.03125  + wind * 0.05).x * 20.0;
		  noise+= texture2D(noisetex, coord*0.015625 + wind * 0.05).x * -15.0;
	return noise;
}

vec4 DrawEndCloud(vec3 viewPos, float dither, vec3 lightCol) {
	float cosT = dot(normalize(viewPos), upVec);
	float cosS = dot(normalize(viewPos), sunVec);

	#if AA > 1
		dither = fract(16.0 * frameTimeCounter + dither);
	#endif
	
	float cloud = 0.0;
	float cloudGradient = 0.0;
	float gradientMix = dither * 0.5;
	float colorMultiplier = 2.0 * (0.5 - 0.25 * (1.0 - sunVisibility) * (1.0 - rainStrength));
	float noiseMultiplier = 0.25;
	float scattering = pow(cosS * 0.5 + 0.5, 6.0);

	float cloudHeightFactor = max(1.14 - 0.002 * eyeAltitude, 0.0);
	cloudHeightFactor *= cloudHeightFactor;
	float cloudHeight = 12.0 * cloudHeightFactor;

	#ifndef GBUFFERS_WATER
		float cloudframetime = frametime;
	#else
		float cloudframetime = cloudtime;
	#endif
	vec2 wind = vec2(cloudframetime * CLOUD_SPEED * 0.005,
				     sin(cloudframetime * CLOUD_SPEED * 0.05) * 0.002);

	vec3 cloudcolor = vec3(0.0);

	if (cosT > 0.0) {
		vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
		for(int i = 0; i < 6; i++) {
			if (cloud > 0.99) break;
			vec3 planeCoord = wpos * ((cloudHeight + (i + dither)) / wpos.y) * 0.014;
			vec2 coord = cameraPosition.xz * 0.00025 + planeCoord.xz;
				float ang1 = (i + frametime * 0.025) * 2.391;
				float ang2 = ang1 + 2.391;
				coord += mix(vec2(cos(ang1),sin(ang1)),vec2(cos(ang2),sin(ang2)), dither * 0.25 + 0.75) * 0.008;
			float coverage = float(i - 3.0 + dither) * 0.667;

			float noise = CloudNoiseEnd(coord, wind);
				  noise = CloudCoverageEnd(noise, cosT, coverage*1.5) * noiseMultiplier;
				  noise = noise / pow(pow(noise, 2.5) + 1.0, 0.4);

			cloudGradient = mix(cloudGradient,
			                    mix(gradientMix * gradientMix, 1.0 - noise, 0.25),
								noise * (1.0 - cloud * cloud));
			cloud = mix(cloud, 1.0, noise);
			gradientMix += 0.6;
		}
		cloudcolor = lightCol * vec3(6.4, 6.8, 5.0) * (1.0 + scattering) * pow(cloudGradient, 0.75);
		cloudcolor = pow(cloudcolor, vec3(2)) * 6 * vec3(1.4, 1.8, 1.0);
		cloud *= min(cosT*cosT*4, 0.42);
	}

	return vec4(cloudcolor * colorMultiplier * (0.6+(sunVisibility)*0.4), cloud * cloud * 0.1 * CLOUD_OPACITY * (2-(sunVisibility)));
}

#endif
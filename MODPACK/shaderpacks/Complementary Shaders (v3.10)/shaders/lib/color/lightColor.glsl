vec3 lightMorning    = vec3(LIGHT_MR, LIGHT_MG, LIGHT_MB) * LIGHT_MI / 255.0;
vec3 lightDay        = vec3(LIGHT_DR, LIGHT_DG, LIGHT_DB) * LIGHT_DI / 255.0;
vec3 lightEvening    = vec3(LIGHT_ER, LIGHT_EG, LIGHT_EB) * LIGHT_EI / 255.0;
#ifndef ONESEVEN
vec3 lightNight      = vec3(LIGHT_NR, LIGHT_NG, LIGHT_NB) * LIGHT_NI * (screenBrightness*0.15 + 0.8) * 0.4 / 255.0;
#else
vec3 lightNight      = (vec3(LIGHT_NR, LIGHT_NG, LIGHT_NB) * LIGHT_NI * 0.3 / 255.0) * 0.65 + vec3(0.37, 0.31, 0.25) * 0.35 ;
#endif

vec3 ambientMorning  = vec3(AMBIENT_MR, AMBIENT_MG, AMBIENT_MB) * AMBIENT_MI * AMBIENT_AI / 255.0;
vec3 ambientDay      = vec3(AMBIENT_DR, AMBIENT_DG, AMBIENT_DB) * AMBIENT_DI * AMBIENT_AI / 255.0;
vec3 ambientEvening  = vec3(AMBIENT_ER, AMBIENT_EG, AMBIENT_EB) * AMBIENT_EI * AMBIENT_AI / 255.0;
vec3 ambientNight    = vec3(AMBIENT_NR, AMBIENT_NG, AMBIENT_NB) * AMBIENT_NI * AMBIENT_AI * (screenBrightness*0.15 + 0.8) * 0.45 / 255.0;

#ifdef WEATHER_PERBIOME
uniform float isDesert, isMesa, isCold, isSwamp, isMushroom, isSavanna;

vec3 weatherRain     = vec3(WEATHER_RR, WEATHER_RG, WEATHER_RB) * WEATHER_RI / 255.0;
vec3 weatherCold     = vec3(WEATHER_CR, WEATHER_CG, WEATHER_CB) * WEATHER_CI / 255.0;
vec3 weatherDesert   = vec3(WEATHER_DR, WEATHER_DG, WEATHER_DB) * WEATHER_DI / 255.0;
vec3 weatherBadlands = vec3(WEATHER_BR, WEATHER_BG, WEATHER_BB) * WEATHER_BI / 255.0;
vec3 weatherSwamp    = vec3(WEATHER_SR, WEATHER_SG, WEATHER_SB) * WEATHER_SI / 255.0;
vec3 weatherMushroom = vec3(WEATHER_MR, WEATHER_MG, WEATHER_MB) * WEATHER_MI / 255.0;
vec3 weatherSavanna  = vec3(WEATHER_VR, WEATHER_VG, WEATHER_VB) * WEATHER_VI / 255.0;

vec3 CalcWeatherColor(vec3 rain, vec3 desert, vec3 mesa, vec3 cold, vec3 swamp, vec3 mushroom,
					  vec3 savanna){
	vec3 weatherCol = rain;
	float weatherweight = isCold + isDesert + isMesa + isSwamp + isMushroom + isSavanna;
	if (weatherweight < 0.001) return weatherCol + vec3(0.0001);
	else{
		vec3 weatherColB = cold  * isCold  + desert   * isDesert   + mesa    * isMesa   +
					       swamp * isSwamp + mushroom * isMushroom + savanna * isSavanna;
		return mix(weatherCol, weatherColB / weatherweight, weatherweight) + vec3(0.0001);
	}
}

vec3 weatherCol = CalcWeatherColor(weatherRain, weatherCold, weatherDesert, weatherBadlands,
								   weatherSwamp, weatherMushroom, weatherSavanna);
vec3 weatherIntensity = CalcWeatherColor(vec3(WEATHER_RI), vec3(WEATHER_DI), vec3(WEATHER_BI),
										 vec3(WEATHER_CI), vec3(WEATHER_SI), vec3(WEATHER_MI),
										 vec3(WEATHER_VI));
#else
vec3 weatherCol = vec3(WEATHER_RR, WEATHER_RG, WEATHER_RB) * WEATHER_RI / 255.0;
vec3 weatherIntensity = vec3(WEATHER_RI);
#endif

float mefade = 1.0 - clamp(abs(timeAngle - 0.5) * 8.0 - 1.5, 0.0, 1.0);
float dfade = 1.0 - timeBrightness;

vec3 CalcLightColor(vec3 morning, vec3 day, vec3 afternoon, vec3 night, vec3 weatherCol){
	vec3 me = mix(morning, afternoon, mefade);
	float dfadeModified = dfade * dfade;
	vec3 dayAll = mix(me, day, 1.0 - dfadeModified * dfadeModified);
	vec3 c = mix(night, dayAll, sunVisibility);
	c = mix(c, dot(c, vec3(0.299, 0.587, 0.114)) * weatherCol, rainStrength*0.6);
	return c * c;
}

vec3 lightCol   = CalcLightColor(lightMorning,   lightDay,   lightEvening,   lightNight,
								 weatherCol * (screenBrightness*0.1 + 0.9));
vec3 ambientCol = CalcLightColor(ambientMorning, ambientDay, ambientEvening, ambientNight,
								 weatherCol * (screenBrightness*0.1 + 0.9));
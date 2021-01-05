vec3 SunGlare(vec3 color, vec3 nViewPos, vec3 lightCol){
	float cosS = dot(nViewPos, lightVec);
	float visfactor = 0.05 * (3.0 * rainStrength + 1.0);
	float invvisfactor = 1.0 - visfactor;

	float visibility = clamp(cosS * 0.5 + 0.5, 0.0, 1.0);
    visibility = visfactor / (1.0 - invvisfactor * visibility) - visfactor;
	visibility = clamp(visibility * 1.015 / invvisfactor - 0.015, 0.0, 1.0);
	visibility = mix(1.0, visibility, 0.25 * eBS + 0.75);

	color += 0.1 * SUN_GLARE_STRENGTH * lightCol * visibility * shadowFade * (1 - rainStrength) * sunVisibility;
	
	return color;
}
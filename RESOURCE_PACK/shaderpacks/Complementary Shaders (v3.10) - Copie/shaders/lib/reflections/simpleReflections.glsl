void SimpleReflection(vec3 viewPos, vec3 normal, float dither, inout vec4 reflection, inout float skyRefCheck) {
	vec4 pos = vec4(0.0);

    Raytrace(depthtex1, viewPos, normal, dither, pos, skyRefCheck);

	float border = clamp(1.0 - pow(cdist(pos.st), 50.0), 0.0, 1.0);
	
	if (pos.z < 1.0 - 1e-5){
		reflection.a = texture2D(gaux2, pos.st).a;
		if (reflection.a > 0.001) reflection.rgb = texture2D(gaux2, pos.st).rgb;
		
		reflection.a *= border;
	}
}
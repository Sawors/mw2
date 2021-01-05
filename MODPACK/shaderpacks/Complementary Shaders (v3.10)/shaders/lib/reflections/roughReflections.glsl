vec4 RoughReflection(vec3 viewPos, vec3 normal, float dither, float smoothness, sampler2D colortex) {
    vec4 color = vec4(0.0);

    vec4 pos = Raytrace(depthtex0, viewPos, normal, dither);
	float border = clamp(1.0 - pow(cdist(pos.st), 50.0 * sqrt(smoothness)), 0.0, 1.0);
	
	if (pos.z < 1.0 - 1e-5) {
		#ifdef REFLECTION_ROUGH
			float dist = 1.0 - exp(-0.125 * (1.0 - smoothness) * pos.a);
			float lod = log2(viewHeight / 8.0 * (1.0 - smoothness) * dist) * 0.35;
		#else
			float lod = 0.0;
		#endif

		if (lod < 1.0) {
			color.a = texture2DLod(colortex6, pos.st, 1.0).b;
			if (color.a > 0.1) color.rgb = texture2DLod(colortex, pos.st, 0.0).rgb;
		} else {
			float alpha = texture2DLod(colortex6, pos.st, lod).b;
			if (alpha > 0.1) {
				color.rgb += texture2DLod(colortex, pos.st, max(lod - 1.0, 0.0)).rgb;
				color.a += alpha;
			}
		}
		
		color *= color.a;
		color.a *= border;
	}
	
    return color;
}
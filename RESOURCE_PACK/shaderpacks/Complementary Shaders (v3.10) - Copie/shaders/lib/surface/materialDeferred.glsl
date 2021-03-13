void GetMaterials(out float materialFormat, out float smoothness, out float metalness, out float f0, 
                  out vec3 normal, out vec3 spec, vec2 coord){
    vec2 specularData = texture2D(colortex3, coord).rg;

	materialFormat = 0.0;
	vec3 materialFormatSource = texture2D(colortex5, coord).rgb;
	if (materialFormatSource.b > 0.75) materialFormat = 1.0;

	if (materialFormat > 0.9) {
		smoothness = specularData.r;
		metalness = specularData.g;
		f0 = 0.78 * metalness + 0.02;
	} else {
		#if MATERIAL_FORMAT == 0
		smoothness = specularData.r;
		f0 = specularData.g;
		metalness = f0 >= 0.9 ? 1.0 : 0.0;
		#else
		smoothness = specularData.r;
		metalness = specularData.g;
		f0 = 0.78 * metalness + 0.02;
		#endif
	}

	normal = DecodeNormal(texture2D(colortex6, coord).xy);

	spec = texture2D(colortex7, coord).rgb;
}
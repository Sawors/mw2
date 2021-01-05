void GetMaterials(out float materialFormat, out float smoothness, out float metalness, out float f0, out float metalData, 
                  inout float emissive, out float ao, out float scattering, out vec3 normalMap, out vec3 roughMap,
                  vec2 newCoord, vec2 dcdx, vec2 dcdy){
	#if defined WRONG_MIPMAP_FIX
   		vec4 specularMap = texture2DLod(specular, newCoord, 0.0);
	#else
   		vec4 specularMap = texture2D(specular, newCoord);
	#endif
	normalMap = texture2DGradARB(normals, newCoord, dcdx, dcdy).xyz;
	
	vec3 normalMapCheck = normalMap;
	#ifdef FORCE_EMINPBR
		normalMapCheck = vec3(1.0);
	#endif

	if (normalMapCheck == vec3(1.0)) {
		materialFormat = 1.0;
	
		smoothness = specularMap.r;
		
		metalness = specularMap.g;
		f0 = 0.78 * metalness + 0.02;
		metalData = metalness;

		emissive = mix(specularMap.b, 1.0, emissive);
		ao = 1.0;

		ao = specularMap.a < 1.0 ? specularMap.a : 1.0;
		ao = ao > 0.000001 ? (ao < 1.0 ? pow(ao, 8) : 1.0) : 1.0;
		
		#ifndef FORCE_EMINPBR	
			#if defined REFLECTION_ROUGH && !defined GBUFFERS_WATER
				float metalFactor = 1.0;
				if (specularMap.g == 1.0) metalFactor = 2.0;
				normalMap = vec3(0.5, 0.5, 1.0) * 2.0 - 1.0;
				roughMap = texture2D(depthtex0, newCoord*2048).xyz;
				roughMap = roughMap + vec3(0.5, 0.5, 0.0);
				float factoredSmoothness = min(smoothness*pow(metalFactor, 0.5), 1.0);
				roughMap = pow(roughMap, vec3(0.25)*pow((1-factoredSmoothness), 2));
				roughMap = roughMap - vec3(0.5, 0.5, 0.0);
				roughMap = roughMap * 2.0 - 1.0;
			#else
				normalMap = vec3(0.5, 0.5, 1.0) * 2.0 - 1.0;
				roughMap = normalMap;
			#endif
		#else
			#if defined REFLECTION_ROUGH && !defined GBUFFERS_WATER
				normalMap += vec3(0.5, 0.5, 0.0);
				normalMap = pow(normalMap, vec3(NORMAL_MULTIPLIER));
				normalMap -= vec3(0.5, 0.5, 0.0);
				
				roughMap = texture2D(depthtex0, newCoord*2048).xyz;
				roughMap = roughMap + vec3(0.5, 0.5, 0.0);
				roughMap = pow(roughMap, vec3(0.125)*pow((1-smoothness), 2));
				roughMap = roughMap - vec3(0.5, 0.5, 0.0);
				roughMap = roughMap * (normalMap + vec3(0.5, 0.5, 0.0));
				normalMap = normalMap * 2.0 - 1.0;
				roughMap = roughMap * 2.0 - 1.0;
			#else
				normalMap = normalMap * 2.0 - 1.0;
				roughMap = normalMap;
			#endif
		#endif
	} else {
		materialFormat = 0.0;

		normalMap += vec3(0.5, 0.5, 0.0);
		normalMap = pow(normalMap, vec3(NORMAL_MULTIPLIER));
		normalMap -= vec3(0.5, 0.5, 0.0);
		
		#if MATERIAL_FORMAT == -1
			smoothness = specularMap.r;
			
			metalness = specularMap.g;
			f0 = 0.78 * metalness + 0.02;
			metalData = metalness;

			emissive = mix(specularMap.b, 1.0, emissive);
			ao = 1.0;

			#if defined REFLECTION_ROUGH && !defined GBUFFERS_WATER
				roughMap = texture2D(depthtex0, newCoord*2048).xyz;
				roughMap = roughMap + vec3(0.5, 0.5, 0.0);
				roughMap = pow(roughMap, vec3(0.125)*pow((1-smoothness), 2));
				roughMap = roughMap - vec3(0.5, 0.5, 0.0);
				roughMap = roughMap * (normalMap + vec3(0.5, 0.5, 0.0));
				normalMap = normalMap * 2.0 - 1.0;
				roughMap = roughMap * 2.0 - 1.0;
			#else
				normalMap = normalMap * 2.0 - 1.0;
				roughMap = normalMap;
			#endif
		#endif

		#if MATERIAL_FORMAT > -1
			smoothness = specularMap.r;

			f0 = specularMap.g;
			metalness = f0 >= 0.9 ? 1.0 : 0.0;
			metalData = f0;
			
			ao = texture2DGradARB(normals, newCoord, dcdx, dcdy).z;
			ao *= ao;
			float aoLightFactor = 1.0 - min(lmCoord.x + lmCoord.y, 1.0);
			if (aoLightFactor > 0.0) ao = pow(ao, aoLightFactor*aoLightFactor);
			else ao = 1.0;

			scattering = specularMap.b > 0.253 ? (specularMap.b - 0.253) * 1.33 : 0.0;

			emissive = mix(specularMap.a < 1.0 ? specularMap.a : 0.0, 1.0, emissive);
			
			#if defined REFLECTION_ROUGH && !defined GBUFFERS_WATER
				roughMap = texture2D(depthtex0, newCoord*2048).xyz;
				roughMap = roughMap + vec3(0.5, 0.5, 0.0);
				roughMap = pow(roughMap, vec3(0.125)*pow((1-smoothness), 2));
				roughMap = roughMap - vec3(0.5, 0.5, 0.0);
				roughMap = roughMap * (normalMap + vec3(0.5, 0.5, 0.0));
				normalMap = normalMap * 2.0 - 1.0;
				float normalCheck = normalMap.x + normalMap.y;
				if (normalCheck > -1.999){
					if (length(normalMap.xy) > 1.0) normalMap.xy = normalize(normalMap.xy);
					normalMap.z = sqrt(1.0 - dot(normalMap.xy, normalMap.xy));
					normalMap = normalize(clamp(normalMap, vec3(-1.0), vec3(1.0)));
				}else{
					normalMap = vec3(0.0, 0.0, 1.0);
					ao = 1.0;
				}
				roughMap = roughMap * 2.0 - 1.0;
			#else
				normalMap = normalMap * 2.0 - 1.0;
				float normalCheck = normalMap.x + normalMap.y;
				if (normalCheck > -1.999){
					if (length(normalMap.xy) > 1.0) normalMap.xy = normalize(normalMap.xy);
					normalMap.z = sqrt(1.0 - dot(normalMap.xy, normalMap.xy));
					normalMap = normalize(clamp(normalMap, vec3(-1.0), vec3(1.0)));
				}else{
					normalMap = vec3(0.0, 0.0, 1.0);
					ao = 1.0;
				}
				roughMap = normalMap;
			#endif
		#endif
	}	
	#ifdef COMPATIBILITY_MODE
		emissive *= 0.25;
	#endif
	
	emissive *= EMISSIVE_MULTIPLIER;
	
	ao = clamp(ao, 0.01, 1.0);
}
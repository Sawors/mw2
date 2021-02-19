/* MakeUp Ultra Fast - gbuffers_entities.vsh
Config variables

Javier Garduño - GNU Lesser General Public License v3.0
*/

// Useful entities
#define ENTITY_SMALLGRASS   10031.0  // Normal grass like entities
#define ENTITY_LOWERGRASS   10175.0  // Lower half only
#define ENTITY_UPPERGRASS   10176.0  // Upper half only
#define ENTITY_SMALLENTS    10059.0  // Crops like entities
#define ENTITY_SMALLENTS_NW 10032.0  // No waveable small ents
#define ENTITY_LEAVES       10018.0  // Leaves
#define ENTITY_VINES        10106.0  // Vines
#define ENTITY_MAGMA        10213.0  // Emissors like magma
#define ENTITY_EMISSIVE     10089.0  // Emissors like candels and others
#define ENTITY_WATER        10008.0  // Water
#define ENTITY_PORTAL       10090.0  // Portal
#define ENTITY_STAINED      10079.0  // Glass

// Other constants
#define HI_SKY_RAIN_COLOR vec3(.7, .85, 1.0)
#define LOW_SKY_RAIN_COLOR vec3(.7, .85, 1.0)

// Options
#define REFLECTION_SLIDER 2 // [0 1 2] Reflection quality

#if REFLECTION_SLIDER == 0
  #define REFLECTION 0
  #define SSR_TYPE 0
#elif REFLECTION_SLIDER == 1
  #define REFLECTION 1
  #define SSR_TYPE 0
#elif REFLECTION_SLIDER == 2
  #define REFLECTION 1
  #define SSR_TYPE 1
#endif

#define ACERCADE 0 // [0] //
#define WAVING 1 // [0 1] Waving entities
#define TINTED_WATER 1  // [0 1] Use the resource pack color for water.
#define REFRACTION 1  // [0 1] Activate refractions.
#define DOF 0  // [0 1] Enables depth of field. High performance cost.
#define DOF_STRENGTH 0.03  // [0.01 0.02 0.03 0.04 0.05 0.06]  Depth of field strenght.
#define DOF_SAMPLES_FACTOR 1.4 // [1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0]  DoF Quality. Lower values are suitable when TAA is active. High performance cost.
#define AO 1  // [0 1] Turn on for enhanced ambient occlusion (medium performance impact).
#define AOSTEPS 6 // [6 10 14 18 22] How many samples are taken. High performance cost.
#define AO_STRENGHT 0.5 // [0.2 0.3 0.4 0.5 0.6] Ambient oclusion strenght
#define AA_TYPE 1 // [0 1] Fast TAA - Enable antialiasing (Recommended). No - Disable antialiasing. Some efects looks noisy.
#define MOTION_BLUR 0 // [0 1] Turn on motion blur
#define MOTION_BLUR_STRENGTH 0.12 // [0.02 0.04 0.06 0.08 0.10 0.12 0.14 0.16 0.18 0.20] Set Motion blur strength. Lower framerate -> Lower strength and vice versa is recommended.
#define SUN_REFLECTION 1 // [0 1] Set sun (or moon) reflection on water and glass
#define SHADOW_CASTING 1 // [0 1] Activate shadows
#define SHADOW_RES 2 // [0 1 2 3 4 5] Set shadow quality
#define SHADOW_TYPE 1 // [0 1] Sets the shadow type
#define SHADOW_BLUR 2.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]  Shadow blur intensity
#define OMNI_TINT 0.50 // [0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90] Tint of omnidirectional light. From sky color to direct light color.
#define WATER_TINT 0.8 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]  Water tint percentage
#define COLOR_SCHEME 1 // [0 1 2] Legacy: Exotic colors at sunset. Cocoa: A warm preset of vivid colors in the day. Captain: A cold preset of stylish colors
#define WATER_TEXTURE 1 // [0 1] Enable or disable resource pack water texture.
#define AVOID_DARK 1 // [0 1] Avoid absolute darkness in caves at daytime
#define V_CLOUDS 1 // [0 1] Set clouds type

// Reflection parameters
#define RAY_STEP 0.25
#define RAYMARCH_STEPS 11
#define RAYSEARCH_STEPS 4

// Cloud parameters
#define CLOUD_PLANE_SUP 920.0
#define CLOUD_PLANE_CENTER 620.0
#define CLOUD_PLANE 520.0
#define CLOUD_STEPS 18

// Buffers clear
const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex2Clear = false;
const bool colortex3Clear = false;
const bool gaux1Clear = false;
const bool colortex5Clear = false;
const bool gaux3Clear = false;

// Sun rotation angle
const float sunPathRotation = -25.0;

// Shadow parameters
const float shadowIntervalSize = 4.0;
const bool generateShadowMipmap = false;
const bool generateShadowColorMipmap = false;
#ifndef NO_SHADOWS
  #if SHADOW_RES == 0
    const int shadowMapResolution = 256;
    const float shadowDistance = 70.0;
    #define SHADOW_DIST 0.77
  #elif SHADOW_RES == 1
  const int shadowMapResolution = 512;
  const float shadowDistance = 128.0;
  #define SHADOW_DIST 0.75
  #elif SHADOW_RES == 2
    const int shadowMapResolution = 512;
    const float shadowDistance = 70.0;
    #define SHADOW_DIST 0.77
  #elif SHADOW_RES == 3
    const int shadowMapResolution = 1024;
    const float shadowDistance = 128.0;
    #define SHADOW_DIST 0.8
  #elif SHADOW_RES == 4
    const int shadowMapResolution = 1024;
    const float shadowDistance = 79.0;
    #define SHADOW_DIST 0.8
  #elif SHADOW_RES == 5
    const int shadowMapResolution = 2048;
    const float shadowDistance = 158.0;
    #define SHADOW_DIST 0.85
  #endif
  const float shadowDistanceRenderMul = 1.0;
  const bool shadowHardwareFiltering1 = true;

  #if SHADOW_TYPE == 0
    const bool shadowtex1Nearest = true;
  #elif SHADOW_TYPE == 1
    const bool shadowtex1Nearest = false;
  #endif
#endif

// Redefined constants
#if AO == 0
  const float ambientOcclusionLevel = 1.0;
#else
  const float ambientOcclusionLevel = 0.5;
#endif

const float eyeBrightnessHalflife = 6.0;
const float centerDepthHalflife = 1.0;

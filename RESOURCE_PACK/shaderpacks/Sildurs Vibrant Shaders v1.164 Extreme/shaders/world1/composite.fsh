#version 120

/* Sildur's basic shaders */
/* read the permission in my thread before editing, thank you */

/*--------------------
//ADJUSTABLE VARIABLES//
---------------------*/

const float	sunPathRotation	= -40.0f;			//Set me to 0 if you want the normal Minecraft sun/moon angle!
const float	ambientOcclusionLevel = 1.0f;		// 1.0 is the default occlusion level of minecraft

/*---------------------------
//END OF ADJUSTABLE VARIABLES//
----------------------------*/

uniform sampler2D gcolor;
uniform sampler2D gdepth;

varying vec4 texcoord;

void main() {
	gl_FragData[0] = texture2D(gcolor, texcoord.st);
	gl_FragData[1] = texture2D(gdepth, texcoord.st);
	gl_FragData[3] = vec4(texture2D(gcolor, texcoord.st).rgb, 1.0);
}

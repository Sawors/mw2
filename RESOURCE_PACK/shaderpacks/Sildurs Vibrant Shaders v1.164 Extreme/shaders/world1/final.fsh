#version 120
/*
                            _____ _____ ___________ 
                           /  ___|_   _|  _  | ___ \
                           \ `--.  | | | | | | |_/ /
                            `--. \ | | | | | |  __/ 
                           /\__/ / | | \ \_/ / |    
                           \____/  \_/  \___/\_|
						Before editing anything here make sure you've 
						read The agreement, which you accepted by downloading
						my shaderpack. The agreement can be found here:
			http://www.minecraftforum.net/topic/1953873-164-172-sildurs-shaders-pcmacintel/
						   
				This code is from Chocapic13' shaders adapted, modified and tweaked by Sildur 
		http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/1293898-chocapic13s-shaders			
*/

varying vec4 texcoord;
uniform sampler2D composite;

void main() {
	vec4 color = texture2D(composite, texcoord.st);
	
	color.r = (color.r*1.34)+(color.b+color.g)*(-0.1);
    color.g = (color.g*1.2)+(color.r+color.b)*(-0.1);
    color.b = (color.b*1.1)+(color.r+color.g)*(-0.1);
	color = color / (color + 2.2) * (1.0+2.0);
	
	gl_FragColor = color;	
}
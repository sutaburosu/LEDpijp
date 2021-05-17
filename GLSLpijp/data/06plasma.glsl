// http://glslsandbox.com/e#66412.3

#ifdef GL_ES
precision mediump float;
#endif

// #extension GL_OES_standard_derivatives : enable

//Made By Deleteboys
//+=dipfshit
// += toss

uniform float time;
uniform vec2 mouse;
uniform vec2 resolution;


vec3 hsv2rgb(  vec3 c )
{
 vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );
rgb = rgb*rgb*(3.0-2.0*rgb);
 return c.z * mix( vec3(1.0), rgb, c.y);
}

void main( void ) {

	vec2 position = ( gl_FragCoord.xy / resolution.xy ) / 4;
	position -= sin(time*0.05)*5.0;
	position*=.15;
	position.y = dot(position,position);
	position-=0.5;

	vec3 color = vec3(0.1, 0.1, 0.1);
	position.x = dot(position,position);
	position.y = mix(position.y,dot(sin(position*70.),cos(position*30.+time)),sin(position.y*24.0+time/5.));
	
	color = hsv2rgb(vec3(sin(time+position.y*4.0+position.x*2.0) * 0.3 + position.x*length(position*6.0), .75,1.));

	gl_FragColor = vec4(color,1.0);
}
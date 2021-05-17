// http://glslsandbox.com/e#66417.0

/*
 * Original shader from: https://www.shadertoy.com/view/WdV3DW
 */

#ifdef GL_ES
precision mediump float;
#endif

// glslsandbox uniforms
uniform float time;
uniform vec2 resolution;

// shadertoy emulation
#define iTime time
#define iResolution resolution

// --------[ Original ShaderToy begins here ]---------- //
//Base values modified with depth later
float intensity = 1.0;
float radius = 0.1;

//Distance functions from 
//https://www.iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float triangleDist(vec2 p){ 
    const float k = sqrt(3.0);
    p.x = abs(p.x) - 1.0;
    p.y = p.y + 1.0/k;
    if( p.x+k*p.y>0.0 ) p=vec2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0, 0.0 );
    return -length(p)*sign(p.y);
}

float boxDist(vec2 p){
    vec2 d = abs(p)-1.0;
    return length(max(d,vec2(0))) + min(max(d.x,d.y),0.0);
}

float circleDist( vec2 p){
  return length(p) - 1.0;
}

//https://www.shadertoy.com/view/3s3GDn
float getGlow(float dist, float radius, float intensity){
    return pow(radius/dist, intensity);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    
	vec2 uv = fragCoord/iResolution.xy;
    float widthHeightRatio = iResolution.x/iResolution.y;
    vec2 centre;
    vec2 pos;
	
    float t = iTime * 0.01;
    
    float dist;
    float glow;
    vec3 col = vec3(0);
    
    //The spacing between shapes
    const float scale = 300.0;
    //Number of shapes
    const float layers = 32.0;
    
    float depth;
    vec2 bend;
    
    const vec3 purple = vec3(0.611, 0.129, 0.909);
    const vec3 green = vec3(0.133, 0.62, 0.698);
    
    float angle;
    float rotationAngle;
    mat2 rotation;
    
    //For movement of the anchor point in time
    float d = 2.5*(sin(t) + sin(3.0*t));

    //Create an out of frame anchor point where all shapes converge to    
    //vec2 anchor = vec2(0.5 + cos(d), 0.5 + sin(d));
    vec2 anchor = vec2(0.5);
	
    //Create light purple glow at the anchor loaction
    pos = anchor - uv;
    pos.y /= widthHeightRatio;
    dist = length(pos);
    glow = getGlow(dist, 0.35, 1.9);
    //col += glow * vec3(0.7,0.6,1.0);
    
	for(float i = 0.0; i < layers; i++){
        
        //Time varying depth information depending on layer
        depth = fract(i/layers + t);

        //Move the focus of the camera in a circle
        //centre = vec2(0.5 + 0.2 * sin(t), 0.5 + 0.2 * cos(t));
        centre = vec2(0.5);
        //Position shapes between the anchor and the camera focus based on depth
        bend = mix(anchor, centre, depth);
     	
        pos = bend - uv;
    	pos.y /= widthHeightRatio;

        //Rotate shapes
       	rotationAngle = 3.14 * sin(depth + fract(t) * 6.28) + i;
        rotation = mat2(cos(rotationAngle), -sin(rotationAngle), 
                        sin(rotationAngle),  cos(rotationAngle));
        
        pos *= rotation;
        
        //Position shapes according to depth
    	pos *= mix(scale, 0.0, depth);
    	
        float m = mod(i, 3.0);
        if(m == 0.0){
        	dist = abs(boxDist(pos));
        }else if(m == 1.0){
        	dist = abs(triangleDist(pos));
        }else{
        	dist = abs(circleDist(pos));
        }
       
        //Get glow from base radius and intensity modified by depth
    	glow = getGlow(dist, radius+(1.0-depth)*2.0, intensity + depth);
        
        //Find angle along shape and map from [-PI; PI] to [0; 1]
        angle = (atan(pos.y, pos.x)+3.14)/6.28;
        //Shift angle depending on layer and map to [1...0...1]
		angle = abs((2.0*fract(angle + i/layers)) - 1.0);
        
        //White core
    	col += 10.0*vec3(smoothstep(0.03, 0.02, dist));
        
        //Glow according to angle value
     	col += glow * mix(green, purple, angle);
	}
    
    //Tone mapping
    col = 1.0 - exp(-col);
    
    //Output to screen
    fragColor = vec4(col,1.0);
}
// --------[ Original ShaderToy ends here ]---------- //

void main(void)
{
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
// http://glslsandbox.com/e#66495.0

#define ZOOM 2

/*
 * Original shader from: https://www.shadertoy.com/view/WlsBR8
 */

#ifdef GL_ES
precision mediump float;
#endif

// glslsandbox uniforms
uniform float time;
uniform vec2 resolution;
// varying vec2 surfacePosition;

// shadertoy emulation
#define iTime 1.0
//cos(dot(surfacePosition,surfacePosition))
#define iResolution resolution

// Emulate a black texture
#define sampler2D float
#define iChannel1 0.
#define texture(s, uv) vec4(0.0)

// --------[ Original ShaderToy begins here ]---------- //
/**
	Gyroid Tunnel Thing
	Just some playing with the base
	of my asteroid shader 
	https://www.shadertoy.com/view/WtfyDX

	also wanted a break from hexagon truchets
*/

#define MAX_DIST 	100.
#define PI  		3.1415926
#define R 			iResolution
#define T 			iTime
#define S			smoothstep

#define r2(a)  mat2(cos(a), sin(a), -sin(a), cos(a))
#define hash(a, b) fract(sin(a*1.2664745 + b*.9560333 + 3.) * 14958.5453)

// gyroid function
float sdGry(vec3 p, float s, float t, float b) {
    p *=s;
   	float g = abs(dot(sin(p), cos(p.zxy))-b)/(s)-t;
    return g;
}

//global vars cause its just a demo
float g1,g2,g3,g4,g5;
vec3 hitPoint;
vec2 map(vec3 p) {
    vec2 res=vec2(1000.,1.);
    p.xy*=r2(T*.009);
    p +=vec3(-.05,-.2,iTime*.1);
    // sdGry(p, thickness, scale, offset) / sdf focus 
   // p = twist(p);
	g1 =  sdGry(p, 8.,  .025,  1.05);
    g2 = sdGry(p, 24., .025, .75);
    g3 = sdGry(p, 54., .01, .25);
    g1 -= (g2 *.85);

    hitPoint =p;
    res.x = g1/1.75;
    return res;
}

vec3 get_normal(in vec3 p, in float t) {
    t *= 0.001;
	vec2 eps = vec2(t, 0.0);
	vec3 n = vec3(
	    map(p+eps.xyy).x - map(p-eps.xyy).x,
	    map(p+eps.yxy).x - map(p-eps.yxy).x,
	    map(p+eps.yyx).x - map(p-eps.yyx).x);
	return normalize(n);
}

vec2 ray_march( in vec3 ro, in vec3 rd, int x) {
    float t = 0.0001;
    float m = 0.;
    for( int i=0; i<128; i++ ) {
        vec2 d = map(ro + rd * t);
        m = d.y;
        if(d.x<.0001*t||t>MAX_DIST) break;
        t += d.x*.6;
    }
    return vec2(t,m);
}

float get_diff(in vec3 p, in vec3 lpos, in vec3 n) {
    vec3 l = normalize(lpos-p);
    float dif = clamp(dot(n,l),0. , 1.),
          shadow = ray_march(p + n * .0001 * 2., l,128).x;
    if(shadow < length(lpos-p)) dif *= .4;
    return dif;
}

// Tri-Planar blending function. Ryan Geiss
// https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch01.html
vec3 tex3D(sampler2D t, in vec3 p, in vec3 n ){
//return n*n*fract(dot(p,p));
    n = max(abs(n), 0.001);
    n /= dot(n, vec3(1));
	vec3 tx = texture(t, p.yz).xyz,
         ty = texture(t, p.zx).xyz,
         tz = texture(t, p.xy).xyz;
    return (tx*tx*n.x + ty*ty*n.y + tz*tz*n.z);
}

vec3 get_hue(float qp) {
   return (.5 + .45*cos(qp + vec3(2, 1, .5)));
}

vec3 tone1 = (.5 + .45*cos(13.72 + vec3(2, 1, .5)));
vec3 tone2 = (.5 + .45*cos(11.5 + vec3(2, 1, .5)));

vec3 get_color(vec3 p, vec3 n) {
    vec3 col = vec3(0.);
    vec3 dif = tone1 * tex3D(iChannel1,hitPoint*4.,n).g; 
	float bbd = abs(abs(g3-.005)-.0025); //b2m
    bbd = abs(bbd-.015);
    float cks1 = S(.01,.011,bbd)*.25;
    float cks2 = S(-.02,-.03,g2)*2.;
    
    vec3 mate = .5 + .45*cos(hitPoint.z*8.25 + vec3(2, 1, .5));
    col += mate*cks1+cks2;   
    return col + dif;
}

vec3 fog (in float t, in float d, in vec3 c) {
    return mix( c, tone2, 1.-exp(-d*t*t*t));
}

vec3 r( in vec3 ro, in vec3 rd, in vec2 uv) {
    vec3 c = vec3(0.);
    vec2 ray = ray_march(ro, rd, 128);

    float t = ray.x;
    float m = ray.y;
    if(t<MAX_DIST) {
		vec3 p = ro + t * rd,
             n = get_normal(p, t);
        float diff = n.x*.5+.5;
        if(ray.y == 1.){
         	c += diff * get_color(p, n);  
        }

        vec2 ref;
        vec3 rr=reflect(rd,n),
             fc=vec3(0.);

        c = fog(t,.07,c);
    } 
    return c;
}

// ACES tone mapping from HDR to LDR
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 ACESFilm(vec3 x) {
    float a = 2.51,
          b = 0.03,
          c = 2.43,
          d = 0.59,
          e = 0.14;
    return clamp((x*(a*x + b)) / (x*(c*x + d) + e), 0.0, 1.0);
}

void mainImage( out vec4 O, in vec2 F ) {
    vec2 U = (2.*F.xy-R.xy)/max(R.x * ZOOM ,R.y * ZOOM);

    vec3 ro = vec3(0.,.0,-time/2.),
         lp = vec3(0.,.0,0.);
		
    vec3 cf = normalize(lp+ro),
     	 cp = vec3(0.,1.,0.),
     	 cr = normalize(cross(cp, cf)),
     	 cu = normalize(cross(cf, cr)),
     	 c = ro + cf * 1.,
     	 i = c + U.x * cr + U.y * cu,
     	 rd = i-ro;
    
    vec3 C = r(ro, rd, U);
    C = ACESFilm(C);
    O = vec4(pow(C, vec3(0.4545)),1.0);
}


void mainVR( out vec4 O, in vec2 F, in vec3 fragRayOri, in vec3 fragRayDir ) {
    /** normalizing center coords */
  	vec2 U = (2.*F.xy-R.xy)/
        max(R.x * ZOOM, R.y * ZOOM);

    
    vec3 ro = fragRayOri;
    vec3 rd = fragRayDir;

    vec3 C = r(ro, rd, U);
    C = ACESFilm(C);
    O = vec4(pow(C, vec3(0.4545)),1.0);

}
// --------[ Original ShaderToy ends here ]---------- //

void main(void)
{
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
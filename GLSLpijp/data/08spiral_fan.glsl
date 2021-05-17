// http://glslsandbox.com/e#66264.0

#define ZOOM 1.5

/*
 * Original shader from: https://www.shadertoy.com/view/wtByWK
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


float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float swirl(vec2 coord)
{
    float l = length(coord) / iResolution.x;
    float phi = atan(coord.y, coord.x + 1e-6);
    return sin(l * 21.0 + phi * 5.0 - iTime * 4.0) * 0.5 + 0.5;
}

float halftone(vec2 coord, float size, vec2 offs)
{
    vec2 uv = coord / size;
    vec2 ip = floor(uv) + offs; // column, row
    vec2 odd = vec2(0.5 * mod(ip.y, 2.0), 0.0); // odd line offset
    vec2 cp = floor(uv - odd + offs) + odd; // dot center
    float d = length(uv - cp - 0.5) * size; // distance
    float r = swirl(cp * size) * size * 0.6; // dot radius
    return max(0.0, d - r);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 coord = fragCoord.xy - iResolution.xy * 0.5;
    float size = iResolution.x / (30.0 + sin(iTime * 0.5) * 20.0);
    float k = size / 4.0 * ZOOM;

    float d =   halftone(coord, size, vec2(-0.5, -1));
    d = smin(d, halftone(coord, size, vec2( 0.5, -1)), k);
    d = smin(d, halftone(coord, size, vec2(-1.0,  0)), k);
    d = smin(d, halftone(coord, size, vec2( 0.0,  0)), k);
    d = smin(d, halftone(coord, size, vec2( 1.0,  0)), k);
    d = smin(d, halftone(coord, size, vec2(-0.5,  1)), k);
    d = smin(d, halftone(coord, size, vec2( 0.5,  1)), k);

    fragColor = vec4(d, d, d, 1);
}


// --------[ Original ShaderToy ends here ]---------- //

void main(void)
{
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
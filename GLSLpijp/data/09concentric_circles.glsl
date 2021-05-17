// http://glslsandbox.com/e#66262.0

/*
 * Original shader from: https://www.shadertoy.com/view/ttByWK
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
float saturate(float x) { return clamp(x, 0.0, 1.0); }

float rand(vec2 uv)
{
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 palette(float z)
{
    float g = 0.6 + 0.4 * sin(z * 8.0 + iTime * 2.0);
    float b = 0.5 + 0.4 * sin(z * 5.0 + iTime * 3.0);
    return vec3(1.0, g, b);
}



void mainImage( out vec4 fragColor, in vec2 fragCoord )    
{
    float scale = iResolution.y / 1.0;
    vec2 p = fragCoord.xy / scale;

    vec2 offs1 = vec2(iTime * 0.53, sin(iTime * 1.35) * 0.2);
    vec2 offs2 = vec2(iTime * 0.81, sin(iTime * 1.19) * 0.2);

    vec2 p1 = p + offs1;
    vec2 p2 = p + offs2 - 0.5;

    float z1 = rand(0.19 * floor(p1));
    float z2 = rand(0.31 * floor(p2));

    p1 = fract(p1) - 0.5;
    p2 = fract(p2) - 0.5;

    float s1 = 0.6 + sin(iTime * (0.6 + z1)) * 0.4;
    float s2 = 0.9 + sin(iTime * (0.6 + z2)) * 0.6;

    float d1 = (0.25 - abs(0.5 - fract(length(p1) * s1 * 10.0 + 0.26))) / (s1 * 10.0);
    float d2 = (0.25 - abs(0.5 - fract(length(p2) * s2 * 10.0 + 0.26))) / (s2 * 10.0);

    vec3 c1 = palette(z1) * saturate(d1 * scale);
    vec3 c2 = palette(z2) * saturate(d2 * scale);

    float a1 = saturate((0.5 - length(p1)) * scale);
    float a2 = saturate((0.5 - length(p2)) * scale);

    vec3 c1on2 = mix(c2 * a2, c1, a1);
    vec3 c2on1 = mix(c1 * a1, c2, a2);

    fragColor = vec4(mix(c2on1, c1on2, step(z1, z2)), 1);
}


// --------[ Original ShaderToy ends here ]---------- //

void main(void)
{
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
// http://glslsandbox.com/e#66359.0

#define ZOOM_BASE 4.0
#define ZOOM_SIZE 1.5

/*
 * Original shader from: https://www.shadertoy.com/view/3tlBRn
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
const vec4 iMouse = vec4(0.);

// --------[ Original ShaderToy begins here ]---------- //
#define FAR_PLANE 50.0
#define EPSILON 0.01
#define t iTime

// -----------------------------------------------------------------------------
// Math

#define PI 3.1416
#define HALF_PI PI / 2.0
#define TAU PI * 2.0
#define DEG2RAD TAU/360.

#define S(x, y, z) smoothstep(x, y, z)

mat3 lookAtMatrix(in vec3 lookAtDirection) 
{
	vec3 ww = normalize(lookAtDirection);
    vec3 uu = cross(ww, vec3(0.0, 1.0, 0.0));
    vec3 vv = cross(uu, ww);
    return mat3(uu, vv, -ww);
}

// -----------------------------------------------------------------------------
// Camera

struct Camera {
    vec3 position;
	vec3 direction;
};

Camera createOrbitCamera(vec2 uv, vec2 mouse, vec2 resolution, float fov, vec3 target, float height, float distanceToTarget)
{
    vec2 r = mouse / resolution * vec2(3.0 * PI, 0.5 * PI);
    float halfFov = fov * 0.5;
    float zoom = cos(halfFov) / sin(halfFov);
    
    vec3 position = target + vec3(sin(r.x), 0.0, cos(r.x)) * distanceToTarget + vec3(0, height, 0);
    vec3 direction = normalize(vec3(uv, -zoom));
    direction = lookAtMatrix(target - position) * direction;
    
    return Camera(position, direction);
}

// -----------------------------------------------------------------------------
// Scene

#define SKY 0
#define FLOOR 1
#define GHOST_EYE 2
#define GHOST_PUPIL 3
#define GHOST_BODY1 4
#define GHOST_BODY2 5
#define GHOST_BODY3 6

struct Entity {
    int id;
	float d;
};

Entity emin(Entity a, Entity b)
{
    if (a.d < b.d) return a; return b;
}

Entity emax(Entity a, Entity b)
{
    if (a.d > b.d) return a; return b;
}

float sdSphere(in vec3 p, float radius)
{
    return length(p) - radius;
}

float sdCappedCylinder( vec3 p, float h, float r )
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(h,r);
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdPlane(in vec3 p, float height)
{
    return p.y + height;
}

Entity ghost(in vec3 p, in int bodyId) 
{        
    float rand = float(bodyId * 3);
    vec3 q = p + vec3(0, sin(rand + t * 5.0) * 0.1, 0);
    
    // BODY
    float body = sdCappedCylinder(q - vec3(0.0, -1.0, 0.0), 1.0, 1.0);
    Entity ghost = Entity(bodyId, body);
    float head = sdSphere(q, 1.0);
    ghost.d = min(ghost.d, head);
    
    float bv = 0.5;
    if (ghost.d > bv) {
        ghost.d = ghost.d - bv * 0.5;
        return ghost;
    }
    
    // BODY FLUCTUATION
    float majorModChangeFreq = 5.0;
    float repeat = 6.5;
    float fluctuationHeight = 2.0;
    float fluctuationRaymarchSpeed = 0.5;
    vec2 movement = normalize(vec2(1.0, 1.0)) * 15.0;
    
    float fluctuation = (0.9 + 0.2 * sin(rand + t * majorModChangeFreq))
        	* sin(rand + q.x * repeat + t * movement.x)
            * sin(rand + q.z * repeat + t * movement.y)
         	* fluctuationHeight;
    
    float fluctuationPlane = sdPlane(q, 1.1 - 0.1 * fluctuation) * fluctuationRaymarchSpeed;
    ghost.d = max(ghost.d, -fluctuationPlane);
    
    // EYES
    vec3 eyesCoord = vec3(abs(q.x), q.yz);
    Entity eyes = Entity(GHOST_EYE, sdSphere(eyesCoord - vec3(0.35, 0.2, 0.7), 0.3));
    
    ghost = emin(ghost, eyes);
    
    // PUPILS
    
    Entity pupils = Entity(GHOST_PUPIL, sdSphere(eyesCoord - vec3(0.37, 0.23, 0.82), 0.2));
    ghost = emin(ghost, pupils);
    
    return ghost;
}

Entity scene(in vec3 p)
{
    Entity scene;
    Entity plane = Entity(FLOOR, sdPlane(p, 1.0)); scene = plane;
    Entity ghost1 = ghost(p - vec3(-2.0,  1.0, -1.5), GHOST_BODY1); scene = emin(scene, ghost1);
    Entity ghost2 = ghost(p - vec3(0.0,  1.2,  0.0), GHOST_BODY2); scene = emin(scene, ghost2);
    Entity ghost3 = ghost(p - vec3(2.0, 1.0, -1.5), GHOST_BODY3); scene = emin(scene, ghost3);
    
    return scene;
}

// -----------------------------------------------------------------------------
// Normals

vec3 sceneNormal(in vec3 p)
{
    vec2 offset = vec2(EPSILON, 0);
    float d = scene(p).d;
    return normalize(vec3(
		d - scene(p - offset.xyy).d,
        d - scene(p - offset.yxy).d,
        d - scene(p - offset.yyx).d
    ));
}

// -----------------------------------------------------------------------------
// Shading

float calcAO( in vec3 pos, in vec3 nor ) {
	float occ = 0.0;
    float sca = 1.0;
    for( int i=0; i<5; i++ ) {
        float hr = 0.01 + 0.12*float(i)/4.0;
        vec3 aopos =  nor * hr + pos;
        float dd = scene( aopos ).d;
        occ += -(dd-hr)*sca;
        sca *= 0.95;
    }
    return clamp( 1.0 - 3.0*occ, 0.0, 1.0 ) * (0.5+0.5*nor.y);
}

float traceShadow(in vec3 ro, in vec3 rd, float hardness)
{
    float d = EPSILON * 2.0;
    float k = hardness;
    float res = 1.0;
    
    for (int i=0; i < 128; i++)
    {
        if (d > FAR_PLANE) break;
        vec3 p = ro + rd * d;
        float stepDistance = scene(p).d;
        
        if (stepDistance < EPSILON) return 0.0;
        
        res = min(res, k * stepDistance / d);
        d += stepDistance;
    }
    
    return clamp(res, 0.0, 1.0);
}

vec3 shading(vec3 p, vec3 n, vec3 diffuseColor)
{
    vec3 sunColor = vec3(6.0);
    vec3 sunDirection = normalize(vec3(1.0, 1.0, 1.0));
    
    float shadowOcclusion = traceShadow(p +  n * EPSILON * 2.0, sunDirection, 28.);
    float ao = calcAO(p, n);
    
    vec3 ambientColor = vec3(0.1) * ao;
    vec3 diffuse = clamp(dot(n, sunDirection), 0.0, 1.0) * sunColor;

    return (ambientColor + shadowOcclusion * diffuse) * diffuseColor;
}

vec3 getFloorColor(vec2 uv)
{
    vec3 lineColor = vec3(0.43, 0.0, 0.5);
    vec3 backgroundColor = vec3(0.0005, 0.001, 0.001);
    float lineWidth = 0.25;    
    float tiling = 0.2;
    
    vec2 cellUV = fract(vec2(0.5, t / 2.0) + uv * tiling) * 2.0 - 1.0;
    
    float grid = smoothstep(1.0 - lineWidth, 1.0, max(abs(cellUV.x), abs(cellUV.y)));
    
    float radialGradient = S(10.0, 50.0, length(uv));
    
    return grid * mix(lineColor, backgroundColor, radialGradient) + (1.0 - grid) * backgroundColor; 
}

vec3 getMaterialColor(Entity e, vec3 p, vec3 n)
{
    vec3 topColor = vec3(0.18, 0.05, 0.01);
    vec3 botColor = vec3(0.10, 0.005, 0.001);
    
    vec3 color = vec3(0);
    
    if (e.id == FLOOR)
    {
        color = getFloorColor(p.xz);
    }
    else if (e.id == GHOST_BODY1)
    {
        color = mix(botColor.rbb, topColor.rbb, S(0.0, 1.5, p.y));
    }
    else if (e.id == GHOST_BODY2)
    {
        color = mix(botColor.bgr, topColor.bgr, S(0.0, 1.5, p.y));
    }
    else if (e.id == GHOST_BODY3)
    {
        color = mix(botColor.grb, topColor.grb, S(0.0, 1.5, p.y));
    }
    else if (e.id == GHOST_EYE)
    {
        color = vec3(0.18, 0.18, 0.18);
    }
    else if (e.id == GHOST_PUPIL)
    {
        color = vec3(0.01, 0.01, 0.01);
    }
    
    return shading(p, n, color); 
}

// -----------------------------------------------------------------------------
// Raymarching - SphereTracing

Entity trace(vec3 origin, vec3 direction)
{
    Entity res = Entity(SKY, 0.0);
    
    for (int i = 0; i < 512; i++)
    {
        if (res.d > FAR_PLANE) break;
        vec3 p = origin + direction * res.d;
        Entity closestEntity = scene(p);
        
        res.id = closestEntity.id;
        res.d += closestEntity.d;
        
        if (closestEntity.d < EPSILON) 
        {
            return res;
        }
    }
    
    res.id = SKY;
    res.d = FAR_PLANE;
    return res;
}

// -----------------------------------------------------------------------------
// Main

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;

    float camHeight = 1.0;
    float vFOV = 60.0 * DEG2RAD + cos(iTime) * 10.0 * DEG2RAD;
    float distanceToTarget = ZOOM_BASE + sin(iTime) * ZOOM_SIZE;
    vec3 target = vec3(0, 0.5, 0);
    Camera cam = createOrbitCamera(uv, iMouse.xy, iResolution.xy, vFOV, target, camHeight, distanceToTarget);
    
    vec3 ro = cam.position;
    vec3 rd = cam.direction;
    
    Entity e = trace(ro, rd);
  
    vec3 p = ro + rd * e.d;
    vec3 n = sceneNormal(p);
    
    vec3 col = vec3(0);

    if (e.id == SKY)
    {
        vec3 skyTopColor = vec3(0.05, 0.1, 1.0);
        vec3 skyHorizonColor = vec3(0.7, 0.1, 0.8);
        col = mix(skyTopColor, skyHorizonColor, exp(-8.0*rd.y));
    } else {
        col = getMaterialColor(e, p, n);
    }
    
    fragColor = vec4(col, 1.0);
}
// --------[ Original ShaderToy ends here ]---------- //

void main(void)
{
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
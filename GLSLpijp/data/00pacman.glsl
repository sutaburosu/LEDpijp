/* 
 * Borrowed from: http://glslsandbox.com/e#64375.0
 * Thanks Iñigo.  Or maybe Señor Quilez.
 */

#define ZOOM 1.2

// --------[ Original GLSLsandbox begins here ]-------- //

/*
 * Original shader from: https://www.shadertoy.com/view/XldcRl
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
/*
	First of all I want share a thousand thanks to my namesake Iñigo Quilez for letting everyone enjoy such a nice tool, 
	where one can develop and visualize its own fantasies :)
	
	Warn: This code is a mix from many geniouses that copied others who copied others(nested forever).
	Also pretends to be didactic in a fairly easy way.
	
	Would love mentioning the users Nrx & iquilez as my main influences on this shader(functions, ideas, talent, etc...).
	
	Hope someone enjoys it and why not, copy some aspects if they are deserved! :D
	
	PD: It is highly possible that there are some remains from my own engine, literally unusable here... sorry for it

	Thank you, again, to my love Sara, for ... the other funny point of view!
*/

#ifdef GL_ES
precision mediump float;
#endif

#define MOUSE
#define SHADOW
#define ARMS
#define LEGS

#define CAMERA_FOCAL_LENGTH	2.0

#define RAY_LENGTH_MAX		1000.0
#define RAY_STEP_MAX		1000.0
#define DELTA			0.2
#define DELTA_SEARCH	0.1527

#define NORMAL_DELTA		0.2

#define SHADOW_LENGTH		600.0
#define SHADOW_POWER		1.0
#define SHADOW_DELTA		0.12

#define AMBIENT			0.05

#define GAMMA			1.0

// #define BACKGROUND_COLOR vec3(0.1, 0.3, 0.5)
#define BACKGROUND_COLOR vec3(0.)

// Math constants
#define PI		3.14159265359
#define PI2		6.28318530718

//Config
vec3 pacmanColor = vec3(0.902, 0.8471, 0.102);
vec3 pacmanMat = vec3(1.0,0.1,0.0);
vec3 gloveColor = vec3(1.0,0.545,0.298);
vec3 gloveMat = vec3(5.0,0.3,0.0);
vec3 bootColor = vec3(0.55,0.145,0.1);
vec3 bootMat = vec3(2.0,0.1,0.0);
vec3 bigBiscuitColor = vec3(1.0,0.75,0.15);
vec3 bigBiscuitMat = vec3(30.0,0.5,0.0);
vec3 biscuitColor = vec3(0.9,0.65,0.1);
vec3 biscuitMat = vec3(10.0,0.5,0.0);
// vec3 groundColor = vec3(0.1,0.898,0.545);
// vec3 groundMat = vec3(3.0,0.0,0.0);
vec3 groundColor = vec3(0.);
vec3 groundMat = vec3(3.0,0.0,0.0);
vec3 tongueColor = vec3(0.9,0.1,0.1);
vec3 tongueMat = vec3(10.0,5.0,0.0);
vec3 eyeBallColor = vec3(0.0,0.0,0.0);
vec3 eyeBallMat = vec3(30.0,1.0,0.0);
vec3 eyeBall2Color = vec3(0.5,0.5,1.0);
vec3 eyeBall2Mat = vec3(50.0,3.0,0.0);

//Lighting
vec3 lightDir = normalize(vec3(0.9,0.8,0.2));
vec3 light2Dir = normalize(vec3(-0.9,-0.2,0.8));
float light2Pow = .5;


mat3 rotX(float c, float s)
{ 
    return mat3( 1.0, 0.0, 0.0, 
                0.0, c, s, 
                0.0, -s, c);
}

mat3 rotY(float c, float s)
{ 
    return mat3( c, 0.0,-s, 
                0.0,1.0,0.0, 
                s, 0.0, c);
}

mat3 rotZ(float c, float s)
{ 
    return mat3( c, s, 0.0,
                -s, c, 0.0, 
                0.0, 0.0, 1.0);
}

float smin( float a, float b, float k, float l )
{
	float h = clamp( l + l*(b-a)/k, 0.0, 1.0 );
	return mix( b, a, h ) - k*h*(1.0-h);
}

vec2 smin( vec2 a, vec2 b, float k, float l )
{
	float h = clamp( l + l*(b.x-a.x)/k, 0.0, 1.0 );
	return vec2( mix( b.x, a.x, h ) - k*h*(1.0-h), mix( b.y, a.y, h ) );
}

float smax( float a, float b, float k, float l )
{
	float h = clamp( l + l*(b-a)/k, 0.0, 1.0 );
	return mix( a, b, h ) + k*h*(1.0-h);
}

float sdEllipsoid( in vec3 p, in vec3 c, in vec3 r )
{
    return (length( (p-c)/r ) - 1.0) * min(min(r.x,r.y),r.z);
}

vec2 sdSegment( vec3 a, vec3 b, vec3 p )
{
	vec3 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return vec2( length( pa - ba*h ), h );
}

float reboundValue( float iTime, float limit )
{
    float doubleLimit = limit*2.0;
	float doubleValue = mod(iTime, doubleLimit);
    if(doubleValue>limit)
        return doubleLimit-doubleValue;
    return doubleValue;
}


// Distance to the scene and color of the closest point
float distScene (in vec3 p, out vec3 color, out vec3 material) {
	float d = 1000.0;
    float d2 = 1000.0;
    float d3 = 1000.0;
    float d4 = 1000.0;
    
    float speed = iTime*0.5;
    
    float speedPI2 = speed*PI2;
    
    vec3 pacmanPos = vec3(0.0,sin((speedPI2)-2.2)*20.0,0.0);
    
    //body
    vec3 pacmanRelPos = p-pacmanPos;
    float body = length (pacmanRelPos);
	body = max (body - 32.0, 27.5 - body);
	float mouthAngle = PI * (0.09 + 0.08 * sin (speedPI2));
    vec3 mouthPos = pacmanRelPos-vec3(0.0,3.0,5.0);
	float mouthTop = dot (mouthPos, vec3 (0.0, -cos (mouthAngle), sin (mouthAngle))) - 2.0;
	mouthAngle *= 1.8;
	float mouthBottom = dot (mouthPos, vec3 (0.0, cos (mouthAngle), sin (mouthAngle)));
	float pacManBody = max (body, min (mouthTop, mouthBottom));
    
    d = pacManBody;
    color = pacmanColor;
    material = pacmanMat;
    
    // EYES
    float eyesAngle = sin(speedPI2)*2.0;
    vec3 eyesPos = vec3 (abs (pacmanRelPos.x) - 11.5, pacmanRelPos.y - (18.2)-eyesAngle, pacmanRelPos.z - (19.2 - eyesAngle));
    vec3 q = 1.2*eyesPos;
	float eyeBall = max (length (q) - (6.0), -p.z);
    q = 1.0*eyesPos;
    float eyeBall2 = min(eyeBall,max (length (q) - (6.0), -p.z));
    eyeBall2 = max(pacManBody-0.1,eyeBall2);
	if (eyeBall2 <= d) {
        d = eyeBall2;
        if(eyeBall < eyeBall2)
        {
            color = eyeBallColor;
        	material = eyeBallMat;
        }
        else
        {
        	color = eyeBall2Color;
        	material = eyeBall2Mat;
        }
    }
    
    //TONGUE
    float tongueFactor = abs(sin(mod(speed*2.0,PI2)));
    vec3 tongueAnim = vec3(1.0,1.4,2.5)*tongueFactor;
    float tongue = sdEllipsoid( vec3(abs(p.x), p.yz), 
                               vec3(3.0,-18.5,-3.0)+pacmanPos, 
                               vec3(14.0,3.2,17.0)+tongueAnim );
    d2 = smin(pacManBody,tongue,2.06,0.5);
    if(d2 < d)
    {
        d = d2;
        if(tongue <= d2+0.09)
        {
            color = tongueColor;
    		material = tongueMat;
        }
    }
    
    float mirrorX = sign(p.x);
    
    #ifdef ARMS
    float armsPeriod = PI*0.55;
    float armsPeriodiTime = (speedPI2*0.275)-1.15+((mirrorX+1.0)*0.5*armsPeriod);
    float armRotSegmentA = reboundValue(armsPeriodiTime,armsPeriod)-1.0;
    float armsSinRotA = sin(armRotSegmentA);
    float armsCosRotA = cos(armRotSegmentA);
    mat3 armsSegmentARot = rotX(armsCosRotA, armsSinRotA);
    
    float armRotSegmentB0 = reboundValue(armsPeriodiTime,armsPeriod)-0.7;
    float armsSinRotB0 = sin(armRotSegmentB0);
    float armsCosRotB0 = cos(armRotSegmentB0);
    mat3 armsSegmentB0Rot = rotY(armsCosRotB0, armsSinRotB0);
    
    float armRotSegmentB1 = reboundValue(armsPeriodiTime,armsPeriod)-1.1;
    float armsSinRotB1 = sin(armRotSegmentB1);
    float armsCosRotB1 = cos(armRotSegmentB1);
    mat3 armsSegmentB1Rot = rotX(armsCosRotB1, armsSinRotB1);
    
    float armRotSegmentB2 = reboundValue(armsPeriodiTime,armsPeriod)-0.1;
    float armsSinRotB2 = sin(armRotSegmentB2);
    float armsCosRotB2 = cos(armRotSegmentB2);
    mat3 armsSegmentB2Rot = rotZ(armsCosRotB2, armsSinRotB2);
    
    mat3 armsSegmentBRot = armsSegmentB0Rot*armsSegmentB1Rot*armsSegmentB2Rot;
    
    vec3 armsSegmentAPos = vec3(28.0,3.0,-2.0)+pacmanPos;
    vec3 armsSegmentBPos = armsSegmentARot*(vec3(10.0,-10.0,5.0))+armsSegmentAPos;
    vec3 armsSegmentCPos = armsSegmentBRot*(vec3(1.0,-2.0,15.0))+armsSegmentBPos;
    
    vec2 armSegmentA = sdSegment( armsSegmentAPos, armsSegmentBPos, vec3(abs(p.x),p.yz) );
	d2 = armSegmentA.x - 4.0 + armSegmentA.y*1.0;
 	d2 = smin(pacManBody,d2,1.06,0.5);
    if (d2 < d) {
        d = d2;
		color = pacmanColor;
    	material = pacmanMat;
	}
    
    vec2 armSegmentB = sdSegment( armsSegmentBPos, armsSegmentCPos, vec3(abs(p.x),p.yz) );
	d4 = armSegmentB.x - 3.0 + armSegmentB.y*1.0;
 	d2 = smin(d2,d4,2.06,0.5);
    if (d2 < d) {
        d = d2;
		color = pacmanColor;
    	material = pacmanMat;
	}
    
    //Hand
    vec3 handPos = armsSegmentBRot*vec3(0.0,0.0,1.2)+armsSegmentCPos;
    
    vec2 hand = sdSegment( armsSegmentCPos, handPos, vec3(abs(p.x),p.yz) );
	d3 = hand.x - 3.0 + hand.y*0.1;
 	d2 = smin(d2,d3,2.06,0.5);
    
    d2 = smax(-d4,d3,1.06,0.5);
    if (d2 < d) {
        d = d2;
        if(d3 <= d2+0.28)
        {
            color = gloveColor;
            material = gloveMat;
        }
	}
    
    //Fingers
    vec3 fingerPos00 = armsSegmentBRot*vec3(-2.0,2.6,8.2)+armsSegmentCPos;
    vec3 fingerPos01 = armsSegmentBRot*vec3(-2.0,0.0,9.5)+armsSegmentCPos;
    vec3 fingerPos02 = armsSegmentBRot*vec3(-2.0,-2.6,8.2)+armsSegmentCPos;
    
    vec2 finger00 = sdSegment( armsSegmentCPos, fingerPos00, vec3(abs(p.x),p.yz) );
	d3 = finger00.x - 1.5 + finger00.y*0.5;
    d2 = smin(d2,d3,0.01,0.1);
    
    vec2 finger01 = sdSegment( armsSegmentCPos, fingerPos01, vec3(abs(p.x),p.yz) );
	d3 = finger01.x - 1.5 + finger01.y*0.5;
    d2 = smin(d2,d3,0.01,0.1);
    
    vec2 finger02 = sdSegment( armsSegmentCPos, fingerPos02, vec3(abs(p.x),p.yz) );
	d3 = finger02.x - 1.5 + finger02.y*0.5;
 	d2 = smin(d2,d3,0.01,0.1);
    
    if (d2 < d) {
        d = d2;
        if(d3 <= d2+0.28)
        {
        color = gloveColor;
        material = gloveMat;
        }
	}
    #endif
    
    #ifdef LEGS
    float legsPeriod = PI*0.75;
    float legsPeriodiTime = ((speedPI2*0.375)-1.55)+((-mirrorX+1.0)*0.5*legsPeriod);
    float legRotSegmentA = reboundValue(legsPeriodiTime,legsPeriod)-1.4;
    float legsSinRotA = sin(legRotSegmentA);
    float legsCosRotA = cos(legRotSegmentA);
    mat3 legsSegmentARot = rotX(legsCosRotA, legsSinRotA);
    
    float legRotSegmentB1 = reboundValue(legsPeriodiTime*0.85-1.1,legsPeriod*0.85);
    float legsSinRotB1 = sin(legRotSegmentB1);
    float legsCosRotB1 = cos(legRotSegmentB1);
    mat3 legsSegmentB1Rot = rotX(legsCosRotB1, legsSinRotB1);
    
    mat3 legsSegmentBRot = legsSegmentB1Rot*legsSegmentARot;
    
    vec3 legsSegmentAPos = vec3(14.0,-27.0,1.0)+pacmanPos;
    vec3 legsSegmentBPos = legsSegmentARot*(vec3(0.0,-22.0,0.0))+legsSegmentAPos;
    vec3 legsSegmentCPos = legsSegmentBRot*(vec3(0.0,-20.0,0.0))+legsSegmentBPos;
    
    vec2 legsegmentA = sdSegment( legsSegmentAPos, legsSegmentBPos, vec3(abs(p.x),p.yz) );
	d2 = legsegmentA.x - 4.5 + legsegmentA.y*1.0;
 	d2 = smin(pacManBody,d2,3.06,0.5);
    if (d2 < d) {
        d = d2;
		color = pacmanColor;
    	material = pacmanMat;
	}
    
    vec2 legsegmentB = sdSegment( legsSegmentBPos, legsSegmentCPos, vec3(abs(p.x),p.yz) );
	d4 = legsegmentB.x - 3.5 + legsegmentB.y*1.0;
 	d2 = smin(d2,d4,2.06,0.5);
    if (d2 < d) {
        d = d2;
		color = pacmanColor;
    	material = pacmanMat;
	}
    
    //Boot
    vec3 bootPos = legsSegmentBRot*vec3(0.0,-4.6,14.2)+legsSegmentCPos;
    
    vec2 boot = sdSegment( legsSegmentCPos, bootPos, vec3(abs(p.x),p.yz) );
	d3 = boot.x - 5.5 + boot.y*1.4;
    d2 = smin(d,d3,2.06,0.5);
    d2 = smax(-d4,d3,6.06,0.5);
    if (d2 < d) {
        d = d2;
        if(d3 <= d2+0.28)
        {
            color = bootColor;
            material = bootMat;
        }
	}
    #endif
    
    // Biscuits
    float biscuitPeriod = 200.0;
    
    float displacement = floor (speed * biscuitPeriod);
    
    float idsPerPeriod = 8.0;
    
    float fullPeriod = biscuitPeriod*idsPerPeriod;
    
    float modPerPeriod = mod (p.z + displacement, fullPeriod);
    
    float unitDist = fullPeriod/idsPerPeriod;

	float idValue = modPerPeriod/unitDist;
	idValue = idValue-fract(idValue ); // modf(idValue, idValue);
    
    float difSize = floor(idValue/(idsPerPeriod-1.0))*6.0;
	q = vec3 (p.xy, mod (p.z + displacement, biscuitPeriod) - biscuitPeriod * 0.5);
	float biscuit = max (length (q) - (9.0+difSize), -p.z);
	if (biscuit < d) {
		d = biscuit;
        if(idValue==(idsPerPeriod-1.0))
        {
            color = bigBiscuitColor;
        	material = bigBiscuitMat;
        }
        else
        {
            color = biscuitColor;
        	material = biscuitMat;
        }
	}
    
    // Ground
	float ground = (p.y + 91.50 );
	if (ground < d) {
		d = ground;
		color = groundColor;
        material = groundMat;
	}
    
    
	return d;
}

// Distance to the scene
vec2 dist (inout vec3 p, in vec3 ray, in float rayLengthMax, in float delta, out vec3 color, out vec3 material) {
    color = vec3(0.0,0.0,0.0);
    material = vec3(0.0,0.0,0.0);
	float d = 0.0;
	float rayLength = 0.0;
	for (float rayStep = 0.0; rayStep < RAY_STEP_MAX; ++rayStep) {
		d = distScene (p, color, material);
		if (d < delta) {
		  break;
		}
		d = d*DELTA_SEARCH;
		rayLength += d;
		if (rayLength > rayLengthMax) {
			break;
		}
		p += d * ray;
	}
	return vec2 (d, rayLength);
}

// Normal at a given point
vec3 normal (in vec3 p) {
	vec2 h = vec2 (NORMAL_DELTA, -NORMAL_DELTA);
    vec3 dummy0, dummy1;
	vec3 n;
	n = h.xxx * distScene (p + h.xxx, dummy0, dummy1) +
			h.xyy * distScene (p + h.xyy, dummy0, dummy1) +
			h.yxy * distScene (p + h.yxy, dummy0, dummy1) +
			h.yyx * distScene (p + h.yyx, dummy0, dummy1);
	return normalize (n);
}

// Main function
void mainImage( out vec4 fragColor, in vec2 fragCoord ) {

	// Get the fragment
	vec2 frag = (2.0 * fragCoord.xy - iResolution.xy) / iResolution.y * ZOOM;

	// Define the ray corresponding to this fragment
	vec3 ray = normalize (vec3 (frag, CAMERA_FOCAL_LENGTH));

	// Compute the orientation of the camera
	float yawAngle = PI * (1.9) + clamp(reboundValue( iTime, PI2*1.15 ), PI, PI2);
	float pitchAngle = PI*(0.15);
    
	#ifdef MOUSE
		yawAngle += 8.0 * PI * iMouse.x;
		pitchAngle += PI * 8.0 * (1.0 - iMouse.y);
	#endif

	float cosYaw = cos (yawAngle);
	float sinYaw = sin (yawAngle);
	float cosPitch = cos (pitchAngle);
	float sinPitch = sin (pitchAngle);

	mat3 cameraOrientation;
	cameraOrientation [0] = vec3 (cosYaw, 0.0, -sinYaw);
	cameraOrientation [1] = vec3 (sinYaw * sinPitch, cosPitch, cosYaw * sinPitch);
	cameraOrientation [2] = vec3 (sinYaw * cosPitch, -sinPitch, cosYaw * cosPitch);

	ray = cameraOrientation * ray;

	// Compute the origin of the ray
	float cameraDist = 70.0;
	vec3 origin = (clamp(reboundValue( iTime, PI2*1.5 ), 0.0, PI) * 2.0 /*10*/
        + (vec3 (0.0, -30.0 * -0.0, 0.0)) - cameraOrientation [2] * cameraDist);

	// Compute the distance to the scene
    vec3 color;
    vec3 material;
	vec2 d = dist (origin, ray, RAY_LENGTH_MAX, DELTA, color, material);

	// Set the background color
	vec3 finalColor = vec3(0.0,0.0,0.0);
	if (d.x < DELTA) {
        vec3 n = normal (origin);
        vec3 diffuse = color * max(0.0,dot(n,lightDir));
        float specular = pow (max (0.0, dot (reflect (ray, n), lightDir)), material.x) * material.y;
        vec3 ambient = (AMBIENT*color*groundColor);
        finalColor = (diffuse+specular);
        
        diffuse = color * max(0.0,dot(n,light2Dir));
        specular = pow (max (0.0, dot (reflect (ray, n), light2Dir)), material.x) * material.y;
        
        #ifdef SHADOW
            vec3 shadowOrigin = origin + n * SHADOW_DELTA*0.5;
            vec2 shadowDist = dist (shadowOrigin, lightDir, SHADOW_LENGTH, SHADOW_DELTA, color, material);
            if (shadowDist.x < SHADOW_DELTA ) {
                float shadowAmount = pow (min (1.0, shadowDist.y / SHADOW_LENGTH), SHADOW_POWER);
                finalColor *= shadowAmount;
            }
		#endif
        

        finalColor += (diffuse+specular)*light2Pow/**groundColor*/;
        
        finalColor += ambient;
    }

    float dist = length(origin)/600.0;
    //finalColor = vec3(dist,dist,dist);
    
    finalColor = mix(finalColor, BACKGROUND_COLOR, min(dist,1.0));
    
	// Set the fragment color
	finalColor = pow (finalColor, vec3 (GAMMA));
	fragColor = vec4 (finalColor, 1.0);
}

// --------[ Original ShaderToy ends here ]---------- //

void main(void)
{
    mainImage(gl_FragColor, gl_FragCoord.xy);
}
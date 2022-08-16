#ifdef GL_ES
precision highp float;
#endif

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

vec2 rnd_state;
void seed_rand(vec2 state) {
    rnd_state = mat2(cos(u_time),-sin(u_time),sin(u_time),cos(u_time))*state;
}

float rand() {
    float res = fract(sin(dot(rnd_state, vec2(12.9898,78.233))) * 43758.5453123);
  	rnd_state.x = rnd_state.y;
    rnd_state.y = res;
    return res;
}

const vec3  _0_0 = vec3(0.0,0.0,0.0);
const float _0_1 = 1.0;
const float WORLD_RES = 1e-3;
const float WORLD_MAX = 1e4;

struct Property {
    float diffuse, specular, transmit, refractive_index;
    vec3 color;
};

float sphere(vec3 p, vec3 loc, float radius) {
    return length(p - loc) - radius;
}

float box(vec3 p, vec3 whd) {
    vec3 del = abs(p)-whd/2.;
    float mval = max(max(del.x,del.y),del.z);
    return length(max(del,0.))+min(mval,0.);
}

float cylinder(vec3 p, float height, float radius) {
    return 0.;
}

float plane_y(vec3 p, vec3 anchor, vec3 norm) {
    return dot(p-anchor,norm);
}

float intersect(float a, float b) {
    return max(a,b);
}

float join(float a, float b) {
    return min(a,b);
}

float subtract(float a, float b) {
    return max(a,-b);
}

float lens(vec3 p, vec3 loc, float focal_length, float thickness) {
    return 0.01+intersect(
        sphere(p,loc+vec3(0.,0.,focal_length-thickness/2.),focal_length),
        sphere(p,loc+vec3(0.,0.,thickness/2.-focal_length),focal_length)
    );      
}

float curvature = 4.0;
float sdf(vec3 p) {
    return  join(
        join(join(join(
            lens(p,vec3(0.,0.,-4.),curvature,0.2),
            sphere(p,vec3(-3.,0.,1.),1.0)
            ),
            sphere(p,vec3(0.,0.,1.),1.0)
        	),
            sphere(p,vec3(+3.,0.,1.),1.0)
    	),	
        plane_y(p,vec3(0.,-1.6,0.),vec3(0.,1.,0.))
    );
}
void prop(vec3 p, vec3 d, out Property property) {
    if (p.y <= -1.5) {
		const float checker_size = 0.25;
        bool a_odd = mod(p.x,2.*checker_size) >= checker_size;
        bool b_odd = mod(p.z,2.*checker_size) >= checker_size;
        if (a_odd == b_odd) {
    		property = Property(0.85,0.0,0.0,1.4,vec3(1.0,1.0,1.0));
        } else {
            property = Property(0.1,0.0,0.0,1.4,vec3(1.0,1.0,1.0));
        }
    } else {
        if (p.z > 0.) {
    		property = Property(0.03,0.8,0.0,1.4,vec3(1.0,1.0,1.0));
        } else {
    		property = Property(0.01,0.1,0.7,1.4,vec3(1.0,1.0,1.0));
        }
    }
}

const float D_ = 1e-4;
const vec3 DX = vec3(D_,0.0,0.0);
const vec3 DY = vec3(0.0,D_,0.0);
const vec3 DZ = vec3(0.0,0.0,D_);
vec3 gradient(vec3 p) {
    return vec3(sdf(p+DX)-sdf(p-DX),
                sdf(p+DY)-sdf(p-DY),
                sdf(p+DZ)-sdf(p-DZ))/(2.0*D_);
}

bool next_surface(inout vec3 p, vec3 d, out vec3 g, vec3 stop_at) {
    for (int i = 0; i < 1000; i++) {
    	float v = sdf(p);
        if (v <= 0.) {
            v = WORLD_RES - v;
        } else if (v < WORLD_RES) {
            g = gradient(p);
            if (dot(g,d) < 0.0) {
                return true;
            }
        } else if (v > WORLD_MAX) {
            return false;
        } else if (dot(stop_at-p,d) < 0.0) {
            return false;
        }
        p += v*d;
    }
    return false;
}

vec3 light(vec3 p, vec3 d, vec3 n) {
    vec3 color = vec3(0.0,0.0,0.0);
    vec3 g;
    {
        vec3 p_light = vec3(sqrt(3.)/2.,2.5,-0.5);
        vec3 c_light = vec3(0.,35.,0.);
        
        vec3 d_light = p_light-p;
        float dist = length(d_light);
        vec3 d_l = d_light/dist;
        vec3 p_l = p;
        if (!next_surface(p_l,d_l,g,p_light)) {
            float d_light_n = dot(d_l,n);
            color += d_light_n/(dist*dist)*c_light;
        }
    }
    {
        vec3 p_light = vec3(-sqrt(3.)/2.,2.5,-0.5);
        vec3 c_light = vec3(0.,0.,35.);
        
        vec3 d_light = p_light-p;
        float dist = length(d_light);
        vec3 d_l = d_light/dist;
        vec3 p_l = p;
        if (!next_surface(p_l,d_l,g,p_light)) {
            float d_light_n = dot(d_l,n);
            color += d_light_n/(dist*dist)*c_light;
        }
    }
    {
        vec3 p_light = vec3(0.,2.5,2.);
        vec3 c_light = vec3(35.,0.,0.);
                
        vec3 d_light = p_light-p;
        float dist = length(d_light);
        vec3 d_l = d_light/dist;
        vec3 p_l = p;
        if (!next_surface(p_l,d_l,g,p_light)) {
            float d_light_n = dot(d_l,n);
            color += d_light_n/(dist*dist)*c_light;
        }
    }
    /*{
        vec3 d_light = vec3(2.0,2.5,2.0);
        vec3 c_light = vec3(0.0,0.0,1.5);
        
        float d_light_n = dot(normalize(d_light),n);
        color += d_light_n*c_light;
    }*/
    /*{
    	vec3 c_light = vec3(1.0,1.0,1.0)*0.1;    
        color += c_light;
    }*/
    return color;
}

bool next_surface(inout vec3 p, inout vec3 d, out vec3 g, bool inside) {
    for (int i = 0; i < 1000; i++) {
    	float v = inside ? -sdf(p) : sdf(p);
        if (v <= 0.) {
            v = WORLD_RES - v;
        } else if (v < WORLD_RES) {
            g = inside ? -gradient(p) : gradient(p);
            if (dot(g,d) < 0.0) {
                return true;
            }
        } else if (v > WORLD_MAX) {
            return false;
        }
        p += v*d;
    }
    return false;
}

bool next_surface(inout vec3 p, inout vec3 d, out vec3 g) {
	return next_surface(p,d,g,false);
}

bool resolve_transmission(float n1, float n2, inout vec3 p, inout vec3 d, inout vec3 n) {
    float nratio = n1/n2;
    vec3 perp_oblique = cross(d,n);
    float internal = nratio*nratio*dot(perp_oblique,perp_oblique);
    if (internal > 1.) {
        //total external reflection, somehow
        d = reflect(d,n);
        return true;
    } else {
        d = refract(d,n,nratio);
        nratio = 1./nratio;
        for (int i = 0; i < 5; i++) {
            vec3 g;
            bool hit = next_surface(p,d,g,true);
            if (!hit) return false;
            n = normalize(g);
            perp_oblique = cross(d,n);
            internal = nratio*nratio*dot(perp_oblique,perp_oblique);
            if (internal > 1.) {
                d = reflect(d,n);
            } else {
                d = refract(d,n,nratio);
                return true;
            }
        }
    }
    return false;
}

vec3 cast_ray(vec3 p, vec3 d, float prescale) {
    vec3 color = vec3(0.0,0.0,0.0);
    float atten = 1.0;
    vec3 p_stack[10];
    vec3 d_stack[10];
    float prescale_stack[10];
    int sp = 0;
    for (int i = 0; i < 1000; i++) {
        vec3 g;
        bool hit = next_surface(p,d,g);
        if (hit) {
            Property s;
            prop(p,d,s);
            vec3 n = normalize(g);
			bool keep_going = false;
            
            if (s.transmit > 0.0) {
				float n1 = 1.0;
                float n2 = s.refractive_index;
                vec3 ref_p = p;
                vec3 ref_d = d; 
                vec3 ref_n = n;
                bool exited = resolve_transmission(n1,n2,ref_p,ref_d,ref_n);
                if (exited) {
            		Property ref_s;
                    prop(ref_p,ref_d,ref_s);
                    color += s.transmit*prescale*ref_s.diffuse*light(ref_p,ref_d,ref_n)*ref_s.color;
                    if (sp < 5) {
                        #define _PUSH(i) if (sp == i) {\
                            p_stack[i] = ref_p;\
                            d_stack[i] = ref_d;\
                            prescale_stack[i] = prescale*s.transmit;\
                        }
                        #define PUSH(i) else _PUSH(i)
                       _PUSH(0)
                        PUSH(1)
                        PUSH(2)
                        PUSH(3)
                        PUSH(4)
                        PUSH(5)
                        PUSH(6)
                        PUSH(7)
                        PUSH(8)
                        PUSH(9)
                        sp++;
                    }
                }
            }

            if (s.diffuse > 0.0) {
                color += prescale*s.diffuse*light(p,d,n)*s.color;
            }

            if (s.specular > 0.0) {
                prescale = prescale*s.specular;
                d = reflect(d,n);
                keep_going = true;
            }
            
			if (keep_going && prescale > 1e-3) continue;
        }
		if (sp > 0) {
            sp--;
            #define _POP(i) if (sp == i) {\
                p = p_stack[i];\
                d = d_stack[i];\
                prescale = prescale_stack[i];\
            }
            #define POP(i) else _POP(i) 
           _POP(0)
            POP(1)  
            POP(2)
            POP(3)
            POP(4)
            POP(5)
            POP(6)
            POP(7)
            POP(8)
            POP(9) 
            continue;
        }
        return color;
    }
}

vec3 cast_ray(vec3 p, vec3 d) {
    return cast_ray(p,d,1.0);
}

float view_dist = 2.0;
mat3 cam_proj = mat3(1.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0);
vec3 cam_orig = vec3(0,0,-10);

void main() {
    vec2 st = gl_FragCoord.xy/u_resolution;
    seed_rand(st);
    st.x *= u_resolution.x/u_resolution.y;
    st.x = st.x*2.0-1.0;
    st.y = st.y*2.0-1.0;

    vec3 px_cam = vec3(st.x,st.y,view_dist);
    
    float cost = cos(0.4*cos(u_time/2.));
    float sint = sin(0.4*cos(u_time/2.));
    
    cam_proj = mat3(cost,0.0,-sint,0.0,1.0,0.0,sint,0.0,cost);
    cam_orig = vec3(-10.0*sint,0.0,-10.*cost);
    
    vec3 color = vec3(0.0,0.0,0.0);
    const int passes = 1;
    for (int i = 0; i < passes; i++) {
        color += cast_ray(cam_orig,normalize(cam_proj*px_cam))/float(passes);
    }
    gl_FragColor = vec4(color,1.0);
}

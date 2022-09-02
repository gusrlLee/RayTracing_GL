#version 330 core
out vec4 FragColor;

uniform uint frame;
uniform vec3 camera_pos;
uniform vec3 camera_front;
uniform vec3 camera_up;
uniform float fov;


#define UINT_MAX 0xFFFFFFFFu
#define FLT_MAX 3.402823466e+38F
#define RAND_MAX UINT_MAX
#define PI 3.1415926535897932385

const int sample_per_pixel = 100;
uint seed;

// RANDOM ----------------------------------------------------------------------------------------
uint hash(uint seed) {
    seed = (seed ^ 61u) ^ (seed >> 16u);
    seed *= 9u;
    seed = seed ^ (seed >> 4u);
    seed *= 0x27D4EB2Du;
    seed = seed ^ (seed >> 15u);
    return seed;
}

void randomInit() {
    seed = hash(hash(uint(gl_FragCoord.x) + hash(uint(gl_FragCoord.y))) + frame);
}

uint randomUint() {
    seed = hash(seed);
    return seed;
}

float randomFloat() {
    return float(randomUint()) / float(RAND_MAX);
}

float randomFloat(float min, float max) {
    return min + (max - min) * randomFloat();
}

vec3 randomUnitSphere() {
    while (true) {
        vec3 p = vec3(randomFloat(-1.0, 1.0), randomFloat(-1.0, 1.0), randomFloat(-1.0, 1.0));
        if (dot(p, p) < 1.0)
            return p;
    }
}

vec3 randomUnitVector() {
    vec3 p = randomUnitSphere();
    return normalize(p);
}

vec3 randomHemisphere(const vec3 normal) {
    vec3 in_unit_sphere = randomUnitSphere();
    if (dot(in_unit_sphere, normal) > 0.0) // In the same hemisphere as the normal
        return in_unit_sphere;
    else
        return -in_unit_sphere;
}

// RANDOM ----------------------------------------------------------------------------------------

// TYPE ----------------------------------------------------------------------------------------
struct Sphere {
    int matrial_type;
    vec3 albedo;
    vec3 center;
    float radius;
    float fuzz; 
    float ir;
};

struct Ray {
    vec3 origin;
    vec3 direction;
};

// material ptr == 1 : lambient 
// material ptr == 2 : metal
// material ptr == 3 : dielectric

struct hit_record {
    vec3 p;
    vec3 normal;
    float t;
    int material_ptr;
    vec3 albedo;
    float fuzz; 
    float ir;
    bool front_face;
};

struct Camera {
    vec3 origin;
    vec3 lower_left_corner;
    vec3 horizontal;
    vec3 vertical;
};

// Method ----------------------------------------------------------------------------------------

vec3 reflect(vec3 v, vec3 n) {
    return v - 2*dot(v,n)*n;
}

vec3 refract(vec3 uv, vec3 n, float etai_over_etat) {
    float cos_theta = min(dot(-uv, n), 1.0);
    vec3 r_out_perp = etai_over_etat * (uv + cos_theta * n);
    float r_out_perp_length = dot(r_out_perp, r_out_perp);
    vec3 r_out_parallel = -sqrt(abs(1.0 - r_out_perp_length)) * n;

    return r_out_perp + r_out_parallel;
}

float reflectance(float cosine, float ref_idx) {
    float r0 = (1 - ref_idx) / (1 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1 - r0) * pow(1 - cosine, 5);
}


float clamp(float x, float min, float max) {
    if (x < min) return min;
    if (x > max) return max;
    return x;
}

bool near_zero(vec3 e) {
    // Return true if the vector is close to zero in all dimensions.
    float s = 1e-8;
    return (abs(e.x) < s) && (abs(e.y) < s) && (abs(e.z) < s);
}

bool lambient_scatter(Ray ray, hit_record rec, out vec3 attenuation, out Ray scattered) {
    vec3 scatter_direction = rec.normal + randomUnitVector();
    if (near_zero(scatter_direction))
        scatter_direction = rec.normal;

    scattered = Ray(rec.p, scatter_direction);  
    attenuation = rec.albedo;

    return true;
}

bool metal_scatter(Ray ray, hit_record rec, out vec3 attenuation, out Ray scattered) {
    float size = dot(ray.direction, ray.direction);
    vec3 unit_direction = ray.direction / size; 
    vec3 reflected = reflect(unit_direction, rec.normal);
    scattered = Ray(rec.p, reflected + rec.fuzz * randomUnitSphere());
    attenuation = rec.albedo;

    return (dot(scattered.direction, rec.normal) > 0);
}

bool dielectric_scatter (Ray ray, hit_record rec, out vec3 attenuation, out Ray scattered) {
    attenuation = vec3(1.0, 1.0, 1.0);

    float refraction_ratio;
    if ( rec.front_face ) {
        refraction_ratio = (1.0 / rec.ir);
    }
    else {
        refraction_ratio = rec.ir;
    }

    float size = dot(ray.direction, ray.direction);
    vec3 unit_direction = ray.direction / size; 

    float cos_theta = min(dot(-unit_direction, rec.normal), 1.0);
    float sin_theta = sqrt(1.0 - (cos_theta * cos_theta));

    bool cannot_refract = refraction_ratio * sin_theta > 1.0;
    vec3 direction;
    if ( cannot_refract || reflectance(cos_theta, refraction_ratio) > randomFloat()) {
        direction = reflect(unit_direction, rec.normal);
    }
    else {
        direction = refract(unit_direction, rec.normal, refraction_ratio);
    }

    scattered = Ray(rec.p, direction);

    return true;
}

bool hit(Ray ray, Sphere sphere, float t_min, float t_max, out hit_record rec) {
    vec3 oc = ray.origin - sphere.center;

    float a = dot(ray.direction, ray.direction);
    float b = dot(oc, ray.direction);
    float c = dot(oc, oc) - sphere.radius * sphere.radius;

    float discriminant = b*b - a * c;
    if (discriminant < 0) return false;
    float sqrtd = sqrt(discriminant);

    float root = (-b - sqrtd) / a;
    if (root < t_min || t_max < root) {
        root = (-b + sqrtd) / a;
        if (root < t_min || t_max < root) {
            return false;
        }
    }

    rec.t = root;
    rec.p = ray.origin + rec.t * ray.direction;
    vec3 outward_normal = (rec.p - sphere.center) / sphere.radius;
    if(dot(ray.direction, outward_normal) < 0) {
        rec.front_face = true;
        rec.normal = outward_normal; 
    }
    else {
        rec.front_face = false;
        rec.normal = -outward_normal;
    }

    rec.albedo = sphere.albedo;
    rec.material_ptr = sphere.matrial_type;
    rec.fuzz = sphere.fuzz;
    rec.ir = sphere.ir;

    return true;
}


vec3 rayColor(Ray ray, Sphere sphereOfWorld[100], int sphere_counter, int depth) {
    hit_record rec;
    Ray r = ray;

    vec3 color = vec3(1.0);
    vec3 temp = vec3(1.0);

    for (int d=0; d<depth; d++) {
        bool hit_result = false;
        float size = dot(r.direction, r.direction);
        vec3 unit_direction = r.direction / size; 
        Sphere sphere;

        for (int i=0; i<sphere_counter; i++) {
            if ( hit_result ) {
                sphere = sphereOfWorld[i];
                break;
            }

            hit_result = hit(r, sphereOfWorld[i], 0.00001, 9999999.0, rec);
        }

        if (hit_result) {
            Ray scattered;
            vec3 attenuation;
            bool result;
            if (rec.material_ptr == 0) { // lambertian
                result = lambient_scatter(r, rec, attenuation, scattered);
                if ( result ) {
                    temp *= attenuation;
                }
                r = scattered;
            }
            else if (rec.material_ptr == 1) { // metal 
                result = metal_scatter(r, rec, attenuation, scattered);
                if ( result ) {
                    temp *= attenuation;
                }
                r = scattered;
            }
            else if (rec.material_ptr == 2) { // dielectric
                result = dielectric_scatter(r, rec, attenuation, scattered);
                if ( result ) {
                    temp *= attenuation;
                }
                r = scattered;
            }
        }

        else {
            float t = 0.5 * (unit_direction.y + 1.0);
            color = (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
            return temp * color;
        }
    }
    // return temp * color;
}

Ray getRay(Camera camera, float u, float v) {
    return Ray(camera.origin, camera.lower_left_corner + u * camera.horizontal + v * camera.vertical - camera.origin);
}

float degreeToRadians(float degree) {
    return degree * PI / 180.0;
}

vec3 unitVector(vec3 vector) {
    return vector / dot(vector, vector);
}

Camera createCamera(vec3 lookfrom, vec3 lookat, vec3 vup, float vfov, float aspect_ratio) {
    Camera cam;
    float theta = degreeToRadians(vfov);
    float h = tan(theta/2);
    float viewport_height = 2.0 * h;
    float viewport_width = aspect_ratio * viewport_height;

    vec3 w = unitVector(lookfrom - lookat);
    vec3 u = unitVector(cross(vup, w));
    vec3 v = cross(w, u);

    cam.origin = lookfrom;
    cam.horizontal = viewport_width * u;
    cam.vertical = viewport_height * v;
    cam.lower_left_corner = cam.origin - cam.horizontal/2 - cam.vertical/2 - w;

    return cam;
}


void main()
{
    vec3 origin = vec3(0.0, 0.0, 0.0);
    float screen_width = 1280;
    float aspect_ratio = 16.0 / 9.0;
    float screen_height = screen_width / aspect_ratio;

    vec2 st = vec2(gl_FragCoord.x / (screen_width-1), gl_FragCoord.y / (screen_height-1)); 
    randomInit();

    // for camera 
    float focal_length = 1.0;
    float viewport_height = 2.0;
    float viewport_width = aspect_ratio * viewport_height;
    vec3 horizontal = vec3(viewport_width, 0, 0);
    vec3 vertical = vec3(0, viewport_height, 0);
    vec3 lower_left_corner = origin - horizontal/2 - vertical/2 - vec3(0, 0, focal_length); 

    Camera camera = createCamera(camera_pos, camera_pos + camera_front, camera_up, fov, aspect_ratio);

    // make (0, 0) center point beacuse center point of gl_FragCoord is (width/2, height/2) 
    // define ray 
    // Ray ray = Ray(origin, vec3(lower_left_corner.x + horizontal.x*x, lower_left_corner.y+vertical.y*y, lower_left_corner.z) - origin);

    Sphere sphereOfWorld[100];
    int sphere_counter = 0;
    
    // Sphere { material_type, albedo, center, radius, fuzz, ir }
    // lambertian 
    sphereOfWorld[0] = Sphere(0, vec3(0.7, 0.3, 0.3), vec3(0, 0, -1), 0.5, 0.0, 0.0); sphere_counter++;
    // metal 
    sphereOfWorld[1] = Sphere(1, vec3(0.8, 0.8, 0.8), vec3(1, 0, -1), 0.5, 0.3, 0.0); sphere_counter++;
    // glass 
    sphereOfWorld[2] = Sphere(1, vec3(0.8, 0.6, 0.2), vec3(-1, 0, -1), 0.5, 0.1, 1.5); sphere_counter++;
    // sphereOfWorld[3] = Sphere(2, vec3(0.8, 0.6, 0.2), vec3(-1, 0, -1), -0.4, 0.0, 1.5); sphere_counter++;
    // ground 
    sphereOfWorld[3] = Sphere(0, vec3(0.8, 0.8, 0.0), vec3(0, -100.5, -1), 100, 0.0, 0.0); sphere_counter++;

    int max_depth = 50;
    vec3 color = vec3(0.0);
    for (int i=0; i<sample_per_pixel; i++) {
        float x = (gl_FragCoord.x - (screen_width/2) + randomFloat()) / (screen_width - 1);
        float y = (gl_FragCoord.y - (screen_height/2) + randomFloat()) / (screen_height - 1);
        Ray ray = getRay(camera, x, y);
        color += rayColor(ray, sphereOfWorld, sphere_counter, max_depth);  
    }
    // determine color 
    FragColor = vec4(sqrt(color / float(sample_per_pixel)), 1.0);
}

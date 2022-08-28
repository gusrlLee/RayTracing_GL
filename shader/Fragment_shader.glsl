#version 330 core
out vec4 FragColor;

uniform uint frame;

#define UINT_MAX 0xFFFFFFFFu
#define FLT_MAX 3.402823466e+38F
#define RAND_MAX UINT_MAX

uint seed;

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

struct Sphere {
    int texture;
    vec3 center;
    float radius;
};

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct hit_record {
    vec3 p;
    vec3 normal;
    float t;
};

struct Camera {
    vec3 origin;
    vec3 lower_left_corner;
    vec3 horizontal;
    vec3 vertical;
};

// type = 1 : sphere
// type = 2 : box 
struct World {
    int type;
};

float screen_width = 1280;
float aspect_ratio = 16.0 / 9.0;
float screen_height = screen_width / aspect_ratio;
const int sample_per_pixel = 10;

float clamp(float x, float min, float max) {
    if (x < min) return min;
    if (x > max) return max;
    return x;
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
    rec.normal = (rec.p - sphere.center) / sphere.radius;

    return true;
}

vec3 rayColor(Ray ray, Sphere sphereOfWorld[100], int sphere_counter, int depth) {
    bool hit_result = false;
    hit_record rec;
    Ray r = ray;

    vec3 color = vec3(1.0);
    float temp = 1.0;

    for (int d=0; d<depth; d++) {
        for (int i=0; i<sphere_counter; i++) {
            if (hit_result) {
                break;
            }

            hit_result = hit(r, sphereOfWorld[i], 0.00001, 9999999, rec);
        }

        if (hit_result) {
            temp *= 0.5;
            vec3 target = rec.p + rec.normal + randomHemisphere(rec.normal);
            r = Ray(rec.p, target - rec.p);
        }

        else {
            float size = dot(r.direction, r.direction);
            vec3 unit_direction = r.direction / size; 
            float t = 0.5 * (unit_direction.y + 1.0);
            color = (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
            return temp * color;
        }
        hit_result = false;
    }
    // return temp * color;
}

Ray getRay(Camera camera, float u, float v) {
    return Ray(camera.origin, vec3(camera.lower_left_corner.x + u*camera.horizontal.x, camera.lower_left_corner.y + v*camera.vertical.y, camera.lower_left_corner.z) - camera.origin);
}


void main()
{
    vec3 origin = vec3(0.0, 0.0, 0.0);

    vec2 st = vec2(gl_FragCoord.x / (screen_width-1), gl_FragCoord.y / (screen_height-1)); 
    randomInit();

    // for camera 
    float focal_length = 1.0;
    float viewport_height = 2.0;
    float viewport_width = aspect_ratio * viewport_height;
    vec3 horizontal = vec3(viewport_width, 0, 0);
    vec3 vertical = vec3(0, viewport_height, 0);
    vec3 lower_left_corner = origin - horizontal/2 - vertical/2 - vec3(0, 0, focal_length); 

    Camera camera = Camera( origin, lower_left_corner, horizontal, vertical);

    // make (0, 0) center point beacuse center point of gl_FragCoord is (width/2, height/2) 

    // define ray 
    // Ray ray = Ray(origin, vec3(lower_left_corner.x + horizontal.x*x, lower_left_corner.y+vertical.y*y, lower_left_corner.z) - origin);

    Sphere sphereOfWorld[100];
    int sphere_counter = 0;
    sphereOfWorld[0] = Sphere(0, vec3(0, 0, -1), 0.5); sphere_counter++;
    sphereOfWorld[1] = Sphere(0, vec3(0, -100.5, -1), 100); sphere_counter++;

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

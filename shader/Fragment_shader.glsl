#version 330 core
out vec4 FragColor;

uniform float t;

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
const int sample_per_pixel = 100;

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

    if (depth <= 0) 
        return vec3(0.0);

    for (int i=0; i<sphere_counter; i++) {
        if (hit_result) {
            return 0.5 * (rec.normal + vec3(1,1,1));
        }

        hit_result = hit(ray, sphereOfWorld[i], 0, 9999999, rec);
    }

    if (hit_result) {
        return 0.5 * (rec.normal + vec3(1,1,1));
    }
    else {
        float size = dot(ray.direction, ray.direction);
        vec3 unit_direction = ray.direction / size; 
        float t = 0.5 * (unit_direction.y + 1.0);
        vec3 color = (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
        return color;
    }
}

Ray getRay(Camera camera, float u, float v) {
    return Ray(camera.origin, vec3(camera.lower_left_corner.x + u*camera.horizontal.x, camera.lower_left_corner.y + v*camera.vertical.y, camera.lower_left_corner.z) - camera.origin);
}

float rand (float t) {
    return fract(sin(t)*1.0);
}


float clamp(float x, float min, float max) {
    if (x < min) return min;
    if (x > max) return max;
    return x;
}

void main()
{
    vec3 origin = vec3(0.0, 0.0, 0.0);

    vec2 st = vec2(gl_FragCoord.x / (screen_width-1), gl_FragCoord.y / (screen_height-1)); 
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

    vec4 color = vec4(0.0);
    for (int i=0; i<sample_per_pixel; i++) {
        float x = (gl_FragCoord.x - (screen_width/2) + rand(t)) / (screen_width - 1);
        float y = (gl_FragCoord.y - (screen_height/2) + rand(t)) / (screen_height - 1);
        Ray ray = getRay(camera, x, y);
        color += vec4(rayColor(ray, sphereOfWorld, sphere_counter, max_depth), 0.0);  
        // FragColor = vec4(rayColor(ray, sphereOfWorld, sphere_counter), 1.0);
    }
    // determine color 
    color.x = clamp(color.x / sample_per_pixel, 0, 0.999);
    color.y = clamp(color.y / sample_per_pixel, 0, 0.999);
    color.z = clamp(color.z / sample_per_pixel, 0, 0.999);
    color.w = 1.0;

    FragColor = color;
}

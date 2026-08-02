#include "rtweekend.h"
#include "camera.h"
#include "hittable.h"
#include "hittable_list.h"
#include "material.h"
#include "sphere.h"

int main() {
    hittable_list world;

    auto ground = make_shared<lambertian>(color(0.8, 0.8, 0.0));
    auto center = make_shared<lambertian>(color(0.1, 0.2, 0.5));
    auto left = make_shared<dielectric>(1.50);
    auto right = make_shared<metal>(color(0.8, 0.6, 0.2), 1.0);

    world.add(make_shared<sphere>(point3( 0.0, -100.5, -1.0), 100.0, ground));
    world.add(make_shared<sphere>(point3( 0.0, 0.0, -1.2), 0.5, center));
    world.add(make_shared<sphere>(point3(-1.0, 0.0, -1.0), 0.5, left));
    world.add(make_shared<sphere>(point3( 1.0, 0.0, -1.0), 0.5, right));

    camera cam;
    cam.aspect_ratio = 16.0 / 9.0;
    cam.image_width = 400;
    cam.samples_per_pixel = 100;
    cam.max_depth = 50;

    cam.render(world);
}

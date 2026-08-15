#include "rtweekend.h"
#include "box.h"
#include "bvh.h"
#include "camera.h"
#include "hittable.h"
#include "hittable_list.h"
#include "material.h"
#include "sphere.h"

int main() {
    hittable_list world;

    auto ground_material = make_shared<lambertian>(color(0.5, 0.5, 0.5));
    world.add(make_shared<sphere>(point3(0,-1000,0), 1000, ground_material));

    for (int a = -11; a < 11; a++) {
        for (int b = -11; b < 11; b++) {
            point3 base(a + 0.9*random_double(), 0, b + 0.9*random_double());

            if ((base - point3( 4, 0, -2)).length() < 1.5) continue;
            if ((base - point3( 0, 0, 0)).length() < 1.5) continue;
            if ((base - point3(-4, 0, 2)).length() < 1.5) continue;

            auto height = 0.0;
            auto stack = 1 + random_int(0, 2);

            for (int s = 0; s < stack; s++) {
                auto side = random_double(0.15, 0.4) * (1.0 - 0.25*s);
                auto angle = random_double(0, 90);
                auto pick = random_double();

                shared_ptr<material> mat;
                if (pick < 0.75) {
                    mat = make_shared<lambertian>(color::random() * color::random());
                } else if (pick < 0.93) {
                    mat = make_shared<metal>(color::random(0.5, 1), random_double(0, 0.4));
                } else {
                    mat = make_shared<dielectric>(1.5);
                }

                world.add(make_shared<box>(point3(base.x(), height + side/2, base.z()),
                                           side, mat, angle));
                height += side;
            }
        }
    }

    // staggered in z. a spun cube eats way more frame than a sphere of the
    // same span, so these are smaller than the book uses
    const double hero_side = 1.4;
    const double hero_y = hero_side / 2;

    auto material1 = make_shared<dielectric>(1.5);
    world.add(make_shared<box>(point3(0, hero_y, 0), hero_side, material1, 25));

    auto material2 = make_shared<lambertian>(color(0.4, 0.2, 0.1));
    world.add(make_shared<box>(point3(-4, hero_y, 2), hero_side, material2, -15));

    auto material3 = make_shared<metal>(color(0.7, 0.6, 0.5), 0.0);
    world.add(make_shared<box>(point3(4, hero_y, -2), hero_side, material3, 40));

    world = hittable_list(make_shared<bvh_node>(world));

    camera cam;

    cam.aspect_ratio = 16.0 / 9.0;
    cam.image_width = 400;
    cam.samples_per_pixel = 300;
    cam.max_depth = 50;

    cam.sky_bottom = color(1.0, 1.0, 1.0);
    cam.sky_top = color(0.5, 0.7, 1.0);

    cam.vfov = 20;
    cam.lookfrom = point3(13,2,3);
    cam.lookat = point3(0,0,0);
    cam.vup = vec3(0,1,0);

    cam.defocus_angle = 0.6;
    cam.focus_dist = 10.0;

    cam.render(world);
}

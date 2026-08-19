#include "gpu.cuh"

#include <iostream>

int main() {
    scene_desc s;
    s.name = "test";
    s.sky = sky_gradient(gcolor(1, 1, 1), gcolor(0.5f, 0.7f, 1.0f));
    s.lookfrom = gpoint3(0, 2, 6);
    s.lookat = gpoint3(0, 0.5f, 0);
    s.vfov = 40.0f;
    s.focus_dist = 6.0f;

    scene_data& d = s.data;
    d.ground(gvec3(200, 2, 200), d.lambertian(gcolor(0.5f, 0.5f, 0.5f)));
    d.sphere(gpoint3(0, 1, 0), 1.0f, d.metal(gcolor(0.7f, 0.6f, 0.5f), 0.0f));
    d.cube(gpoint3(-2.4f, 0.75f, 0), 1.5f, d.lambertian(gcolor(0.8f, 0.2f, 0.2f)), 25.0f);
    d.sphere(gpoint3(2.2f, 0.8f, 0), 0.8f, d.glass(1.5f));

    gpu_scene g = upload_scene(d);

    const int width = 480;
    const int height = 270;
    auto image = render_image(s, g, width, height, 100, 20);

    std::cout << "P3\n" << width << ' ' << height << "\n255\n";
    for (int i = 0; i < width*height; i++) {
        unsigned int p = image[i];
        std::cout << ((p >> 16) & 0xFF) << ' ' << ((p >> 8) & 0xFF) << ' '
                  << (p & 0xFF) << '\n';
    }

    g.release();
    return 0;
}

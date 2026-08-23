#ifndef SCENE_CORNELL_HEAP_CUH
#define SCENE_CORNELL_HEAP_CUH

#include "helpers.cuh"

inline scene_desc scene_cornell_heap() {
    seed_scene(7);
    scene_desc s;
    s.name = "Cornell Heap";
    scene_data& d = s.data;

    const float room = 28.0f;
    const float half = room / 2;
    const float wall = 1.0f;

    int white = d.lambertian(gcolor(0.73f, 0.73f, 0.73f));
    int red = d.lambertian(gcolor(0.65f, 0.05f, 0.05f));
    int green = d.lambertian(gcolor(0.12f, 0.45f, 0.15f));

    d.box(gpoint3(0, -wall/2, 0), gvec3(room, wall, room), white);
    d.box(gpoint3(0, room + wall/2, 0), gvec3(room, wall, room), white);
    d.box(gpoint3(0, half, -half), gvec3(room, room, wall), white);
    d.box(gpoint3(-half, half, 0), gvec3(wall, room, room), red);
    d.box(gpoint3( half, half, 0), gvec3(wall, room, room), green);

    // 4th wall, sits behind the cam. stops light leaking out the back
    d.box(gpoint3(0, half, half + wall/2), gvec3(room, room, wall), white);

    d.box(gpoint3(0, room - 0.7f, 0), gvec3(10.0f, 0.4f, 10.0f),
          d.light(gcolor(14.0f, 12.6f, 10.5f)));

    for (int i = 0; i < 420; i++) {
        float side = rnd(1.0f, 2.4f);
        float x = rnd(-half + 2.0f, half - 2.0f);
        float z = rnd(-half + 2.0f, half - 6.0f);
        float lean = std::max(0.0f, 1.0f - (std::fabs(x + 5.0f) + std::fabs(z + 4.0f)) / 22.0f);
        float top = side + 12.0f * lean;
        float y = rnd(side/2, std::max(side/2, top));

        gcolor col = chance(0.4f) ? gcolor(0.73f, 0.72f, 0.70f)
                                  : bold_palette(rnd_int(0, 7));
        float roll = rnd();
        int mat;
        if (roll < 0.10f)      mat = d.glass(1.5f);
        else if (roll < 0.30f) mat = d.metal(col, rnd(0.0f, 0.25f));
        else                   mat = d.lambertian(col);

        drop_shape(d, gpoint3(x, y, z), side, mat, 0.42f);
    }

    s.sky = sky_gradient(gcolor(0, 0, 0));
    s.lookfrom = gpoint3(0, 13, 12.5f);
    s.lookat = gpoint3(0, 10, -6);
    s.vfov = 66.0f;
    s.focus_dist = 20.0f;
    s.defocus_angle = 0.0f;
    return s;
}

#endif

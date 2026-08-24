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

    // packed tight but still checked in 3d. radius sits between the inradius
    // and the corner so they nestle without growing through eachother
    struct blob { gpoint3 c; float r; };
    std::vector<blob> pile;

    for (int i = 0; i < 9000 && pile.size() < 620; i++) {
        float side = rnd(0.8f, 2.0f);
        float r = side * 0.60f;

        for (int tries = 0; tries < 60; tries++) {
            float x = rnd(-half + wall + r, half - wall - r);
            float z = rnd(-half + wall + r, half - 6.0f);
            float lean = std::max(0.0f, 1.0f - (std::fabs(x + 5.0f) + std::fabs(z + 4.0f)) / 22.0f);
            float top = r + 12.0f * lean;

            float t = rnd();
            float y = r + (std::max(r, top) - r) * t*t;   // bias low, stuff settles

            gpoint3 c(x, y, z);
            bool ok = true;
            for (size_t j = 0; j < pile.size(); j++) {
                float gap = r + pile[j].r + 0.02f;
                if ((c - pile[j].c).length_squared() < gap*gap) { ok = false; break; }
            }
            if (!ok) continue;

            pile.push_back(blob{c, r});

            gcolor col = chance(0.4f) ? gcolor(0.73f, 0.72f, 0.70f)
                                      : bold_palette(rnd_int(0, 7));
            float roll = rnd();
            int mat;
            if (roll < 0.10f) mat = d.glass(1.5f);
            else if (roll < 0.30f) mat = d.metal(col, rnd(0.0f, 0.25f));
            else mat = d.lambertian(col);

            drop_shape(d, c, side, mat, 0.42f);
            break;
        }
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

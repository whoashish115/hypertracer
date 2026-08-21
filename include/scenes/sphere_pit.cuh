#ifndef SCENE_SPHERE_PIT_CUH
#define SCENE_SPHERE_PIT_CUH

#include "helpers.cuh"

inline scene_desc scene_sphere_pit() {
    seed_scene(4);
    scene_desc s;
    s.name = "Sphere Pit";
    scene_data& d = s.data;

    d.ground(gvec3(400, 2, 400), d.metal(gcolor(0.30f, 0.30f, 0.33f), 0.10f));

    int red = d.lambertian(gcolor(0.72f, 0.13f, 0.16f));
    int green = d.lambertian(gcolor(0.14f, 0.70f, 0.16f));
    int gold = d.metal(gcolor(0.92f, 0.78f, 0.32f), 0.02f);
    int steel = d.metal(gcolor(0.78f, 0.80f, 0.84f), 0.14f);
    int clear = d.glass(1.52f);

    const int layers = 15;
    const int across = 15;
    const float radius = 1.0f;
    const float spacing = 1.92f;
    const float rise = spacing * 0.82f;
    const int half = across / 2;

    for (int layer = 0; layer < layers; layer++) {
        // odd rows shift half a step so they sit in the gaps below
        float offset = (layer % 2) ? spacing * 0.5f : 0.0f;
        float y = radius + layer * rise;

        for (int x = -half; x <= half; x++) {
            for (int z = -half; z <= half; z++) {
                float px = x*spacing + offset + rnd(-0.08f, 0.08f);
                float pz = z*spacing + offset + rnd(-0.08f, 0.08f);

                float roll = rnd();
                int mat = roll < 0.42f ? clear
                        : roll < 0.62f ? red
                        : roll < 0.80f ? green
                        : roll < 0.92f ? gold
                                       : steel;

                d.sphere(gpoint3(px, y + rnd(-0.04f, 0.04f), pz),
                         radius * rnd(0.90f, 1.04f), mat);
            }
        }
    }

    const float extent = half * spacing;
    const float top = radius + (layers - 1) * rise;

    // plain warm lamps burried in the pack. no tint, dont want stray colours
    for (int i = 0; i < 110; i++) {
        d.sphere(gpoint3(rnd(-extent, extent), rnd(radius, top), rnd(-extent, extent)),
                 radius*0.85f,
                 d.light(mix(gcolor(1.0f, 0.85f, 0.55f), hue(rnd()), rnd()*0.5f) * 5.0f));
    }

    for (int i = 0; i < 130; i++) {
        d.cube(gpoint3(rnd(-extent, extent), rnd(radius, top), rnd(-extent, extent)),
               rnd(1.2f, 2.2f),
               chance(0.55f) ? clear : d.metal(hue(rnd()), 0.05f), rnd(0.0f, 90.0f));
    }

    for (int i = 0; i < 120; i++) {
        float a = rnd(0.0f, 2.0f*GPU_PI);
        float r = extent + rnd(2.0f, 18.0f);
        float size = radius * rnd(0.7f, 1.1f);
        float roll = rnd();
        int mat = roll < 0.4f ? clear : roll < 0.6f ? red : roll < 0.8f ? green : gold;
        d.sphere(gpoint3(r*std::cos(a), size, r*std::sin(a)), size, mat);
    }

    d.box(gpoint3(22, 58, 30), gvec3(36, 0.6f, 36), d.light(gcolor(6.0f, 5.7f, 5.3f)));
    d.box(gpoint3(-40, 44, -18), gvec3(26, 0.6f, 26), d.light(gcolor(2.2f, 2.2f, 2.4f)));

    s.sky = sky_gradient(gcolor(0.05f, 0.05f, 0.06f), gcolor(0.14f, 0.15f, 0.18f));
    s.lookfrom = gpoint3(26, 26, 40);
    s.lookat = gpoint3(0, 11, 0);
    s.vfov = 40.0f;
    s.focus_dist = 50.0f;
    s.defocus_angle = 0.35f;
    return s;
}

#endif

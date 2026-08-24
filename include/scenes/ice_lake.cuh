#ifndef SCENE_ICE_LAKE_CUH
#define SCENE_ICE_LAKE_CUH

#include "helpers.cuh"

inline scene_desc scene_ice_lake() {
    seed_scene(16);
    scene_desc s;
    s.name = "Ice Lake";
    scene_data& d = s.data;

    d.ground(gvec3(600, 2, 600), d.metal(gcolor(0.52f, 0.60f, 0.68f), 0.012f));

    int snow = d.lambertian(gcolor(0.88f, 0.91f, 0.96f));
    int rock = d.lambertian(gcolor(0.19f, 0.20f, 0.24f));
    int ice = d.glass(1.31f);

    const int peaks = 26;
    for (int i = 0; i < peaks; i++) {
        float a = (i / float(peaks)) * 2.0f*GPU_PI + rnd(-0.08f, 0.08f);
        float dist = rnd(46.0f, 62.0f);
        float px = dist*std::cos(a);
        float pz = dist*std::sin(a);
        float tall = rnd(14.0f, 34.0f);
        int base = int(tall * 0.55f);

        for (int x = -base; x <= base; x++) {
            for (int z = -base; z <= base; z++) {
                float r = std::sqrt(float(x*x + z*z));
                if (r > base) continue;
                int height = int((base - r) * (tall / base) * rnd(0.85f, 1.1f));
                if (height <= 0) continue;

                for (int k = height - 3; k < height; k++) {
                    if (k < 0) continue;
                    int mat = (k > tall*0.55f) ? snow : rock;
                    d.cube(gpoint3(px + x, k + 0.5f, pz + z), 1.0f, mat, rnd(-4.0f, 4.0f));
                }
            }
        }
    }

    for (int i = 0; i < 300; i++) {
        float a = rnd(0.0f, 2.0f*GPU_PI);
        float dist = std::sqrt(rnd()) * 40.0f;
        float px = dist*std::cos(a), pz = dist*std::sin(a);
        float tall = rnd(0.4f, 3.2f);
        d.box(gpoint3(px, tall*0.4f, pz),
              gvec3(rnd(0.8f, 3.0f), tall, rnd(0.5f, 1.4f)),
              chance(0.55f) ? ice : snow, rnd(0.0f, 90.0f));
    }

    for (int i = 0; i < 120; i++) {
        float a = rnd(0.0f, 2.0f*GPU_PI);
        float dist = std::sqrt(rnd()) * 38.0f;
        drop_shape(d, gpoint3(dist*std::cos(a), rnd(0.3f, 0.9f), dist*std::sin(a)),
                   rnd(0.5f, 2.0f), chance(0.7f) ? snow : rock, 0.7f);
    }
    d.sphere(gpoint3(58, 15, -70), 14.0f, d.light(gcolor(13.0f, 8.6f, 5.2f)));

    s.sky = sky_gradient(gcolor(1.0f, 0.82f, 0.68f), gcolor(0.24f, 0.42f, 0.78f));
    s.lookfrom = gpoint3(0, 4.5f, 44);
    s.lookat = gpoint3(4, 10, -20);
    s.vfov = 40.0f;
    s.focus_dist = 60.0f;
    s.defocus_angle = 0.0f;
    return s;
}

#endif

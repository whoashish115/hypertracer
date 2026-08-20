#ifndef SCENE_CUBE_MOUNTAIN_CUH
#define SCENE_CUBE_MOUNTAIN_CUH

#include "helpers.cuh"

inline scene_desc scene_cube_mountain() {
    seed_scene(1);
    scene_desc s;
    s.name = "Cube Mountain";
    scene_data& d = s.data;

    d.ground(gvec3(400, 2, 400), d.metal(gcolor(0.24f, 0.24f, 0.27f), 0.20f));

    const int radius = 19;
    const float peak = 13.5f;
    const float sigma = 5.6f;
    const float unit = 0.90f;   // bit under the grid pitch so nothing touches

    for (int x = -radius; x <= radius; x++) {
        for (int z = -radius; z <= radius; z++) {
            float r = std::sqrt(float(x*x + z*z));
            if (r > radius) continue;

            float falloff = std::exp(-(r*r) / (2.0f*sigma*sigma));
            float ridge = 1.9f*std::sin(x*0.85f)*std::cos(z*0.72f)
                        + 1.25f*std::sin((x + z)*0.41f)
                        + 0.8f*std::sin(r*1.15f);

            int height = int(peak*falloff + ridge*std::sqrt(falloff) + rnd(-0.7f, 0.7f));

            if (height <= 0) {
                if (!chance(0.30f * (1.0f - r/float(radius)))) continue;
                height = 1;
            }

            gcolor albedo = bold_palette(rnd_int(0, 7));

            for (int k = 0; k < height; k++) {
                float roll = rnd();
                int mat;
                if (roll < 0.07f) mat = d.light(albedo * 9.0f);
                else if (roll < 0.15f) mat = d.glass(1.5f);
                else if (roll < 0.64f) mat = d.metal(albedo, rnd(0.0f, 0.18f));
                else mat = d.lambertian(albedo);

                drop_shape(d, gpoint3(float(x), k + 0.5f, float(z)), unit, mat, 0.22f);
            }
        }
    }

    // reject overlaps, otherwise the rocks melt into one big lump
    struct rock { float x, z, r; };
    std::vector<rock> rocks;

    for (int tries = 0; tries < 6000 && rocks.size() < 240; tries++) {
        float a = rnd(0.0f, 2.0f*GPU_PI);
        float dist = rnd(float(radius) + 1.5f, 34.0f);
        float r = rnd(0.25f, 1.0f);
        float x = dist*std::cos(a);
        float z = dist*std::sin(a);

        bool ok = true;
        for (size_t i = 0; i < rocks.size(); i++) {
            float dx = x - rocks[i].x, dz = z - rocks[i].z;
            float gap = r + rocks[i].r + 0.12f;
            if (dx*dx + dz*dz < gap*gap) { ok = false; break; }
        }
        if (!ok) continue;

        rocks.push_back(rock{x, z, r});

        gcolor c = bold_palette(rnd_int(0, 7));
        int mat = chance(0.10f) ? d.light(c * 6.0f)
                : chance(0.4f) ? d.metal(c, rnd(0.0f, 0.2f))
                                : d.lambertian(c * 0.7f);
        d.sphere(gpoint3(x, r, z), r, mat);
    }

    d.box(gpoint3( 21, 30, 9), gvec3(16, 0.6f, 16), d.light(gcolor(6.5f, 5.8f, 4.6f)));
    d.box(gpoint3(-25, 28, 5), gvec3(14, 0.6f, 14), d.light(gcolor(0.9f, 1.4f, 3.2f)));
    d.box(gpoint3( 0, 30, -34), gvec3(22, 0.6f, 14), d.light(gcolor(2.0f, 0.6f, 2.7f)));

    s.sky = sky_gradient(gcolor(0.004f, 0.005f, 0.010f));
    s.lookfrom = gpoint3(0, 27, 30);
    s.lookat = gpoint3(0, 6, 0);
    s.vfov = 36.0f;
    s.focus_dist = 37.0f;
    s.defocus_angle = 0.3f;
    return s;
}

#endif

#ifndef SCENE_MOSS_MOUNTAIN_CUH
#define SCENE_MOSS_MOUNTAIN_CUH

#include "helpers.cuh"

inline scene_desc scene_moss_mountain() {
    seed_scene(31);
    scene_desc s;
    s.name = "Moss Mountain";
    scene_data& d = s.data;

    d.ground(gvec3(600, 2, 600), d.lambertian(gcolor(0.34f, 0.34f, 0.34f)));

    auto moss = [&](float k) {
        gcolor deep (0.05f, 0.19f, 0.06f);
        gcolor leaf (0.20f, 0.48f, 0.09f);
        gcolor lime (0.55f, 0.78f, 0.12f);
        gcolor yellow(0.88f, 0.80f, 0.08f);
        gcolor amber (0.92f, 0.58f, 0.06f);
        gcolor straw (0.82f, 0.80f, 0.44f);
        if (k < 0.26f) return mix(deep, leaf, k / 0.26f);
        if (k < 0.52f) return mix(leaf, lime, (k - 0.26f) / 0.26f);
        if (k < 0.72f) return mix(lime, yellow, (k - 0.52f) / 0.20f);
        if (k < 0.90f) return mix(yellow, amber, (k - 0.72f) / 0.18f);
        return mix(amber, straw, (k - 0.90f) / 0.10f);
    };

    struct summit { float x, z, height, spread; };
    summit peaks[12];

    // spread them down the band infront of the cam so the range recedes
    for (int i = 0; i < 12; i++) {
        peaks[i].x = rnd(-40.0f, 40.0f);
        peaks[i].z = rnd(-60.0f, 10.0f);
        peaks[i].height = rnd(11.0f, 26.0f);
        peaks[i].spread = rnd(5.0f, 9.5f);
    }

    const int x_reach = 46;
    const int z_near = 40;
    const int z_far = -60;
    const gpoint3 eye(0.0f, 8.0f, 56.0f);

    for (int x = -x_reach; x <= x_reach; x++) {
        for (int z = z_far; z <= z_near; z++) {
            // coarser cells further out. same few pixels on screen anyway
            float away = (eye.z() - float(z)) / 380.0f;
            if (away < 0.0f) away = 0.0f;
            if (away > 1.0f) away = 1.0f;
            int step = 1 + int(away * 3.99f);
            if (((x + 1000) % step) != 0) continue;
            if (((z + 1000) % step) != 0) continue;
            float cell = float(step);

            float fx = float(x), fz = float(z);

            float column = 0.0f;
            for (int i = 0; i < 12; i++) {
                float dx = fx - peaks[i].x, dz = fz - peaks[i].z;
                float dd = dx*dx + dz*dz;
                column += peaks[i].height *
                          std::exp(-dd / (2.0f*peaks[i].spread*peaks[i].spread));
            }

            // rolling base so the ground fills right out to the horizon
            column += 3.0f
                    + 2.4f*std::sin(fx*0.055f)*std::cos(fz*0.048f)
                    + 1.5f*std::sin((fx + fz)*0.031f)
                    + 1.6f*std::sin(fx*0.62f)*std::cos(fz*0.55f)
                    + 1.0f*std::sin((fx + fz)*0.33f)
                    + rnd(-0.9f, 0.9f);

            if (column <= 0.4f) {
                if (!chance(0.25f)) continue;
                column = rnd(0.5f, 1.6f);
            }

            float wide = rnd(0.55f, 0.88f) * cell;
            float thick = rnd(0.55f, 0.88f) * cell;
            float lean = rnd(-4.0f, 4.0f);

            float y = 0.0f;
            while (y < column) {
                float tall = rnd(0.6f, 3.0f) * cell;
                if (y + tall > column) tall = column - y;
                if (tall < 0.3f) break;

                gcolor tone = moss(rnd());
                float roll = rnd();
                int mat;
                if (roll < 0.06f) mat = d.light(tone * 5.0f);
                else if (roll < 0.11f) mat = d.glass(1.5f);
                else if (roll < 0.42f) mat = d.metal(tone, rnd(0.10f, 0.45f));
                else mat = d.lambertian(tone);

                d.box(gpoint3(fx, y + tall*0.5f, fz), gvec3(wide, tall - 0.06f, thick),
                      mat, lean);
                y += tall;
            }
        }
    }

    // lights go behind us. a panel out front flattens the whole thing
    d.box(gpoint3( 40, 96, 108), gvec3(110, 0.6f, 60), d.light(gcolor(13.0f, 12.2f, 9.0f)));
    d.box(gpoint3(-80, 70, 98), gvec3( 60, 0.6f, 44), d.light(gcolor(3.4f, 4.0f, 1.9f)));

    s.sky = sky_gradient(gcolor(0.72f, 0.72f, 0.72f));
    s.lookfrom = eye;
    s.lookat = gpoint3(0, 13, -10);
    s.vfov = 52.0f;
    s.focus_dist = 66.0f;
    s.defocus_angle = 0.0f;
    return s;
}

#endif

#ifndef SCENE_CRYSTAL_CAVERN_CUH
#define SCENE_CRYSTAL_CAVERN_CUH

#include "helpers.cuh"

inline scene_desc scene_crystal_cavern()
{
    seed_scene(14);
    scene_desc s;
    s.name = "Crystal Cavern";
    scene_data &d = s.data;

    int stone = d.lambertian(gcolor(0.26f, 0.25f, 0.28f));
    int damp = d.metal(gcolor(0.22f, 0.22f, 0.26f), 0.30f);
    int glass = d.glass(1.7f);

    const float span = 46.0f;
    const float roof = 26.0f;

    d.box(gpoint3(0, -1.0f, 0), gvec3(span, 2, span), damp);
    d.box(gpoint3(0, roof + 1.0f, 0), gvec3(span, 2, span), stone);
    d.box(gpoint3(0, roof / 2, -span / 2), gvec3(span, roof, 2), stone);
    d.box(gpoint3(0, roof / 2, span / 2), gvec3(span, roof, 2), stone);
    d.box(gpoint3(-span / 2, roof / 2, 0), gvec3(2, roof, span), stone);
    d.box(gpoint3(span / 2, roof / 2, 0), gvec3(2, roof, span), stone);

    struct disc
    {
        float x, z, r;
    };
    std::vector<disc> taken;

    auto free_at = [&](float x, float z, float r)
    {
        for (size_t i = 0; i < taken.size(); i++)
        {
            float dx = x - taken[i].x, dz = z - taken[i].z;
            float gap = r + taken[i].r + 0.25f;
            if (dx * dx + dz * dz < gap * gap)
                return false;
        }
        return true;
    };

    for (int i = 0; i < 20; i++)
    {
        float cx = 0.0f, cz = 0.0f, reach = rnd(2.6f, 3.6f);
        bool placed = false;
        for (int tries = 0; tries < 200; tries++)
        {
            cx = rnd(-18.0f, 18.0f);
            cz = rnd(-18.0f, 18.0f);
            if (!free_at(cx, cz, reach))
                continue;
            placed = true;
            break;
        }
        if (!placed)
            continue;
        taken.push_back(disc{cx, cz, reach});

        gcolor tone = chance(0.6f) ? mix(gcolor(0.2f, 0.7f, 1.0f), gcolor(0.1f, 1.0f, 0.7f), rnd())
                                   : mix(gcolor(0.8f, 0.3f, 1.0f), gcolor(1.0f, 0.4f, 0.5f), rnd());
        int glow = d.light(tone * rnd(5.0f, 8.0f));

        std::vector<disc> local;
        d.sphere(gpoint3(cx, rnd(0.6f, 1.2f), cz), rnd(0.5f, 0.9f), glow);
        local.push_back(disc{cx, cz, 0.9f});

        int spikes = rnd_int(5, 11);
        for (int k = 0; k < spikes; k++)
        {
            float wide = rnd(0.35f, 0.85f);
            for (int tries = 0; tries < 60; tries++)
            {
                float a = rnd(0.0f, 2.0f * GPU_PI);
                float rr = rnd(0.8f, reach - wide);
                float px = cx + rr * std::cos(a);
                float pz = cz + rr * std::sin(a);

                bool ok = true;
                for (size_t j = 0; j < local.size(); j++)
                {
                    float dx = px - local[j].x, dz = pz - local[j].z;
                    float gap = wide + local[j].r + 0.12f;
                    if (dx * dx + dz * dz < gap * gap)
                    {
                        ok = false;
                        break;
                    }
                }
                if (!ok)
                    continue;

                local.push_back(disc{px, pz, wide});
                float tall = rnd(2.0f, 7.5f);
                d.box(gpoint3(px, tall * 0.5f, pz), gvec3(wide * 2, tall, wide * 2),
                      chance(0.10f) ? glow : glass, rnd(0.0f, 90.0f));
                break;
            }
        }
    }

    for (int i = 0; i < 400; i++)
    {
        float r = rnd(0.4f, 1.7f);
        for (int tries = 0; tries < 40; tries++)
        {
            float x = rnd(-21.0f, 21.0f);
            float z = rnd(-21.0f, 21.0f);
            if (!free_at(x, z, r))
                continue;
            taken.push_back(disc{x, z, r});
            d.sphere(gpoint3(x, r * 0.75f, z), r, stone);
            break;
        }
    }

    s.sky = sky_gradient(gcolor(0, 0, 0));
    s.lookfrom = gpoint3(0, 7, 21);
    s.lookat = gpoint3(0, 4, -8);
    s.vfov = 56.0f;
    s.focus_dist = 28.0f;
    s.defocus_angle = 0.3f;
    return s;
}

#endif

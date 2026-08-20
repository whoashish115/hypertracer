#ifndef SCENE_HELPERS_CUH
#define SCENE_HELPERS_CUH

#include "../gpu.cuh"

#include <cctype>
#include <random>

inline std::mt19937& scene_rng() {
    static std::mt19937 gen;
    return gen;
}
inline void seed_scene(unsigned int seed) { scene_rng().seed(seed); }

inline float rnd() {
    static std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    return dist(scene_rng());
}
inline float rnd(float lo, float hi) { return lo + (hi - lo) * rnd(); }
inline int rnd_int(int lo, int hi) { return int(rnd(float(lo), float(hi) + 0.999f)); }
inline bool chance(float p) { return rnd() < p; }

inline gcolor mix(const gcolor& a, const gcolor& b, float t) {
    return (1.0f - t)*a + t*b;
}

inline gcolor hue(float turns) {
    float h = (turns - std::floor(turns)) * 6.0f;
    float x = 1.0f - std::fabs(std::fmod(h, 2.0f) - 1.0f);
    if (h < 1) return gcolor(1, x, 0);
    if (h < 2) return gcolor(x, 1, 0);
    if (h < 3) return gcolor(0, 1, x);
    if (h < 4) return gcolor(0, x, 1);
    if (h < 5) return gcolor(x, 0, 1);
    return gcolor(1, 0, x);
}

inline gcolor bold_palette(int i) {
    switch (((i % 8) + 8) % 8) {
        case 0: return gcolor(0.85f, 0.06f, 0.07f);
        case 1: return gcolor(0.07f, 0.11f, 0.85f);
        case 2: return gcolor(0.06f, 0.72f, 0.14f);
        case 3: return gcolor(0.42f, 0.12f, 0.85f);
        case 4: return gcolor(0.92f, 0.46f, 0.04f);
        case 5: return gcolor(0.04f, 0.68f, 0.80f);
        case 6: return gcolor(0.85f, 0.08f, 0.50f);
        default: return gcolor(0.86f, 0.86f, 0.90f);
    }
}

inline float terrain(float x, float z, float amp = 1.0f) {
    float h = 1.00f * std::sin(x*0.13f) * std::cos(z*0.11f)
            + 0.55f * std::sin(x*0.31f + 1.7f) * std::cos(z*0.27f - 0.4f)
            + 0.30f * std::sin((x + z)*0.47f)
            + 0.18f * std::sin(x*0.83f - 2.1f) * std::sin(z*0.71f);
    return h * amp;
}

inline void drop_shape(scene_data& d, const gpoint3& c, float size, int mat, float ball_odds) {
    if (rnd() < ball_odds) d.sphere(c, size * 0.5f, mat);
    else d.cube(c, size, mat, rnd(0.0f, 90.0f));
}

#endif

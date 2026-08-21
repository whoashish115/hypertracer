#ifndef SCENES_ALL_CUH
#define SCENES_ALL_CUH

#include "helpers.cuh"

#include "cube_mountain.cuh"
#include "sphere_pit.cuh"

const int scene_count = 2;

inline scene_desc build_scene(int index) {
    switch (index) {
        case 0: return scene_cube_mountain();
        default: return scene_sphere_pit();
    }
}

// name -> filename, so renders dont overwrite eachother
inline std::string scene_slug(const scene_desc& s) {
    std::string slug;
    for (char c : s.name) {
        if (c == ' ') slug += '_';
        else slug += char(std::tolower((unsigned char)c));
    }
    return slug;
}

#endif

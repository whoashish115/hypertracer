#ifndef SCENES_ALL_CUH
#define SCENES_ALL_CUH

#include "helpers.cuh"

#include "cube_mountain.cuh"
#include "sphere_pit.cuh"
#include "moss_mountain.cuh"
#include "cornell_heap.cuh"
#include "crystal_cavern.cuh"

const int scene_count = 5;

inline scene_desc build_scene(int index) {
    switch (index) {
        case 0: return scene_cube_mountain();
        case 1: return scene_sphere_pit();
        case 2: return scene_moss_mountain();
        case 3: return scene_cornell_heap();
        default: return scene_crystal_cavern();
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

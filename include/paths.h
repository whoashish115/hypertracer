#ifndef PATHS_H
#define PATHS_H

#include <string>

// change these and all 3 exes follow
namespace paths {

const std::string output_dir = "output";
const std::string still_image = "render";
const std::string photo = "photo";
const std::string full_render = "render";

inline std::string in_output(const std::string& name, const std::string& ext) {
    return output_dir + "/" + name + ext;
}

}

#endif

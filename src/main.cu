// usage: hypertracer_cuda [scene] [width] [samples]
// writes a ppm on stdout and drops a bmp in output/

#include "scenes/all.cuh"
#include "image_io.h"
#include "paths.h"

#include <chrono>
#include <filesystem>
#include <cstdlib>
#include <iostream>

int main(int argc, char** argv) {
    int scene_index = (argc > 1) ? std::atoi(argv[1]) - 1 : 0;
    int width = (argc > 2) ? std::atoi(argv[2]) : 1280;
    int samples = (argc > 3) ? std::atoi(argv[3]) : 2000;

    if (scene_index < 0 || scene_index >= scene_count) {
        std::cerr << "Scene must be 1.." << scene_count << "\n";
        return 1;
    }
    if (width < 16) width = 16;
    if (samples < 1) samples = 1;

    const int height = int(width * 9.0f / 16.0f);

    int device_count = 0;
    CUDA_CHECK(cudaGetDeviceCount(&device_count));
    if (device_count == 0) {
        std::cerr << "No CUDA device found.\n";
        return 1;
    }
    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));

    std::filesystem::create_directories(paths::output_dir);

    scene_desc desc = build_scene(scene_index);
    gpu_scene scene = upload_scene(desc.data);

    std::cerr << "Device: " << prop.name << " (sm_" << prop.major << prop.minor << ")\n"
              << "Scene " << (scene_index + 1) << ": " << desc.name << "  --  "
              << scene.prim_count << " primitives, " << scene.node_count << " BVH nodes\n"
              << "Rendering " << width << "x" << height << " at " << samples << " spp\n";

    auto start = std::chrono::steady_clock::now();

    auto image = render_image(desc, scene, width, height, samples, 30,
                              [&](int done, int total) {
                                  std::cerr << "\r  " << done << " / " << total << " spp   "
                                            << std::flush;
                              });

    double elapsed = std::chrono::duration<double>(
                         std::chrono::steady_clock::now() - start).count();
    std::cerr << "\r  done in " << elapsed << " s\n";

    write_ppm(std::cout, image, width, height);

    std::string bmp = paths::in_output(paths::still_image + "_" + scene_slug(desc), ".bmp");
    if (write_bmp(bmp, image, width, height))
        std::cerr << "Wrote " << bmp << "\n";
    else
        std::cerr << "Could not write " << bmp << " (does " << paths::output_dir
                  << "/ exist?)\n";

    scene.release();
    return 0;
}

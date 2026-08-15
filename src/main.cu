#include "gpu.cuh"

#include <cstdio>

int main() {
    int n = 0;
    CUDA_CHECK(cudaGetDeviceCount(&n));
    if (n == 0) {
        std::fprintf(stderr, "no cuda device found\n");
        return 1;
    }

    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    std::printf("%s  sm_%d%d  %zu MB\n", prop.name, prop.major, prop.minor,
                (size_t)(prop.totalGlobalMem >> 20));
    return 0;
}

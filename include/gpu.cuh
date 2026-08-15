#ifndef GPU_CUH
#define GPU_CUH

#include <cuda_runtime.h>
#include <curand_kernel.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <string>
#include <vector>

#define GPU_INF INFINITY
#define GPU_PI 3.1415926535897932385f

#define CUDA_CHECK(call)                                                          \
    do {                                                                          \
        cudaError_t err_ = (call);                                                \
        if (err_ != cudaSuccess) {                                                \
            std::fprintf(stderr, "\nCUDA error %s at %s:%d\n  %s\n",              \
                         cudaGetErrorName(err_), __FILE__, __LINE__,              \
                         cudaGetErrorString(err_));                               \
            std::exit(1);                                                         \
        }                                                                         \
    } while (0)

struct gvec3 {
    float e[3];

    __host__ __device__ gvec3() : e{0,0,0} {}
    __host__ __device__ gvec3(float x, float y, float z) : e{x,y,z} {}

    __host__ __device__ float x() const { return e[0]; }
    __host__ __device__ float y() const { return e[1]; }
    __host__ __device__ float z() const { return e[2]; }

    __host__ __device__ gvec3 operator-() const { return gvec3(-e[0], -e[1], -e[2]); }
    __host__ __device__ float operator[](int i) const { return e[i]; }
    __host__ __device__ float& operator[](int i) { return e[i]; }

    __host__ __device__ gvec3& operator+=(const gvec3& v) {
        e[0] += v.e[0]; e[1] += v.e[1]; e[2] += v.e[2];
        return *this;
    }
    __host__ __device__ gvec3& operator*=(const gvec3& v) {
        e[0] *= v.e[0]; e[1] *= v.e[1]; e[2] *= v.e[2];
        return *this;
    }
    __host__ __device__ gvec3& operator*=(float t) {
        e[0] *= t; e[1] *= t; e[2] *= t;
        return *this;
    }

    __host__ __device__ float length_squared() const {
        return e[0]*e[0] + e[1]*e[1] + e[2]*e[2];
    }
    __host__ __device__ float length() const { return sqrtf(length_squared()); }

    __host__ __device__ bool near_zero() const {
        return fabsf(e[0]) < 1e-8f && fabsf(e[1]) < 1e-8f && fabsf(e[2]) < 1e-8f;
    }
};

using gpoint3 = gvec3;
using gcolor = gvec3;

__host__ __device__ inline gvec3 operator+(const gvec3& u, const gvec3& v) {
    return gvec3(u.e[0]+v.e[0], u.e[1]+v.e[1], u.e[2]+v.e[2]);
}
__host__ __device__ inline gvec3 operator-(const gvec3& u, const gvec3& v) {
    return gvec3(u.e[0]-v.e[0], u.e[1]-v.e[1], u.e[2]-v.e[2]);
}
__host__ __device__ inline gvec3 operator*(const gvec3& u, const gvec3& v) {
    return gvec3(u.e[0]*v.e[0], u.e[1]*v.e[1], u.e[2]*v.e[2]);
}
__host__ __device__ inline gvec3 operator*(float t, const gvec3& v) {
    return gvec3(t*v.e[0], t*v.e[1], t*v.e[2]);
}
__host__ __device__ inline gvec3 operator*(const gvec3& v, float t) { return t * v; }
__host__ __device__ inline gvec3 operator/(const gvec3& v, float t) { return (1.0f/t) * v; }

__host__ __device__ inline float dot(const gvec3& u, const gvec3& v) {
    return u.e[0]*v.e[0] + u.e[1]*v.e[1] + u.e[2]*v.e[2];
}
__host__ __device__ inline gvec3 cross(const gvec3& u, const gvec3& v) {
    return gvec3(u.e[1]*v.e[2] - u.e[2]*v.e[1],
                 u.e[2]*v.e[0] - u.e[0]*v.e[2],
                 u.e[0]*v.e[1] - u.e[1]*v.e[0]);
}
__host__ __device__ inline gvec3 unit_vector(const gvec3& v) { return v / v.length(); }

__host__ __device__ inline gvec3 reflect(const gvec3& v, const gvec3& n) {
    return v - 2.0f*dot(v, n)*n;
}
__host__ __device__ inline gvec3 refract(const gvec3& uv, const gvec3& n, float ratio) {
    float ct = fminf(dot(-uv, n), 1.0f);
    gvec3 perp = ratio * (uv + ct*n);
    gvec3 para = -sqrtf(fabsf(1.0f - perp.length_squared())) * n;
    return perp + para;
}

__host__ __device__ inline float degrees_to_radians(float deg) {
    return deg * GPU_PI / 180.0f;
}

using rng_state = curandStatePhilox4_32_10_t;

__device__ inline float random_float(rng_state& s) { return curand_uniform(&s); }
__device__ inline float random_float(rng_state& s, float lo, float hi) {
    return lo + (hi - lo) * random_float(s);
}

// spherical not rejection. warps hate retry loops
__device__ inline gvec3 random_unit_vector(rng_state& s) {
    float z = random_float(s, -1.0f, 1.0f);
    float a = random_float(s, 0.0f, 2.0f*GPU_PI);
    float r = sqrtf(fmaxf(0.0f, 1.0f - z*z));
    float sa, ca;
    sincosf(a, &sa, &ca);
    return gvec3(r*ca, r*sa, z);
}

__device__ inline gvec3 random_in_unit_disk(rng_state& s) {
    float a = random_float(s, 0.0f, 2.0f*GPU_PI);
    float r = sqrtf(random_float(s));
    float sa, ca;
    sincosf(a, &sa, &ca);
    return gvec3(r*ca, r*sa, 0.0f);
}

struct gray {
    gpoint3 orig;
    gvec3 dir;

    __host__ __device__ gray() {}
    __host__ __device__ gray(const gpoint3& o, const gvec3& d) : orig(o), dir(d) {}

    __host__ __device__ const gpoint3& origin() const { return orig; }
    __host__ __device__ const gvec3& direction() const { return dir; }
    __host__ __device__ gpoint3 at(float t) const { return orig + t*dir; }
};

#endif

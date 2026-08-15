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

enum mat_type : int { MAT_LAMBERTIAN = 0, MAT_METAL, MAT_DIELECTRIC, MAT_DIFFUSE_LIGHT };
enum prim_type : int { PRIM_SPHERE = 0, PRIM_BOX, PRIM_TRIANGLE };

struct gmaterial {
    int type;
    gcolor albedo;
    float fuzz;
    float refraction_index;
};

// one struct for all 3 shapes. fields mean different things per type which is
// a bit gross but it keeps traversal to one array
struct gprim {
    int type;
    int mat;
    gpoint3 center;   // tri: vert 0
    gvec3 half;   // sphere radius in [0], tri: edge 1
    gvec3 extra;   // tri: edge 2
    float sin_theta;
    float cos_theta;
};

struct ghit_record {
    gpoint3 p;
    gvec3 normal;
    float t;
    int mat;
    bool front_face;

    __device__ void set_face_normal(const gray& r, const gvec3& outward) {
        front_face = dot(r.direction(), outward) < 0.0f;
        normal = front_face ? outward : -outward;
    }
};

// leaf: count > 0, prims start at offset.
// interior: count == 0, left kid is idx+1, right kid is at offset
struct gbvh_node {
    gvec3 bmin, bmax;
    int offset;
    int count;
};

struct sky_gradient {
    gcolor bottom;
    gcolor top;

    __host__ __device__ sky_gradient() : bottom(0,0,0), top(0,0,0) {}
    __host__ __device__ sky_gradient(const gcolor& b, const gcolor& t) : bottom(b), top(t) {}
    __host__ __device__ sky_gradient(const gcolor& flat) : bottom(flat), top(flat) {}

    __device__ gcolor sample(const gvec3& dir) const {
        float t = 0.5f * (unit_vector(dir).y() + 1.0f);
        return (1.0f - t)*bottom + t*top;
    }
};

struct gscene {
    gprim* prims;
    gmaterial* mats;
    gbvh_node* nodes;
    int prim_count;
    int node_count;
};

__device__ inline bool hit_sphere(const gprim& s, const gray& r, float t_min, float t_max,
                                  ghit_record& rec) {
    float radius = s.half[0];
    gvec3 oc = s.center - r.origin();
    float a = r.direction().length_squared();
    float h = dot(r.direction(), oc);
    float c = oc.length_squared() - radius*radius;

    float disc = h*h - a*c;
    if (disc < 0.0f) return false;

    float sq = sqrtf(disc);
    float root = (h - sq) / a;
    if (root <= t_min || root >= t_max) {
        root = (h + sq) / a;
        if (root <= t_min || root >= t_max) return false;
    }

    rec.t = root;
    rec.p = r.at(root);
    rec.set_face_normal(r, (rec.p - s.center) / radius);
    rec.mat = s.mat;
    return true;
}

// slab test in the box's own frame, which gets us the Y spin for free
__device__ inline bool hit_box(const gprim& b, const gray& r, float t_min, float t_max,
                               ghit_record& rec) {
    gvec3 o = r.origin() - b.center;
    gvec3 origin(b.cos_theta*o.x() - b.sin_theta*o.z(), o.y(),
                 b.sin_theta*o.x() + b.cos_theta*o.z());
    gvec3 d = r.direction();
    gvec3 dir(b.cos_theta*d.x() - b.sin_theta*d.z(), d.y(),
              b.sin_theta*d.x() + b.cos_theta*d.z());

    float tmin = -GPU_INF, tmax = GPU_INF;
    int amin = 0, amax = 0;
    float smin = -1.0f, smax = 1.0f;

    #pragma unroll
    for (int a = 0; a < 3; a++) {
        float inv = 1.0f / dir[a];
        float lo = (-b.half[a] - origin[a]) * inv;
        float hi = ( b.half[a] - origin[a]) * inv;
        float slo = -1.0f, shi = 1.0f;

        if (inv < 0.0f) {
            float tmp = lo; lo = hi; hi = tmp;
            slo = 1.0f; shi = -1.0f;
        }

        if (lo > tmin) { tmin = lo; amin = a; smin = slo; }
        if (hi < tmax) { tmax = hi; amax = a; smax = shi; }
        if (tmax <= tmin) return false;
    }

    float root = tmin;
    int axis = amin;
    float sign = smin;
    if (root <= t_min || root >= t_max) {
        // started inside, take the exit instead. glass boxes need this
        root = tmax; axis = amax; sign = smax;
        if (root <= t_min || root >= t_max) return false;
    }

    rec.t = root;
    rec.p = r.at(root);
    gvec3 n(0,0,0);
    n[axis] = sign;
    rec.set_face_normal(r, gvec3(b.cos_theta*n.x() + b.sin_theta*n.z(), n.y(),
                                 -b.sin_theta*n.x() + b.cos_theta*n.z()));
    rec.mat = b.mat;
    return true;
}

// moller trumbore
__device__ inline bool hit_triangle(const gprim& tri, const gray& r, float t_min, float t_max,
                                    ghit_record& rec) {
    gvec3 pv = cross(r.direction(), tri.extra);
    float det = dot(tri.half, pv);
    if (fabsf(det) < 1e-8f) return false;

    float inv = 1.0f / det;
    gvec3 tv = r.origin() - tri.center;
    float u = dot(tv, pv) * inv;
    if (u < 0.0f || u > 1.0f) return false;

    gvec3 qv = cross(tv, tri.half);
    float v = dot(r.direction(), qv) * inv;
    if (v < 0.0f || u + v > 1.0f) return false;

    float t = dot(tri.extra, qv) * inv;
    if (t <= t_min || t >= t_max) return false;

    rec.t = t;
    rec.p = r.at(t);
    rec.set_face_normal(r, unit_vector(cross(tri.half, tri.extra)));
    rec.mat = tri.mat;
    return true;
}

#endif

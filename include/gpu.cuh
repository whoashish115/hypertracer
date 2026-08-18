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

__device__ inline bool hit_node_bounds(const gbvh_node& n, const gpoint3& orig,
                                       const gvec3& inv, float t_min, float t_max) {
    float t0 = (n.bmin.x() - orig.x()) * inv.x();
    float t1 = (n.bmax.x() - orig.x()) * inv.x();
    t_min = fmaxf(t_min, fminf(t0, t1));
    t_max = fminf(t_max, fmaxf(t0, t1));

    t0 = (n.bmin.y() - orig.y()) * inv.y();
    t1 = (n.bmax.y() - orig.y()) * inv.y();
    t_min = fmaxf(t_min, fminf(t0, t1));
    t_max = fminf(t_max, fmaxf(t0, t1));

    t0 = (n.bmin.z() - orig.z()) * inv.z();
    t1 = (n.bmax.z() - orig.z()) * inv.z();
    t_min = fmaxf(t_min, fminf(t0, t1));
    t_max = fminf(t_max, fmaxf(t0, t1));

    return t_max > t_min;
}

// no recursion on the device so we carry our own stack. 32 is plenty, the
// split is median so the tree stays balanced
__device__ inline bool hit_scene(const gscene& scene, const gray& r, float t_min, float t_max,
                                 ghit_record& rec) {
    const int max_stack = 32;
    gvec3 inv(1.0f / r.direction().x(), 1.0f / r.direction().y(), 1.0f / r.direction().z());

    int stack[max_stack];
    int sp = 0;
    stack[sp++] = 0;

    bool got_one = false;
    ghit_record temp;

    while (sp > 0) {
        int idx = stack[--sp];
        const gbvh_node& node = scene.nodes[idx];

        if (!hit_node_bounds(node, r.origin(), inv, t_min, t_max))
            continue;

        if (node.count > 0) {
            for (int i = 0; i < node.count; i++) {
                const gprim& p = scene.prims[node.offset + i];
                bool hit = (p.type == PRIM_SPHERE) ? hit_sphere(p, r, t_min, t_max, temp)
                         : (p.type == PRIM_TRIANGLE) ? hit_triangle(p, r, t_min, t_max, temp)
                                                     : hit_box(p, r, t_min, t_max, temp);
                if (hit) {
                    got_one = true;
                    t_max = temp.t;
                    rec = temp;
                }
            }
        } else if (sp + 2 <= max_stack) {
            stack[sp++] = node.offset;
            stack[sp++] = idx + 1;
        }
    }

    return got_one;
}

// schlick
__device__ inline float reflectance(float cosine, float ri) {
    float r0 = (1.0f - ri) / (1.0f + ri);
    r0 = r0*r0;
    return r0 + (1.0f - r0)*powf(1.0f - cosine, 5.0f);
}

__device__ inline gcolor emitted(const gmaterial& m) {
    return m.type == MAT_DIFFUSE_LIGHT ? m.albedo : gcolor(0,0,0);
}

__device__ inline bool scatter(const gmaterial& m, const gray& r_in, const ghit_record& rec,
                               gcolor& attenuation, gray& scattered, rng_state& rng) {
    if (m.type == MAT_DIFFUSE_LIGHT) return false;   // path stops here

    if (m.type == MAT_LAMBERTIAN) {
        gvec3 dir = rec.normal + random_unit_vector(rng);
        if (dir.near_zero()) dir = rec.normal;
        scattered = gray(rec.p, dir);
        attenuation = m.albedo;
        return true;
    }

    if (m.type == MAT_METAL) {
        gvec3 reflected = reflect(r_in.direction(), rec.normal);
        reflected = unit_vector(reflected) + m.fuzz*random_unit_vector(rng);
        scattered = gray(rec.p, reflected);
        attenuation = m.albedo;
        return dot(scattered.direction(), rec.normal) > 0.0f;
    }

    attenuation = gcolor(1,1,1);
    float ri = rec.front_face ? (1.0f / m.refraction_index) : m.refraction_index;

    gvec3 unit_dir = unit_vector(r_in.direction());
    float ct = fminf(dot(-unit_dir, rec.normal), 1.0f);
    float st = sqrtf(fmaxf(0.0f, 1.0f - ct*ct));

    bool stuck = ri*st > 1.0f;
    gvec3 dir = (stuck || reflectance(ct, ri) > random_float(rng))
              ? reflect(unit_dir, rec.normal)
              : refract(unit_dir, rec.normal, ri);

    scattered = gray(rec.p, dir);
    return true;
}

struct prim_bounds {
    gvec3 lo, hi;
};

inline prim_bounds bounds_of(const gprim& p) {
    prim_bounds b;
    if (p.type == PRIM_SPHERE) {
        float r = p.half[0];
        b.lo = p.center - gvec3(r, r, r);
        b.hi = p.center + gvec3(r, r, r);
    } else if (p.type == PRIM_TRIANGLE) {
        gvec3 v1 = p.center + p.half;
        gvec3 v2 = p.center + p.extra;
        for (int a = 0; a < 3; a++) {
            b.lo[a] = std::fmin(p.center[a], std::fmin(v1[a], v2[a]));
            b.hi[a] = std::fmax(p.center[a], std::fmax(v1[a], v2[a]));
        }
    } else {
        b.lo = gvec3( GPU_INF, GPU_INF, GPU_INF);
        b.hi = gvec3(-GPU_INF, -GPU_INF, -GPU_INF);
        for (int i = 0; i < 8; i++) {
            gvec3 c((i & 1) ? p.half[0] : -p.half[0],
                    (i & 2) ? p.half[1] : -p.half[1],
                    (i & 4) ? p.half[2] : -p.half[2]);
            gvec3 w(p.cos_theta*c.x() + p.sin_theta*c.z(), c.y(),
                    -p.sin_theta*c.x() + p.cos_theta*c.z());
            gvec3 q = p.center + w;
            for (int a = 0; a < 3; a++) {
                b.lo[a] = std::fmin(b.lo[a], q[a]);
                b.hi[a] = std::fmax(b.hi[a], q[a]);
            }
        }
    }
    // flat stuff needs some thickness or the slab test never hits it
    for (int a = 0; a < 3; a++) {
        if (b.hi[a] - b.lo[a] < 1e-4f) { b.lo[a] -= 5e-5f; b.hi[a] += 5e-5f; }
    }
    return b;
}

// median split on the widest axis. built once on the host so nothing fancy,
// traversal is what costs us not the build
class bvh_builder {
  public:
    static const int leaf_size = 4;

    bvh_builder(std::vector<gprim>& prims) : prims(prims) {
        bounds.reserve(prims.size());
        for (size_t i = 0; i < prims.size(); i++) bounds.push_back(bounds_of(prims[i]));

        order.resize(prims.size());
        for (size_t i = 0; i < order.size(); i++) order[i] = int(i);

        nodes.reserve(2*prims.size());
        build(0, int(prims.size()));

        std::vector<gprim> sorted;
        sorted.reserve(prims.size());
        for (size_t i = 0; i < order.size(); i++) sorted.push_back(prims[order[i]]);
        prims.swap(sorted);
    }

    std::vector<gbvh_node> nodes;

  private:
    std::vector<gprim>& prims;
    std::vector<prim_bounds> bounds;
    std::vector<int> order;

    int build(int start, int end) {
        int me = int(nodes.size());
        nodes.push_back(gbvh_node());

        gvec3 lo( GPU_INF, GPU_INF, GPU_INF);
        gvec3 hi(-GPU_INF, -GPU_INF, -GPU_INF);
        gvec3 clo( GPU_INF, GPU_INF, GPU_INF);
        gvec3 chi(-GPU_INF, -GPU_INF, -GPU_INF);
        for (int i = start; i < end; i++) {
            const prim_bounds& b = bounds[order[i]];
            for (int a = 0; a < 3; a++) {
                lo[a] = std::fmin(lo[a], b.lo[a]);
                hi[a] = std::fmax(hi[a], b.hi[a]);
                float c = 0.5f*(b.lo[a] + b.hi[a]);
                clo[a] = std::fmin(clo[a], c);
                chi[a] = std::fmax(chi[a], c);
            }
        }

        nodes[me].bmin = lo;
        nodes[me].bmax = hi;

        int count = end - start;
        if (count <= leaf_size) {
            nodes[me].offset = start;
            nodes[me].count = count;
            return me;
        }

        int axis = 0;
        float extent = chi[0] - clo[0];
        if (chi[1] - clo[1] > extent) { axis = 1; extent = chi[1] - clo[1]; }
        if (chi[2] - clo[2] > extent) { axis = 2; extent = chi[2] - clo[2]; }

        if (extent <= 0.0f) {
            // every centroid in the same spot, nothing to split on
            nodes[me].offset = start;
            nodes[me].count = count;
            return me;
        }

        int mid = start + count/2;
        const std::vector<prim_bounds>& bb = bounds;
        std::nth_element(order.begin() + start, order.begin() + mid, order.begin() + end,
                         [&bb, axis](int a, int b) {
                             return bb[a].lo[axis] + bb[a].hi[axis]
                                  < bb[b].lo[axis] + bb[b].hi[axis];
                         });

        build(start, mid);
        int right = build(mid, end);
        nodes[me].offset = right;
        nodes[me].count = 0;
        return me;
    }
};

#endif

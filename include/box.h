#ifndef BOX_H
#define BOX_H

#include "hittable.h"

#include <algorithm>

class box : public hittable {
  public:
    box(const point3& center, const vec3& size, shared_ptr<material> mat)
      : center(center), half(std::fabs(size.x())/2, std::fabs(size.y())/2, std::fabs(size.z())/2),
        mat(mat)
    {
        bbox = aabb(center - half, center + half);
    }

    box(const point3& center, double side, shared_ptr<material> mat)
      : box(center, vec3(side, side, side), mat) {}

    aabb bounding_box() const override { return bbox; }

    bool hit(const ray& r, interval ray_t, hit_record& rec) const override {
        vec3 origin = r.origin() - center;
        vec3 direction = r.direction();

        auto tmin = -infinity, tmax = infinity;
        int axis_min = 0, axis_max = 0;
        double sign_min = -1, sign_max = 1;

        for (int a = 0; a < 3; a++) {
            auto inv = 1.0 / direction[a];
            auto lo = (-half[a] - origin[a]) * inv;
            auto hi = ( half[a] - origin[a]) * inv;
            double slo = -1, shi = 1;

            if (inv < 0) {
                std::swap(lo, hi);
                std::swap(slo, shi);
            }

            if (lo > tmin) { tmin = lo; axis_min = a; sign_min = slo; }
            if (hi < tmax) { tmax = hi; axis_max = a; sign_max = shi; }

            if (tmax <= tmin)
                return false;
        }

        auto root = tmin;
        auto axis = axis_min;
        auto sign = sign_min;
        if (!ray_t.surrounds(root)) {
            root = tmax;
            axis = axis_max;
            sign = sign_max;
            if (!ray_t.surrounds(root))
                return false;
        }

        rec.t = root;
        rec.p = r.at(rec.t);
        vec3 n(0, 0, 0);
        n[axis] = sign;
        rec.set_face_normal(r, n);
        rec.mat = mat;
        return true;
    }

  private:
    point3 center;
    vec3 half;
    shared_ptr<material> mat;
    aabb bbox;
};

#endif

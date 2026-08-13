#ifndef BOX_H
#define BOX_H

#include "hittable.h"

#include <algorithm>

class box : public hittable {
  public:
    box(const point3& center, const vec3& size, shared_ptr<material> mat, double angle_y = 0)
      : center(center), half(std::fabs(size.x())/2, std::fabs(size.y())/2, std::fabs(size.z())/2),
        mat(mat)
    {
        auto radians = degrees_to_radians(angle_y);
        sin_theta = std::sin(radians);
        cos_theta = std::cos(radians);

        point3 lo( infinity, infinity, infinity);
        point3 hi(-infinity, -infinity, -infinity);
        for (int i = 0; i < 8; i++) {
            vec3 corner((i & 1) ? half.x() : -half.x(),
                        (i & 2) ? half.y() : -half.y(),
                        (i & 4) ? half.z() : -half.z());
            auto p = center + to_world(corner);
            for (int a = 0; a < 3; a++) {
                lo[a] = std::fmin(lo[a], p[a]);
                hi[a] = std::fmax(hi[a], p[a]);
            }
        }
        bbox = aabb(lo, hi);
    }

    box(const point3& center, double side, shared_ptr<material> mat, double angle_y = 0)
      : box(center, vec3(side, side, side), mat, angle_y) {}

    aabb bounding_box() const override { return bbox; }

    bool hit(const ray& r, interval ray_t, hit_record& rec) const override {
        vec3 origin = to_local(r.origin() - center);
        vec3 direction = to_local(r.direction());

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
        rec.set_face_normal(r, to_world(n));
        rec.mat = mat;
        return true;
    }

  private:
    point3 center;
    vec3 half;
    shared_ptr<material> mat;
    double sin_theta, cos_theta;
    aabb bbox;

    vec3 to_local(const vec3& v) const {
        return vec3(cos_theta*v.x() - sin_theta*v.z(), v.y(), sin_theta*v.x() + cos_theta*v.z());
    }

    vec3 to_world(const vec3& v) const {
        return vec3(cos_theta*v.x() + sin_theta*v.z(), v.y(), -sin_theta*v.x() + cos_theta*v.z());
    }
};

#endif

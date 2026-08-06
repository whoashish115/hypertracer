#ifndef AABB_H
#define AABB_H

#include <algorithm>

class aabb {
  public:
    interval x, y, z;

    aabb() {}

    aabb(const interval& x, const interval& y, const interval& z) : x(x), y(y), z(z) {
        pad();
    }

    aabb(const point3& a, const point3& b) {
        x = interval(std::fmin(a[0], b[0]), std::fmax(a[0], b[0]));
        y = interval(std::fmin(a[1], b[1]), std::fmax(a[1], b[1]));
        z = interval(std::fmin(a[2], b[2]), std::fmax(a[2], b[2]));
        pad();
    }

    aabb(const aabb& a, const aabb& b) {
        x = interval(std::fmin(a.x.min, b.x.min), std::fmax(a.x.max, b.x.max));
        y = interval(std::fmin(a.y.min, b.y.min), std::fmax(a.y.max, b.y.max));
        z = interval(std::fmin(a.z.min, b.z.min), std::fmax(a.z.max, b.z.max));
    }

    const interval& axis_interval(int n) const {
        if (n == 1) return y;
        if (n == 2) return z;
        return x;
    }

    int longest_axis() const {
        if (x.size() > y.size())
            return x.size() > z.size() ? 0 : 2;
        return y.size() > z.size() ? 1 : 2;
    }

    bool hit(const ray& r, interval ray_t) const {
        const point3& orig = r.origin();
        const vec3& dir = r.direction();

        for (int a = 0; a < 3; a++) {
            const interval& ax = axis_interval(a);
            const double inv = 1.0 / dir[a];

            auto t0 = (ax.min - orig[a]) * inv;
            auto t1 = (ax.max - orig[a]) * inv;

            if (t0 > t1) std::swap(t0, t1);
            if (t0 > ray_t.min) ray_t.min = t0;
            if (t1 < ray_t.max) ray_t.max = t1;

            if (ray_t.max <= ray_t.min)
                return false;
        }
        return true;
    }

    static const aabb empty, universe;

  private:
    void pad() {
        // zero thickness slabs never get hit
        double delta = 0.0001;
        if (x.size() < delta) x = grow(x, delta);
        if (y.size() < delta) y = grow(y, delta);
        if (z.size() < delta) z = grow(z, delta);
    }

    static interval grow(const interval& i, double delta) {
        return interval(i.min - delta/2, i.max + delta/2);
    }
};

const aabb aabb::empty = aabb(interval::empty, interval::empty, interval::empty);
const aabb aabb::universe = aabb(interval::universe, interval::universe, interval::universe);

#endif

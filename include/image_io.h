#ifndef IMAGE_IO_H
#define IMAGE_IO_H

#include <cstdint>
#include <fstream>
#include <ostream>
#include <string>
#include <vector>

// pixels come in as 0x00RRGGBB, row 0 on top

inline void write_ppm(std::ostream& out, const std::vector<unsigned int>& pixels,
                      int width, int height) {
    out << "P3\n" << width << ' ' << height << "\n255\n";
    for (int i = 0; i < width*height; i++) {
        unsigned int p = pixels[i];
        out << ((p >> 16) & 0xFF) << ' ' << ((p >> 8) & 0xFF) << ' ' << (p & 0xFF) << '\n';
    }
}

// bmp as well as ppm because windows will actually open a bmp on a double click
inline bool write_bmp(const std::string& path, const std::vector<unsigned int>& pixels,
                      int width, int height) {
    std::ofstream out(path, std::ios::binary);
    if (!out) return false;

    const uint32_t pixel_bytes = uint32_t(width) * uint32_t(height) * 4;
    const uint32_t offset = 14 + 40;

    auto u16 = [&](uint16_t v) { out.write(reinterpret_cast<const char*>(&v), 2); };
    auto u32 = [&](uint32_t v) { out.write(reinterpret_cast<const char*>(&v), 4); };
    auto i32 = [&](int32_t v) { out.write(reinterpret_cast<const char*>(&v), 4); };

    out.put('B'); out.put('M');
    u32(offset + pixel_bytes); u16(0); u16(0); u32(offset);

    u32(40); i32(width); i32(-height);
    u16(1); u16(32); u32(0); u32(pixel_bytes);
    i32(2835); i32(2835); u32(0); u32(0);

    for (int i = 0; i < width*height; i++) {
        unsigned int p = pixels[i];
        out.put(char(p & 0xFF));
        out.put(char((p >> 8) & 0xFF));
        out.put(char((p >> 16) & 0xFF));
        out.put(char(0));
    }
    return out.good();
}

#endif

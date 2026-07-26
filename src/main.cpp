#include <iostream>

int main() {
    int image_width = 256;
    int image_height = 256;

    std::cout << "P3\n" << image_width << ' ' << image_height << "\n255\n";

    for (int j = 0; j < image_height; j++) {
        std::clog << "\rlines left: " << (image_height - j) << ' ' << std::flush;
        for (int i = 0; i < image_width; i++) {
            auto r = double(i) / (image_width - 1);
            auto g = double(j) / (image_height - 1);
            auto b = 0.0;

            std::cout << int(255.999 * r) << ' '
                      << int(255.999 * g) << ' '
                      << int(255.999 * b) << '\n';
        }
    }

    std::clog << "\rdone.                \n";
}

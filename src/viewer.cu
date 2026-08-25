// arrows/WASD move, Q/E up down, drag to look, 1-6 scenes, [ ] cycle,
// P photo, R full render, F reframe, esc quits

#include "scenes/all.cuh"
#include "image_io.h"
#include "paths.h"

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#include <cstdio>
#include <string>
#include <vector>

// we steer with yaw/pitch, the render cam wants a lookat point so we rebuild
// the direction each frame
struct fly_camera {
    gpoint3 position;
    float yaw = -90.0f;
    float pitch = -20.0f;
    float vfov = 40.0f;
    float speed = 14.0f;

    gvec3 forward() const {
        float y = degrees_to_radians(yaw);
        float p = degrees_to_radians(pitch);
        return unit_vector(gvec3(cosf(p)*cosf(y), sinf(p), cosf(p)*sinf(y)));
    }
    gvec3 right() const { return unit_vector(cross(forward(), gvec3(0, 1, 0))); }

    void frame(const scene_desc& s) {
        position = s.lookfrom;
        vfov = s.vfov;
        gvec3 d = unit_vector(s.lookat - s.lookfrom);
        yaw = atan2f(d.z(), d.x()) * 180.0f / GPU_PI;
        pitch = asinf(fminf(fmaxf(d.y(), -1.0f), 1.0f)) * 180.0f / GPU_PI;
        clamp_pitch();
        speed = fmaxf(6.0f, (s.lookfrom - s.lookat).length() * 0.4f);   // big scene, big steps
    }

    void clamp_pitch() {
        // dead up or down and the basis goes undefined
        if (pitch > 88.0f) pitch = 88.0f;
        if (pitch < -88.0f) pitch = -88.0f;
    }
};

static bool g_running = true;
static bool g_dragging = false;
static POINT g_last_mouse{};
static float g_mouse_dx = 0.0f;
static float g_mouse_dy = 0.0f;
static int g_width = 1280;
static int g_height = 720;
static bool g_resized = false;

static int g_pick_scene = -1;   // 0 based, -1 means nothing asked for
static int g_step_scene = 0;
static bool g_snapshot = false;
static bool g_full_render= false;
static bool g_reframe = false;

static LRESULT CALLBACK window_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
        case WM_CLOSE:
        case WM_DESTROY:
            g_running = false;
            return 0;

        case WM_SIZE: {
            int w = LOWORD(lp), h = HIWORD(lp);
            if (w > 0 && h > 0 && (w != g_width || h != g_height)) {
                g_width = w; g_height = h; g_resized = true;
            }
            return 0;
        }

        case WM_KEYDOWN:
            if (wp == VK_ESCAPE) g_running = false;
            if (wp >= '1' && wp <= '9') g_pick_scene = int(wp - '1');
            if (wp == '0') g_pick_scene = 9;
            if (g_pick_scene >= scene_count) g_pick_scene = -1;
            if (wp == VK_OEM_4) g_step_scene = -1;   // [
            if (wp == VK_OEM_6) g_step_scene = +1;   // ]
            if (wp == 'P') g_snapshot = true;
            if (wp == 'R') g_full_render = true;
            if (wp == 'F') g_reframe = true;
            return 0;

        case WM_LBUTTONDOWN:
            g_dragging = true;
            GetCursorPos(&g_last_mouse);
            SetCapture(hwnd);
            return 0;

        case WM_LBUTTONUP:
            g_dragging = false;
            ReleaseCapture();
            return 0;

        case WM_MOUSEMOVE:
            if (g_dragging) {
                POINT p;
                GetCursorPos(&p);
                g_mouse_dx += float(p.x - g_last_mouse.x);
                g_mouse_dy += float(p.y - g_last_mouse.y);
                g_last_mouse = p;
            }
            return 0;
    }
    return DefWindowProc(hwnd, msg, wp, lp);
}

static bool key_down(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

static void blit(HWND hwnd, const std::vector<unsigned int>& pixels, int src_w, int src_h) {
    BITMAPINFO info{};
    info.bmiHeader.biSize = sizeof(info.bmiHeader);
    info.bmiHeader.biWidth = src_w;
    info.bmiHeader.biHeight = -src_h;   // negative = rows go top to bottom
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;

    HDC dc = GetDC(hwnd);
    StretchDIBits(dc, 0, 0, g_width, g_height, 0, 0, src_w, src_h,
                  pixels.data(), &info, DIB_RGB_COLORS, SRCCOPY);
    ReleaseDC(hwnd, dc);
}

// number them so saving twice doesnt clobber the first one
static std::string next_free_path(const std::string& stem, const std::string& extension) {
    for (int n = 1; n < 10000; n++) {
        char name[256];
        std::snprintf(name, sizeof(name), "%s_%03d", stem.c_str(), n);
        std::string path = paths::in_output(name, extension);
        if (GetFileAttributesA(path.c_str()) == INVALID_FILE_ATTRIBUTES) return path;
    }
    return paths::in_output(stem, extension);
}

int main() {
    CreateDirectoryA(paths::output_dir.c_str(), nullptr);

    int scene_index = 0;
    scene_desc desc = build_scene(scene_index);
    gpu_scene scene = upload_scene(desc.data);

    fly_camera fly;
    fly.frame(desc);

    HINSTANCE instance = GetModuleHandle(nullptr);
    WNDCLASSA wc{};
    wc.lpfnWndProc = window_proc;
    wc.hInstance = instance;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.lpszClassName = "hypertracer_viewer";
    RegisterClassA(&wc);

    RECT rect{0, 0, g_width, g_height};
    AdjustWindowRect(&rect, WS_OVERLAPPEDWINDOW, FALSE);
    HWND hwnd = CreateWindowA(wc.lpszClassName, "hypertracer", WS_OVERLAPPEDWINDOW,
                              CW_USEDEFAULT, CW_USEDEFAULT,
                              rect.right - rect.left, rect.bottom - rect.top,
                              nullptr, nullptr, instance, nullptr);
    if (!hwnd) {
        MessageBoxA(nullptr, "Could not create the window.", "hypertracer",
                    MB_OK | MB_ICONERROR);
        return 1;
    }
    ShowWindow(hwnd, SW_SHOW);

    gcolor* d_accum = nullptr;
    unsigned int* d_pixels = nullptr;
    std::vector<unsigned int> frame;

    auto allocate = [&](int w, int h) {
        if (d_accum) cudaFree(d_accum);
        if (d_pixels) cudaFree(d_pixels);
        CUDA_CHECK(cudaMalloc(&d_accum, size_t(w)*h * sizeof(gcolor)));
        CUDA_CHECK(cudaMalloc(&d_pixels, size_t(w)*h * sizeof(unsigned int)));
        frame.assign(size_t(w)*h, 0);
    };
    allocate(g_width, g_height);

    int accumulated = 0;
    bool dirty = true;
    int scale = 1;   // 2 while flying, 1 when we settle
    int spp_per_frame = 1;
    int render_w = g_width, render_h = g_height;

    LARGE_INTEGER freq, last;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&last);

    std::string status;

    while (g_running) {
        MSG msg;
        while (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
        if (!g_running) break;

        LARGE_INTEGER now;
        QueryPerformanceCounter(&now);
        double dt = double(now.QuadPart - last.QuadPart) / double(freq.QuadPart);
        last = now;
        if (dt > 0.1) dt = 0.1;   // dont lurch after a stall

        if (g_resized) {
            allocate(g_width, g_height);
            g_resized = false;
            dirty = true;
        }

        int wanted = scene_index;
        if (g_pick_scene >= 0) { wanted = g_pick_scene; g_pick_scene = -1; }
        if (g_step_scene) {
            wanted = (scene_index + g_step_scene + scene_count) % scene_count;
            g_step_scene = 0;
        }
        if (wanted != scene_index) {
            scene_index = wanted;
            desc = build_scene(scene_index);
            scene = upload_scene(desc.data);
            fly.frame(desc);
            dirty = true;
            status.clear();
        }

        if (g_reframe) {
            fly.frame(desc);
            g_reframe = false;
            dirty = true;
        }

        bool moving = false;
        if (GetForegroundWindow() == hwnd) {
            float step = fly.speed * float(dt);
            if (key_down(VK_SHIFT)) step *= 4.0f;
            if (key_down(VK_CONTROL)) step *= 0.25f;

            gvec3 move(0, 0, 0);
            if (key_down(VK_UP) || key_down('W')) move += fly.forward();
            if (key_down(VK_DOWN) || key_down('S')) move += -fly.forward();
            if (key_down(VK_RIGHT) || key_down('D')) move += fly.right();
            if (key_down(VK_LEFT) || key_down('A')) move += -fly.right();
            if (key_down('E') || key_down(VK_PRIOR)) move += gvec3(0, 1, 0);
            if (key_down('Q') || key_down(VK_NEXT)) move += gvec3(0, -1, 0);

            if (move.length_squared() > 0.0f) {
                fly.position += unit_vector(move) * step;
                moving = true;
            }

            if (g_mouse_dx != 0.0f || g_mouse_dy != 0.0f) {
                fly.yaw += g_mouse_dx * 0.18f;
                fly.pitch -= g_mouse_dy * 0.18f;
                fly.clamp_pitch();
                g_mouse_dx = g_mouse_dy = 0.0f;
                moving = true;
            }
        }
        if (moving) dirty = true;

        // half res while flying, full res the moment you stop
        int wanted_scale = moving ? 2 : 1;
        if (wanted_scale != scale) {
            scale = wanted_scale;
            dirty = true;
        }
        render_w = (g_width + scale - 1) / scale;
        render_h = (g_height + scale - 1) / scale;

        scene_desc live = desc;
        live.lookfrom = fly.position;
        live.lookat = fly.position + fly.forward();
        live.vfov = fly.vfov;
        live.focus_dist = 1.0f;
        live.defocus_angle = 0.0f;

        gcamera cam = camera_for(live, render_w, render_h, spp_per_frame, 30);
        cam.image_height = render_h;

        if (dirty) {
            CUDA_CHECK(cudaMemset(d_accum, 0, size_t(render_w)*render_h * sizeof(gcolor)));
            accumulated = 0;
            dirty = false;
        }

        dim3 block(8, 8);
        dim3 grid((render_w + block.x - 1) / block.x, (render_h + block.y - 1) / block.y);

        render_kernel<<<grid, block>>>(d_accum, cam, scene.view(),
                                       0x9E3779B97F4A7C15ull
                                         + (unsigned long long)accumulated * 1315423911ull);
        CUDA_CHECK(cudaGetLastError());
        accumulated += spp_per_frame;

        resolve_kernel<<<grid, block>>>(d_accum, d_pixels, render_w, render_h,
                                        1.0f / float(accumulated));
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaMemcpy(frame.data(), d_pixels,
                              size_t(render_w)*render_h * sizeof(unsigned int),
                              cudaMemcpyDeviceToHost));

        blit(hwnd, frame, render_w, render_h);

        if (g_snapshot) {
            std::string path = next_free_path(paths::photo + "_" + scene_slug(desc), ".bmp");
            if (write_bmp(path, frame, render_w, render_h))
                status = "saved " + path + "  (" + std::to_string(accumulated) + " spp)";
            else
                status = "could not write " + path;
            g_snapshot = false;
        }

        if (g_full_render) {
            g_full_render = false;
            const int out_w = 1920, out_h = 1080, out_spp = 3000;

            SetWindowTextA(hwnd, "hypertracer  |  rendering...");
            auto image = render_image(live, scene, out_w, out_h, out_spp, 40,
                [&](int done, int total) {
                    char t[160];
                    std::snprintf(t, sizeof(t), "hypertracer  |  rendering %d / %d spp",
                                  done, total);
                    SetWindowTextA(hwnd, t);
                    // keep pumping or windows decides weve hung
                    MSG pump;
                    while (PeekMessage(&pump, nullptr, 0, 0, PM_REMOVE)) {
                        TranslateMessage(&pump);
                        DispatchMessage(&pump);
                    }
                });

            std::string path = next_free_path(paths::full_render + "_" + scene_slug(desc),
                                              ".bmp");
            status = write_bmp(path, image, out_w, out_h) ? "rendered " + path
                                                          : "could not write " + path;
            QueryPerformanceCounter(&last);   // that took ages, dont skew the pacing
        }

        // aim each frame at ~30fps
        const double target = 0.033;   // aim for ~30fps
        int next = int(spp_per_frame * (target / (dt > 1e-6 ? dt : target)) + 0.5);
        if (next < 1) next = 1;
        if (next > 64) next = 64;
        if (next > spp_per_frame + 4) next = spp_per_frame + 4;
        spp_per_frame = next;

        char title[512];
        std::snprintf(title, sizeof(title),
                      "hypertracer  |  [%d] %s  |  %d spp  |  %.0f fps  |  %d prims  |  "
                      "%d/%d  1-%d or [ ] scene, WASD+QE move, drag look, "
                      "P photo, R render, F reframe%s%s",
                      scene_index + 1, desc.name.c_str(), accumulated,
                      dt > 0 ? 1.0/dt : 0.0, scene.prim_count,
                      scene_index + 1, scene_count, scene_count,
                      status.empty() ? "" : "  |  ", status.c_str());
        SetWindowTextA(hwnd, title);
    }

    if (d_accum) cudaFree(d_accum);
    if (d_pixels) cudaFree(d_pixels);
    scene.release();
    return 0;
}

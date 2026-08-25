// arrows/WASD move, Q/E up down, drag to look, 1-6 scenes, esc quits

#include "scenes/all.cuh"

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#include <cstdio>
#include <string>
#include <vector>

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
        speed = fmaxf(6.0f, (s.lookfrom - s.lookat).length() * 0.4f);
    }

    void clamp_pitch() {
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
static int g_pick_scene = -1;

static LRESULT CALLBACK window_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
        case WM_CLOSE:
        case WM_DESTROY:
            g_running = false;
            return 0;

        case WM_KEYDOWN:
            if (wp == VK_ESCAPE) g_running = false;
            if (wp >= '1' && wp <= '9') g_pick_scene = int(wp - '1');
            if (g_pick_scene >= scene_count) g_pick_scene = -1;
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

int main() {
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

    CUDA_CHECK(cudaMalloc(&d_accum, size_t(g_width)*g_height * sizeof(gcolor)));
    CUDA_CHECK(cudaMalloc(&d_pixels, size_t(g_width)*g_height * sizeof(unsigned int)));
    frame.assign(size_t(g_width)*g_height, 0);

    LARGE_INTEGER freq, last;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&last);

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
        if (dt > 0.1) dt = 0.1;

        if (g_pick_scene >= 0 && g_pick_scene != scene_index) {
            scene_index = g_pick_scene;
            desc = build_scene(scene_index);
            scene = upload_scene(desc.data);
            fly.frame(desc);
        }
        g_pick_scene = -1;

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

            if (move.length_squared() > 0.0f)
                fly.position += unit_vector(move) * step;

            if (g_mouse_dx != 0.0f || g_mouse_dy != 0.0f) {
                fly.yaw += g_mouse_dx * 0.18f;
                fly.pitch -= g_mouse_dy * 0.18f;
                fly.clamp_pitch();
                g_mouse_dx = g_mouse_dy = 0.0f;
            }
        }

        scene_desc live = desc;
        live.lookfrom = fly.position;
        live.lookat = fly.position + fly.forward();
        live.vfov = fly.vfov;
        live.focus_dist = 1.0f;
        live.defocus_angle = 0.0f;

        gcamera cam = camera_for(live, g_width, g_height, 1, 12);
        cam.image_height = g_height;

        dim3 block(8, 8);
        dim3 grid((g_width + block.x - 1) / block.x, (g_height + block.y - 1) / block.y);

        CUDA_CHECK(cudaMemset(d_accum, 0, size_t(g_width)*g_height * sizeof(gcolor)));
        render_kernel<<<grid, block>>>(d_accum, cam, scene.view(), 0x9E3779B97F4A7C15ull);
        CUDA_CHECK(cudaGetLastError());
        resolve_kernel<<<grid, block>>>(d_accum, d_pixels, g_width, g_height, 1.0f);
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaMemcpy(frame.data(), d_pixels,
                              size_t(g_width)*g_height * sizeof(unsigned int),
                              cudaMemcpyDeviceToHost));

        BITMAPINFO info{};
        info.bmiHeader.biSize = sizeof(info.bmiHeader);
        info.bmiHeader.biWidth = g_width;
        info.bmiHeader.biHeight = -g_height;
        info.bmiHeader.biPlanes = 1;
        info.bmiHeader.biBitCount = 32;
        info.bmiHeader.biCompression = BI_RGB;

        HDC dc = GetDC(hwnd);
        StretchDIBits(dc, 0, 0, g_width, g_height, 0, 0, g_width, g_height,
                      frame.data(), &info, DIB_RGB_COLORS, SRCCOPY);
        ReleaseDC(hwnd, dc);

        char title[256];
        std::snprintf(title, sizeof(title), "hypertracer  |  [%d/%d] %s  |  %.0f fps",
                      scene_index + 1, scene_count, desc.name.c_str(),
                      dt > 0 ? 1.0/dt : 0.0);
        SetWindowTextA(hwnd, title);
    }

    if (d_accum) cudaFree(d_accum);
    if (d_pixels) cudaFree(d_pixels);
    scene.release();
    return 0;
}

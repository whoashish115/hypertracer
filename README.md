# hypertracer

A path tracer that runs on the CPU and on CUDA. Six scenes, and a viewer you can
fly around in while it renders.

## Scenes
Everything below was rendered at 1920x1080, 3000 samples, straight out of the
viewer with `R`. Full size versions are in [examples/](examples).

**1. Cube Mountain** - stacked cubes at night, lit from inside

![Cube Mountain](examples/1_cube_mountain.png)

**2. Sphere Pit** - fifteen layers of red, green and glass spheres

![Sphere Pit](examples/2_sphere_pit.png)

**3. Moss Mountain** - twelve peaks of yellow green boxes under a grey sky

![Moss Mountain](examples/3_moss_mountain.png)

**4. Cornell Heap** - the cornell box with a pile of stuff dumped in it

![Cornell Heap](examples/4_cornell_heap.png)

**5. Crystal Cavern** - sealed cave, glass columns, glowing cores

![Crystal Cavern](examples/5_crystal_cavern.png)

**6. Ice Lake** - frozen lake with peaks around it at sunrise

![Ice Lake](examples/6_ice_lake.png)


## Build

Needs CMake 3.18 or newer, a C++17 compiler, and the CUDA toolkit if you want
the GPU bits. No CUDA is fine, you just get the CPU renderer.

```powershell
.\release.ps1
```

Three exes end up in `build/Release`:

| | |
| --- | --- |
| `hypertracer` | CPU renderer, one scene, ppm on stdout |
| `hypertracer_cuda` | GPU stills, any of the six |
| `hypertracer_view` | the viewer, windows only |

## Run

```powershell
.\view.ps1                  # fly around
.\render.ps1 3 1920 3000    # scene 3, 1920 wide, 3000 samples
.\cpu.ps1                   # the cpu one
```

`hypertracer_cuda` takes `[scene] [width] [samples]`. It puts a ppm on stdout
and a bmp in `output/`.

## Viewer keys

| | |
| --- | --- |
| arrows or `WASD` | forward, back, strafe |
| `Q` / `E` | down, up |
| left drag | look around |
| `1`-`6` | pick a scene |
| `[` `]` | prev / next scene |
| `Shift` / `Ctrl` | faster / slower |
| `P` | photo, whatever is on screen right now |
| `R` | full quality render to file |
| `F` | snap back to the scene's own camera |
| `Esc` | quit |

Hold still and the picture cleans itself up. One sample a frame is way too noisy
to look at so it keeps accumulating. Move and it throws that away and drops to
half res so the camera stays responsive. `P` and `R` both write into `output/`
with a number on the end so nothing gets overwritten.


## References

- Peter Shirley, Trevor David Black, Steve Hollasch,
  [Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html),
  [The Next Week](https://raytracing.github.io/books/RayTracingTheNextWeek.html) and
  [The Rest of Your Life](https://raytracing.github.io/books/RayTracingTheRestOfYourLife.html)
- Pharr, Jakob and Humphreys, [Physically Based Rendering](https://pbr-book.org/)
- Moller and Trumbore, Fast Minimum Storage Ray/Triangle Intersection, 1997
- Roger Allen,
  [Accelerated Ray Tracing in One Weekend in CUDA](https://developer.nvidia.com/blog/accelerated-ray-tracing-cuda/)
- [Ray Tracing Gems](https://link.springer.com/book/10.1007/978-1-4842-4427-2)
  vol 1 and [vol 2](https://link.springer.com/book/10.1007/978-1-4842-7185-8),
  free from NVIDIA

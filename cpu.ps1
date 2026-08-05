New-Item -ItemType Directory -Force -Path "output" | Out-Null
& ".\build\Release\hypertracer.exe" > "output\cpu.ppm"

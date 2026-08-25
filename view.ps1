New-Item -ItemType Directory -Force -Path "output" | Out-Null
& ".\build\Release\hypertracer_view.exe"

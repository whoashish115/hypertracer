# render.ps1 [scene 1-10] [width] [samples]
param(
    [int]$Scene = 1,
    [int]$Width = 1280,
    [int]$Samples = 2000
)

New-Item -ItemType Directory -Force -Path "output" | Out-Null
& ".\build\Release\hypertracer_cuda.exe" $Scene $Width $Samples > "output\render.ppm"

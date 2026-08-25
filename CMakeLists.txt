cmake_minimum_required(VERSION 3.18)

project(hypertracer VERSION 1.0 LANGUAGES CXX)

add_executable(hypertracer src/main.cpp)
target_include_directories(hypertracer PRIVATE ${PROJECT_SOURCE_DIR}/include)
target_compile_features(hypertracer PRIVATE cxx_std_17)

if(MSVC)
    target_compile_options(hypertracer PRIVATE
        $<$<CONFIG:Debug>:/Od /Zi /W4>
        $<$<CONFIG:Release>:/O2>
    )
else()
    target_compile_options(hypertracer PRIVATE
        $<$<CONFIG:Debug>:-O0 -g -Wall -Wextra -Wpedantic>
        $<$<CONFIG:Release>:-O3 -march=native -DNDEBUG>
    )
endif()

find_package(OpenMP)
if(OpenMP_CXX_FOUND)
    target_link_libraries(hypertracer PRIVATE OpenMP::OpenMP_CXX)
endif()

include(CheckLanguage)
check_language(CUDA)

if(CMAKE_CUDA_COMPILER)
    if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
        set(CMAKE_CUDA_ARCHITECTURES native)
    endif()

    enable_language(CUDA)
    function(add_cuda_target name source)
        add_executable(${name} ${source})
        target_include_directories(${name} PRIVATE ${PROJECT_SOURCE_DIR}/include)
        target_compile_features(${name} PRIVATE cxx_std_17 cuda_std_17)
        target_compile_options(${name} PRIVATE
            $<$<COMPILE_LANGUAGE:CUDA>:-lineinfo>
            $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<CONFIG:Release>>:-O3>
        )
    endfunction()

    add_cuda_target(hypertracer_cuda src/main.cu)

    if(WIN32)
        add_cuda_target(hypertracer_view src/viewer.cu)
        target_link_libraries(hypertracer_view PRIVATE user32 gdi32)
    endif()

    message(STATUS "CUDA ${CMAKE_CUDA_COMPILER_VERSION} found -- building GPU targets")

else()

    message(STATUS "No CUDA compiler found -- building the CPU renderer only")

endif()

cmake_minimum_required(VERSION 3.16)

project(hypertracer LANGUAGES CXX)

add_executable(hypertracer src/main.cpp)
target_include_directories(hypertracer PRIVATE ${PROJECT_SOURCE_DIR}/include)
target_compile_features(hypertracer PRIVATE cxx_std_17)

if(MSVC)
    target_compile_options(hypertracer PRIVATE $<$<CONFIG:Release>:/O2>)
else()
    target_compile_options(hypertracer PRIVATE $<$<CONFIG:Release>:-O3>)
endif()

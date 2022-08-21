cmake_minimum_required(VERSION 3.0)
set(CMAKE_CXX_STANDARD 17)
project(Metal_RayTracing)

add_executable(${PROJECT_NAME} 
    Source/Application.cpp
    Source/Renderer.cpp    
    Source/MyAppDelegate.cpp
    Source/MyMTKViewDelegate.cpp
)

target_include_directories(${PROJECT_NAME} PUBLIC
    ${CMAKE_SOURCE_DIR}/metal
    ${CMAKE_SOURCE_DIR}/metal-extensions
)

# Metal cpp library (linker)
target_link_libraries(${PROJECT_NAME}
        "-framework Metal"
        "-framework MetalKit"
        "-framework AppKit"
        "-framework Foundation"
        "-framework QuartzCore"
)
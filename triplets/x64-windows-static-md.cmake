set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_BUILD_TYPE release)

# OSG: use GL3 profile instead of default GL2.
set(osg_OPENGL_PROFILE GL3)

# All CUDA-related ports need CUDA_PATH passed through.
if(PORT MATCHES "^(cuda|opencv4|ceres|pcl)$")
    set(ENV{CUDA_PATH} "$ENV{CUDA_PATH}")
    set(VCPKG_ENV_PASSTHROUGH_UNTRACKED CUDA_PATH NVCC_PREPEND_FLAGS)
endif()

# CUDA settings for ports that build CUDA code.
if(PORT MATCHES "^(opencv4|ceres|pcl)$")
    set(CUDA_RUNTIME_LIBRARY Shared)
    # CUDA 12.9 doesn't officially support VS 2026 (MSVC 19.50) yet.
    # Set env var so nvcc accepts this compiler during ALL phases,
    # including CMake's check_language(CUDA) compiler identification.
    set(ENV{NVCC_PREPEND_FLAGS} "--allow-unsupported-compiler")
    set(VCPKG_CMAKE_CONFIGURE_OPTIONS
        -DCMAKE_CUDA_FLAGS=--allow-unsupported-compiler
        -DCUDA_ARCH_PTX=86
        -DCUDA_FAST_MATH=ON
    )
endif()

# OpenCV uses CUDA_ARCH_BIN with space-separated values (handles splitting internally).
if(PORT STREQUAL "opencv4")
    list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS
        "-DCUDA_ARCH_BIN=61 70 75 86 89 90 100 120"
        -DOPENCV_ENABLE_FAST_MATH=ON
    )
endif()

# PCL expects CUDA_ARCH_BIN as a CMake list (semicolons) for CMAKE_CUDA_ARCHITECTURES.
if(PORT STREQUAL "pcl")
    list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS
        "-DCUDA_ARCH_BIN=61\;70\;75\;86\;89\;90\;100\;120"
    )
endif()

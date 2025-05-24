set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_BUILD_TYPE release)

# These flags will only apply to opencv4
if(PORT STREQUAL "opencv4")
    set(VCPKG_CMAKE_CONFIGURE_OPTIONS
        -DWITH_CUDA=ON
        -DCUDA_FAST_MATH=ON
        -DOPENCV_ENABLE_FAST_MATH=ON
        -DCUDA_ARCH_BIN=61;70;75;86;89;90;100;120
        -DCUDA_ARCH_PTX=86
    )
endif()
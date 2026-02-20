vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO gulrak/filesystem
    REF "v${VERSION}"
    HEAD_REF master
    SHA512 6eae921485ecdaf4b8329a568b1f4f612ee491fc5fdeafce9c8000b9bf1a73b6fa4e07d0d4ddf05be49efe79e9bddfbcc0aba85529cb016668797a8d89eb9b82
)

set(VCPKG_BUILD_TYPE release) # header-only port

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DGHC_FILESYSTEM_BUILD_TESTING=OFF
        -DGHC_FILESYSTEM_BUILD_EXAMPLES=OFF
        -DGHC_FILESYSTEM_WITH_INSTALL=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(
    PACKAGE_NAME ghc_filesystem
    CONFIG_PATH "lib/cmake/ghc_filesystem"
)

# Fix /utf-8 leaking to nvcc: use COMPILE_LANG_AND_ID instead of C/CXX_COMPILER_ID
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/ghc_filesystem/ghc_filesystem-targets.cmake"
    [[INTERFACE_COMPILE_OPTIONS "\$<\$<C_COMPILER_ID:MSVC>:/utf-8>;\$<\$<CXX_COMPILER_ID:MSVC>:/utf-8>"]]
    [[INTERFACE_COMPILE_OPTIONS "\$<\$<COMPILE_LANG_AND_ID:C,MSVC>:/utf-8>;\$<\$<COMPILE_LANG_AND_ID:CXX,MSVC>:/utf-8>"]]
)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

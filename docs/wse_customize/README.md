# WSE vcpkg Customizations

This document describes all customizations made to the vcpkg port registry for
the WSE project. The goal is to build ~40 third-party dependencies using
**vcpkg manifest mode** with a custom triplet, targeting:

- **MSVC 19.50** (Visual Studio 2026 Build Tools 18.2)
- **CUDA 12.9.86**
- **Windows x64**, static libraries with dynamic CRT (`/MD`)
- **Release-only** builds

---

## Table of Contents

1. [Manifest File (vcpkg.json)](#1-manifest-file)
2. [Custom Triplet (x64-windows-static-md.cmake)](#2-custom-triplet)
3. [Overlay Ports Configuration (vcpkg-configuration.json)](#3-overlay-ports-configuration)
4. [Overlay Port: CGAL](#4-overlay-port-cgal)
5. [Overlay Port: GDAL](#5-overlay-port-gdal)
6. [Overlay Port: ghc-filesystem](#6-overlay-port-ghc-filesystem)
7. [Overlay Port: libpq](#7-overlay-port-libpq)
8. [Issues Encountered and Solutions](#8-issues-encountered-and-solutions)

---

## 1. Manifest File

**File:** `vcpkg.json`

The manifest declares all direct dependencies with their required features.
Key design decisions:

- **`builtin-baseline`**: pinned to commit `36f02df9a386654ac25a4fc63cbe660d0ef978ac`
  to ensure reproducible builds.
- **CUDA** is NOT listed as a direct dependency — it is pulled transitively
  via `pcl[cuda]`, `ceres[cuda]`, and `opencv4[cuda]`.
- **GStreamer**, **ONNX Runtime**, **LibSGM**, and **VMProtect** are excluded
  because they are not available in vcpkg or are managed externally.

### Notable dependency features

| Package | Features | Rationale |
|---------|----------|-----------|
| `ceres` | `cuda, eigensparse, lapack, schur, suitesparse` | Full solver suite with GPU acceleration |
| `opencv4` | `cuda, directml, contrib, dnn, freetype, ipp, nonfree, ...` | Broad CV feature set for mapping & inference |
| `gdal` | `hdf5, netcdf, postgresql, libkml, libspatialite, ...` | Geospatial I/O with many format drivers |
| `osg` | `plugins, fontconfig, freetype, nvtt, openexr` | OpenSceneGraph with texture compression & HDR |
| `pcl` | `cuda` | Point cloud GPU processing |
| `suitesparse-cholmod` | `matrixops, openmp, partition, supernodal` | Sparse linear algebra for SfM |

---

## 2. Custom Triplet

**File:** `triplets/x64-windows-static-md.cmake`

The upstream triplet only sets architecture and linkage. We add several
customizations:

### 2.1 Global settings

```cmake
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)        # /MD — required for CUDA interop
set(VCPKG_LIBRARY_LINKAGE static)      # static libs for all ports
set(VCPKG_BUILD_TYPE release)          # skip debug builds entirely
```

- **Release-only**: `VCPKG_BUILD_TYPE release` halves build time and disk usage.
  WSE only ships Release builds.

### 2.2 OSG GL3 profile

```cmake
set(osg_OPENGL_PROFILE GL3)
```

Forces OpenSceneGraph to use the **GL3 core profile** instead of the legacy GL2
fixed-function pipeline.

### 2.3 CUDA environment passthrough

```cmake
if(PORT MATCHES "^(cuda|opencv4|ceres|pcl)$")
    set(ENV{CUDA_PATH} "$ENV{CUDA_PATH}")
    set(VCPKG_ENV_PASSTHROUGH_UNTRACKED CUDA_PATH NVCC_PREPEND_FLAGS)
endif()
```

**Why**: vcpkg sanitizes the build environment and strips most environment
variables. CUDA detection relies on `CUDA_PATH`, so we must explicitly pass
it through. The `cuda` meta-port (a transitive dependency of `pcl[cuda]`) also
needs this to locate `nvcc`.

### 2.4 CUDA compiler flags

```cmake
if(PORT MATCHES "^(opencv4|ceres|pcl)$")
    set(CUDA_RUNTIME_LIBRARY Shared)
    set(ENV{NVCC_PREPEND_FLAGS} "--allow-unsupported-compiler")
    set(VCPKG_CMAKE_CONFIGURE_OPTIONS
        -DCMAKE_CUDA_FLAGS=--allow-unsupported-compiler
        -DCUDA_ARCH_PTX=86
        -DCUDA_FAST_MATH=ON
    )
endif()
```

- **`--allow-unsupported-compiler`**: CUDA 12.9 does not officially support
  MSVC 19.50 (VS 2026). The `host_config.h` header rejects unknown compiler
  versions. This flag bypasses the check. It must be set in **two places**:
  - `ENV{NVCC_PREPEND_FLAGS}` — used during CMake's `check_language(CUDA)`
    compiler identification phase (before any project-level flags are applied).
  - `CMAKE_CUDA_FLAGS` — used during the actual compilation phase.
- **`CUDA_RUNTIME_LIBRARY Shared`**: links against `cudart.dll` (not the
  static `cudart_static.lib`), avoiding multiple-definition issues when
  several static libs all embed CUDA runtime.
- **`CUDA_ARCH_PTX=86`**: forward-compatible PTX for Ampere and newer.
- **`CUDA_FAST_MATH=ON`**: enables `--use_fast_math` in nvcc.

### 2.5 Per-port CUDA architecture lists

```cmake
# OpenCV: space-separated (its CMake splits internally)
if(PORT STREQUAL "opencv4")
    list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS
        "-DCUDA_ARCH_BIN=61 70 75 86 89 90 100 120"
        -DOPENCV_ENABLE_FAST_MATH=ON
    )
endif()

# PCL: semicolon-separated CMake list (for CMAKE_CUDA_ARCHITECTURES)
if(PORT STREQUAL "pcl")
    list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS
        "-DCUDA_ARCH_BIN=61\;70\;75\;86\;89\;90\;100\;120"
    )
endif()
```

**Why different formats**: OpenCV's CMake parses `CUDA_ARCH_BIN` as a
space-separated string and splits it internally. PCL passes the value directly
to `CMAKE_CUDA_ARCHITECTURES` which expects a CMake list (semicolon-separated).
Using the wrong format causes `nvcc fatal: Unsupported gpu architecture`.

The architectures cover: Pascal (61), Volta (70), Turing (75), Ampere (86),
Ada Lovelace (89), Hopper (90), Blackwell (100, 120).

---

## 3. Overlay Ports Configuration

**File:** `vcpkg-configuration.json`

```json
{
  "overlay-ports": [ "ports/cgal", "ports/gdal", "ports/ghc-filesystem", "ports/libpq" ]
}
```

vcpkg's manifest mode resolves port versions from Git history (via `builtin-baseline`),
**not** from the local `ports/` directory. To apply our patches and fixes, we
register modified ports as **overlay ports** so they take priority over the
baseline versions.

This file is listed in `.gitignore` (line 14) — each developer or CI
environment may need to adjust overlay paths.

---

## 4. Overlay Port: CGAL

**Directory:** `ports/cgal/`  
**Modified files:** `portfile.cmake` (added patch), new file `0001-insert-with-info-reserve.patch`

### What changed

Added a performance patch to `Delaunay_triangulation_3::insert_with_info()`.

### Why

The upstream implementation creates three `std::vector`s (`indices`, `points`,
`infos`) without pre-allocating memory. When inserting millions of points
(common in WSE's mesh generation), this causes excessive reallocations.

### Patch details (`0001-insert-with-info-reserve.patch`)

Adds `reserve(point_count)` calls to the three vectors:

```cpp
const std::size_t point_count = static_cast<std::size_t>(std::distance(first, last));
std::vector<std::size_t> indices;
indices.reserve(point_count);
std::vector<Point> points;
points.reserve(point_count);
std::vector<typename Triangulation_data_structure::Vertex::Info> infos;
infos.reserve(point_count);
```

### Portfile change

```cmake
PATCHES
    0001-insert-with-info-reserve.patch
```

---

## 5. Overlay Port: GDAL

**Directory:** `ports/gdal/`  
**Modified files:** `portfile.cmake` (added two `vcpkg_replace_string` calls post-install)

### What changed

Fixed HDF5 detection when GDAL is consumed by downstream projects via
`find_package(GDAL CONFIG)`.

### Why

vcpkg builds HDF5 as a static library and provides `hdf5-config.cmake` for
config-mode discovery. However, GDAL's installed `GDALConfig.cmake` uses
`find_dependency(HDF5 COMPONENTS C)` which invokes CMake's **FindHDF5** module
(module mode). The module-mode search fails to find vcpkg's static HDF5
because it looks for shared library names and standard system paths.

### Fix (in `portfile.cmake`, after `vcpkg_cmake_config_fixup`)

```cmake
# Fix 1: Use CONFIG mode for HDF5 so vcpkg's hdf5-config.cmake is found.
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/gdal/GDALConfig.cmake"
    "find_dependency(HDF5 COMPONENTS C)"
    "find_dependency(HDF5 CONFIG REQUIRED)"
)

# Fix 2: Add pkgconf tool to CMAKE_PROGRAM_PATH for downstream consumers.
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/gdal/GDALConfig.cmake"
    "include(CMakeFindDependencyMacro)"
    "include(CMakeFindDependencyMacro)
# gdal needs a pkg-config tool. A host dependency provides pkgconf.
get_filename_component(vcpkg_host_prefix \"\${CMAKE_CURRENT_LIST_DIR}/../../../${HOST_TRIPLET}\" ABSOLUTE)
list(APPEND CMAKE_PROGRAM_PATH \"\${vcpkg_host_prefix}/tools/pkgconf\")"
)
```

---

## 6. Overlay Port: ghc-filesystem

**Directory:** `ports/ghc-filesystem/`  
**Modified files:** `portfile.cmake` (added `vcpkg_replace_string` post-install)

### What changed

Fixed the `/utf-8` compiler flag leaking to CUDA (nvcc) compilations.

### Why

The installed CMake targets file sets:
```cmake
INTERFACE_COMPILE_OPTIONS "$<$<C_COMPILER_ID:MSVC>:/utf-8>;$<$<CXX_COMPILER_ID:MSVC>:/utf-8>"
```

When a target links `ghc_filesystem` and also compiles `.cu` files, CMake
evaluates the generator expression for the CUDA compiler. MSVC is detected as
the host compiler, so `/utf-8` is passed to `nvcc`, which does not understand
this flag and fails.

### Fix

Replace `C_COMPILER_ID` / `CXX_COMPILER_ID` with `COMPILE_LANG_AND_ID` so the
flag is only added when compiling C or C++ (not CUDA):

```cmake
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/ghc_filesystem/ghc_filesystem-targets.cmake"
    [[INTERFACE_COMPILE_OPTIONS "$<$<C_COMPILER_ID:MSVC>:/utf-8>;$<$<CXX_COMPILER_ID:MSVC>:/utf-8>"]]
    [[INTERFACE_COMPILE_OPTIONS "$<$<COMPILE_LANG_AND_ID:C,MSVC>:/utf-8>;$<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/utf-8>"]]
)
```

---

## 7. Overlay Port: libpq

**Directory:** `ports/libpq/`  
**Modified files:** `portfile.cmake` (added patch), new file `windows/vs2026-nmake-version.patch`

### What changed

Fixed Visual Studio version detection for VS 2026 (Build Tools 18.2).

### Why

PostgreSQL's MSVC build system (`VSObjectFactory.pm`) determines the Visual
Studio version by parsing the output of `nmake /nologo /?`. In VS 2026,
`nmake` no longer prints its version number in the help banner, causing
the regex match to fail with:

```
Unable to determine Visual Studio version:
The nmake version could not be determined.
```

### Patch details (`windows/vs2026-nmake-version.patch`)

When the `nmake` version regex fails, the patch falls back to parsing the
output of `cl 2>&1` for the compiler version, which still prints a version
banner:

```perl
# VS 2026+ nmake no longer prints a version banner.
# Fall back to cl.exe version detection.
my $cl_output = `cl 2>&1`;
if ($cl_output =~ /(\d+)\.(\d+)\.\d+/)
{
    return _GetVisualStudioVersion($1, $2);
}
```

The existing `_GetVisualStudioVersion()` function maps the compiler major/minor
version to a VS version, so this fallback integrates cleanly.

### Portfile change

```cmake
PATCHES
    ...
    windows/vs2026-nmake-version.patch
```

---

## 8. Issues Encountered and Solutions

A summary of all build issues encountered during the initial vcpkg install
and how they were resolved.

### 8.1 CUDA_PATH not inherited

**Symptom**: CUDA not found during ceres/opencv4 configuration.  
**Cause**: VS Code terminal was launched before CUDA Toolkit was installed,
so `CUDA_PATH` was not in the terminal's environment.  
**Fix**: Restart VS Code (or manually `$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9"`).

### 8.2 CUDA 12.9 rejects MSVC 19.50

**Symptom**: `nvcc fatal: unsupported host compiler` during CMake CUDA
compiler identification.  
**Cause**: CUDA 12.9's `host_config.h` has a whitelist of supported MSVC
versions and does not include 19.50 (VS 2026).  
**Fix**: `--allow-unsupported-compiler` via both `NVCC_PREPEND_FLAGS` env var
(for compiler ID phase) and `CMAKE_CUDA_FLAGS` (for compilation phase).
See [Section 2.4](#24-cuda-compiler-flags).

### 8.3 libpq nmake version detection

**Symptom**: `Unable to determine Visual Studio version` when building libpq.  
**Cause**: VS 2026 `nmake` no longer prints version in help output.  
**Fix**: Overlay port with fallback to `cl.exe` version. See [Section 7](#7-overlay-port-libpq).

### 8.4 Overlay ports required for patches

**Symptom**: Patches applied to files in `ports/` had no effect — builds
used the original (unpatched) port files.  
**Cause**: vcpkg manifest mode resolves ports from Git history via
`builtin-baseline`, not from the working tree's `ports/` directory.  
**Fix**: Created `vcpkg-configuration.json` with `overlay-ports` entries.
See [Section 3](#3-overlay-ports-configuration).

### 8.5 CGAL patch format issues

**Symptom**: `git apply` failed with "corrupt patch" or wrong hunk counts.  
**Cause**: Patch file had CRLF line endings (git apply requires LF) and
manually written hunk headers had incorrect line counts.  
**Fix**: Regenerated patch using actual `git diff` output with LF line endings.

### 8.6 OpenCV CUDA detection failure

**Symptom**: `check_language(CUDA)` failed even with `CMAKE_CUDA_FLAGS` set.  
**Cause**: `CMAKE_CUDA_FLAGS` is not used during CMake's internal compiler
identification — it only takes effect after `enable_language(CUDA)`.  
**Fix**: Set `ENV{NVCC_PREPEND_FLAGS}` in the triplet. This environment
variable is read by nvcc before any other flags, including during the
compiler identification phase. Also added `NVCC_PREPEND_FLAGS` to
`VCPKG_ENV_PASSTHROUGH_UNTRACKED`.

### 8.7 cuda meta-port can't find nvcc

**Symptom**: The `cuda` port (transitive dependency of `pcl[cuda]`) failed
to locate `nvcc`.  
**Cause**: vcpkg scrubs environment variables. The `cuda` meta-port needs
`CUDA_PATH` but it was only passed through for `opencv4`, `ceres`, and `pcl`.  
**Fix**: Added `cuda` to the port matching pattern:
`if(PORT MATCHES "^(cuda|opencv4|ceres|pcl)$")`.

### 8.8 PCL CUDA_ARCH_BIN format

**Symptom**: `nvcc fatal: Unsupported gpu architecture 'compute_61 70 75 86 89 90 100 120'`.  
**Cause**: PCL passes `CUDA_ARCH_BIN` directly to `CMAKE_CUDA_ARCHITECTURES`,
which expects a CMake list (semicolons). Space-separated values were treated
as a single architecture name.  
**Fix**: Use escaped semicolons for PCL: `"-DCUDA_ARCH_BIN=61\;70\;75\;..."`.
See [Section 2.5](#25-per-port-cuda-architecture-lists).

### 8.9 VCPKG_ROOT mismatch warning

**Symptom**: Warning about mismatched `VCPKG_ROOT` environment variable.  
**Cause**: VS 2026 Build Tools ships a bundled vcpkg instance at
`C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\vcpkg`,
and sets `VCPKG_ROOT` system-wide.  
**Fix**: Harmless warning — vcpkg uses the detected root (our workspace)
and ignores the environment variable. Can be suppressed by unsetting
`VCPKG_ROOT` or using `--vcpkg-root`.

---

## File Summary

| File | Status | Purpose |
|------|--------|---------|
| `vcpkg.json` | **New** | Manifest declaring ~37 direct dependencies with features |
| `vcpkg-configuration.json` | **New** | Registers 4 overlay ports |
| `triplets/x64-windows-static-md.cmake` | **Modified** | Static/MD linkage, release-only, CUDA config, OSG GL3 |
| `ports/cgal/portfile.cmake` | **Overlay** | Adds reserve() performance patch |
| `ports/cgal/0001-insert-with-info-reserve.patch` | **New** | Patch for Delaunay insert_with_info |
| `ports/gdal/portfile.cmake` | **Overlay** | Fixes HDF5 detection in GDALConfig.cmake |
| `ports/ghc-filesystem/portfile.cmake` | **Overlay** | Fixes /utf-8 flag leaking to nvcc |
| `ports/libpq/portfile.cmake` | **Overlay** | Adds VS 2026 nmake version patch |
| `ports/libpq/windows/vs2026-nmake-version.patch` | **New** | Fallback to cl.exe for VS version detection |

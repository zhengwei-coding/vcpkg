# Third-Party Dependencies

> BUILD_MAPPER=ON (standard profile), BUILD_DL_INFERENCE=ON

| # | Library | Key Consumers |
|---|---------|---------------|
| 1 | **Boost** | utilities, wse_common, wse_core, xmap_Baselib, MVSBackEnd |
| 2 | **Ceres** | xmap_SfM |
| 3 | **CGAL** | xmap_Mesh, MVSBackEnd |
| 4 | **Clipper2** | dl_inference |
| 5 | **CUDA Toolkit** | wse_common/gis, xmap_Baselib, dl_inference, WakeMapping |
| 6 | **Eigen3** | xmap_Baselib, SLAM3, dl_inference |
| 7 | **FLANN** | xmap_Baselib |
| 8 | **g2o** | SLAM3 |
| 9 | **GDAL** | wse_common/gis, xmap_Baselib, dl_inference |
| 10 | **GeographicLib** | xmap_Baselib |
| 11 | **GEOS** | dl_inference |
| 12 | **GKlib** | xmap_Mesh |
| 13 | **GLEW** | SLAM3 |
| 14 | **glog** | wse_common/avs, wse_core, xmap_Baselib, SLAM3 |
| 15 | **GStreamer** | wse_common/avs, dl_inference |
| 16 | **cpp-httplib** | TerrainFusion |
| 17 | **jemalloc** | xmap_Baselib |
| 18 | **libjpeg** | xmap_Baselib, MVSBackEnd, dl_inference |
| 19 | **LASlib** | xmap_Baselib |
| 20 | **LibLZMA** | dl_inference |
| 21 | **LibSGM** | new_sgm |
| 22 | **lz4** | TerrainFusion |
| 23 | **METIS** | xmap_SfM, xmap_Mesh |
| 24 | **nlohmann_json** | wse_common, wse_core, utilities, WakeMapping, dl_inference, etc. |
| 25 | **nlohmann_json_schema_validator** | wse_common/gis, wse_core, WakeMapping, dl_inference, wse_launcher |
| 26 | **ONNX Runtime** | dl_inference |
| 27 | **OpenCV** | wse_common, utilities, xmap_SIMD, xmap_Baselib, SLAM3, MVSBackEnd, dl_inference, etc. |
| 28 | **OpenGL** | xmap_Baselib, SLAM3, TerrainFusion |
| 29 | **OpenMP** | dl_inference, MVSBackEnd |
| 30 | **OpenSceneGraph (OSG)** | xmap_Baselib |
| 31 | **OpenSSL** | wse_common/util, wse_core, utilities, WakeMapping |
| 32 | **PCL** | xmap_Densematch |
| 33 | **libpng** | xmap_Ortho, MVSBackEnd |
| 34 | **PROJ** | xmap_Baselib |
| 35 | **Sophus** | SLAM3 |
| 36 | **SuiteSparse** (CHOLMOD, SPQR, CXSparse, UMFPACK, etc.) | xmap_SfM |
| 37 | **TBB** | xmap_Mesh |
| 38 | **libtiff** | MVSBackEnd |
| 39 | **SQLite3** (unofficial-sqlite3) | utilities, TerrainFusion, dl_inference, PointsFusion |
| 40 | **VMProtect** | wse_core/security (conditional) |
string(APPEND CONFIG_ARGS " --host=cray")
set(USE_CUDA "TRUE")
string(APPEND CPPDEFS " -DGPU")
if (COMP_NAME STREQUAL gptl)
  string(APPEND CPPDEFS " -DHAVE_NANOTIME -DBIT64 -DHAVE_SLASHPROC -DHAVE_GETTIMEOFDAY")
endif()
string(APPEND CPPDEFS " -DTHRUST_IGNORE_CUB_VERSION_CHECK")
string(APPEND CUDA_FLAGS " -ccbin CC -O2 -arch sm_80 --use_fast_math")
string(APPEND SLIBS " -L$ENV{CRAY_HDF5_PARALLEL_PREFIX}/lib -lhdf5_hl -lhdf5 -L$ENV{CRAY_NETCDF_HDF5PARALLEL_PREFIX} -L$ENV{CRAY_PARALLEL_NETCDF_PREFIX}/lib -lpnetcdf -lnetcdf -lnetcdff")
string(APPEND SLIBS " -lblas -llapack")
if (NOT MPILIB STREQUAL mpi-serial)
  string(APPEND SLIBS " -L$ENV{ADIOS2_DIR}/lib64 -ladios2_c_mpi -ladios2_c -ladios2_core_mpi -ladios2_core -ladios2_evpath -ladios2_ffs -ladios2_dill -ladios2_atl -ladios2_enet")
endif()
set(CXX_LINKER "FORTRAN")
set(NETCDF_PATH "$ENV{CRAY_PARALLEL_NETCDF_PREFIX}")
set(NETCDF_C_PATH "$ENV{CRAY_PARALLEL_NETCDF_PREFIX}")
set(NETCDF_FORTRAN_PATH "$ENV{CRAY_PARALLEL_NETCDF_PREFIX}")
set(HDF5_PATH "$ENV{CRAY_HDF5_PARALLEL_PREFIX}")
set(PNETCDF_PATH "$ENV{CRAY_PARALLEL_NETCDF_PREFIX}")
set(SCC "cc")
set(SCXX "CC")
set(SFC "ftn")

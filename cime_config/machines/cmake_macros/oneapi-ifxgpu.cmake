if (compile_threaded)
  string(APPEND CFLAGS   " -qopenmp")
  string(APPEND FFLAGS   " -qopenmp")
  string(APPEND CXXFLAGS " -qopenmp")
  string(APPEND LDFLAGS  " -qopenmp")
endif()
if (NOT DEBUG)
  string(APPEND CFLAGS   " -O3")
  string(APPEND FFLAGS   " -O3")
  string(APPEND CXXFLAGS " -O3")
endif()
if (DEBUG)
  string(APPEND FFLAGS   " -O0 -g -check uninit -check bounds -check pointers -fpe0 -check noarg_temp_created")
  string(APPEND CFLAGS   " -O0 -g")
  string(APPEND CXXFLAGS " -O0 -g")
endif()
string(APPEND CFLAGS   " -traceback -fp-model precise -std=gnu99")
string(APPEND CXXFLAGS " -traceback -fp-model precise")
string(APPEND FFLAGS   " -traceback -convert big_endian -assume byterecl -assume realloc_lhs -fp-model precise")
set(SUPPORTS_CXX "TRUE")
set(CXX_LINKER "CXX")
string(APPEND CPPDEFS "-DFORTRANUNDERSCORE -DNO_R16 -DCPRINTEL -DHAVE_SLASHPROC")
string(APPEND FC_AUTO_R8 " -r8")
string(APPEND FFLAGS_NOOPT " -O0")
string(APPEND FIXEDFLAGS " -fixed -132")
string(APPEND FREEFLAGS " -free")
set(HAS_F2008_CONTIGUOUS "TRUE")
set(MPIFC "mpifort")
set(MPICC "mpicc")
set(MPICXX "mpicxx")
set(SCC "icx")
set(SCXX "icpx")
set(SFC "ifx")
string(APPEND CFLAGS   " -cc=icx")
string(APPEND FFLAGS   " -fc=ifx")
string(APPEND CXXFLAGS " -cxx=icpx")
execute_process(COMMAND $ENV{NETCDF_PATH}/bin/nf-config --flibs OUTPUT_VARIABLE SHELL_CMD_OUTPUT_BUILD_INTERNAL_IGNORE0 OUTPUT_STRIP_TRAILING_WHITESPACE)
string(APPEND SLIBS " ${SHELL_CMD_OUTPUT_BUILD_INTERNAL_IGNORE0} -Wl,-rpath -Wl,$ENV{NETCDF_PATH}/lib -lmkl_intel_lp64 -lmkl_sequential -lmkl_core")
execute_process(COMMAND $ENV{NETCDF_PATH}/bin/nc-config --libs OUTPUT_VARIABLE SHELL_CMD_OUTPUT_BUILD_INTERNAL_IGNORE0 OUTPUT_STRIP_TRAILING_WHITESPACE)
string(APPEND SLIBS " ${SHELL_CMD_OUTPUT_BUILD_INTERNAL_IGNORE0}")
string(APPEND SLIBS " -fiopenmp -fopenmp-targets=spir64")
set(NETCDF_PATH "$ENV{NETCDF_PATH}")
set(PNETCDF_PATH "$ENV{PNETCDF_PATH}")
set(USE_SYCL "TRUE")
#string(APPEND SYCL_FLAGS " -\-intel -fsycl -fsycl-targets=spir64_gen -Xsycl-target-backend \"-device xehp\" -fsycl-device-code-split=per_source -DSYCL_DISABLE_PARALLEL_FOR_RANGE_ROUNDING_")
string(APPEND SYCL_FLAGS " -\-intel -fsycl")
string(APPEND CXX_LDFLAGS " -cxx=icpx -Wl,-\-defsym,main=MAIN_\_ -lifcore -\-intel -fsycl -lsycl")

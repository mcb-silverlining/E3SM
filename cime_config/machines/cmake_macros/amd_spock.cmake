if (compile_threaded)
  string(APPEND FFLAGS " -fopenmp")
endif()
string(APPEND CPPDEFS " -DNO_R16 -DCPRAMD -DFORTRANUNDERSCORE")
string(APPEND SLIBS " -L$ENV{PNETCDF_PATH}/lib -lpnetcdf -L$ENV{CRAY_LIBSCI_PREFIX_DIR}/lib -lsci_amd")
set(PNETCDF_PATH "$ENV{PNETCDF_DIR}")
set(CRAY_LIBSCI_PREFIX_DIR "$ENV{CRAY_LIBSCI_PREFIX_DIR}")
set(PIO_FILESYSTEM_HINTS "gpfs")
set(SUPPORTS_CXX "TRUE")
set(CXX_LINKER "FORTRAN")
if (COMP_NAME STREQUAL gptl)
  string(APPEND CPPDEFS " -DFORTRANUNDERSCORE")
endif()

# Ideally, we want this one source file to have different compiler flags as is
# case in current master, but the CIME in maint-1.0 does nto allow.
# The flags for this ice_shortwave source in MPAS is not being modified
#ice_shortwave.o: ice_shortwave.F90
#	$(FC) -c $(INCLDIR) $(INCS) $(FFLAGS) -fno-tree-pta $<

cam_history.o: cam_history.F90
	$(FC) -c $(INCLDIR) $(INCS) $(FFLAGS) -fallow-invalid-boz $<
MEGANFactorsMod.o: MEGANFactorsMod.F90
	$(FC) -c $(INCLDIR) $(INCS) $(FFLAGS) -fallow-invalid-boz $<

inidat.o: inidat.F90
	$(FC) -c $(INCLDIR) $(INCS) $(FFLAGS) -fno-inline-arg-packing $<


#list(APPEND MPAS_ICE_SHORTWAVE
#  ${CMAKE_BINARY_DIR}/core_seaice/column/ice_shortwave.f90
#)

# For optimized GNU builds that use v9 or higher, remove an optimization on one file
#if (NOT DEBUG)
#  if (CMAKE_Fortran_COMPILER_VERSION VERSION_GREATER_EQUAL 9)
#    foreach(ITEM IN LISTS MPAS_ICE_SHORTWAVE)
#      e3sm_add_flags("${ITEM}" "-fno-tree-pta") # avoids an error that shows up in solver with gnu9 and higher
#    endforeach()
#  endif()
#endif()

#list(APPEND ALLOW_INVALID_BOZ_LIST
#  eam/src/control/cam_history.F90
#  elm/src/biogeochem/MEGANFactorsMod.F90
#)
#list(APPEND NO_INLINE_ARG_PACKING_LIST
#  eam/src/dynamics/se/inidat.F90
#)

#if (CMAKE_Fortran_COMPILER_VERSION VERSION_GREATER_EQUAL 10)
#  foreach(ITEM IN LISTS ALLOW_INVALID_BOZ_LIST)
#    e3sm_add_flags("${ITEM}" "-fallow-invalid-boz") # avoids build error for integer, parameter :: gen_hash_key_offset = z'000053db'
#  endforeach()

#  if (NOT DEBUG)
#    # new in gnu10, inline arg packing was causing INF values with SMS_P4x1.ne4pg2_ne4pg2.F-MMFXX
#    foreach(ITEM IN LISTS NO_INLINE_ARG_PACKING_LIST)
#      e3sm_add_flags("${ITEM}" " -fno-inline-arg-packing")
#    endforeach()
#  endif()
#endif()

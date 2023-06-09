! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
!
!  ocn_core
!
!> \brief Main driver for MPAS ocean core
!> \author Doug Jacobsen, Mark Petersen, Todd Ringler
!> \date   September 2011
!> \details
!>  This module contains initialization and timestep drivers for
!>  the MPAS ocean core.
!
!-----------------------------------------------------------------------

module ocn_core

   use mpas_kind_types
   use mpas_derived_types
   use mpas_pool_routines
   use mpas_stream_manager
   use mpas_timekeeping
   use mpas_dmpar
   use mpas_timer
   use mpas_threading

   use ocn_forward_mode
   use ocn_analysis_mode
   use ocn_config
#ifndef EXCLUDE_INIT_MODE
   use ocn_init_mode
#endif

   implicit none
   private

   public :: ocn_core_init, ocn_core_run, ocn_core_finalize

   contains

!***********************************************************************
!
!  function ocn_core_init
!
!> \brief   MPAS-Ocean Initialize Driver
!> \author  Doug Jacobsen
!> \date    06/15/2015
!> \details
!>  This function is a driver function for the initialization of the different
!>  run modes within MPAS-Ocean
!
!-----------------------------------------------------------------------

   function ocn_core_init(domain, startTimeStamp) result(ierr)!{{{

      type (domain_type), intent(inout) :: domain
      character(len=*), intent(out) :: startTimeStamp
      integer :: ierr

      integer :: numThreads

      ierr = 0

      call mpas_pool_get_config_scalar(domain % configs, 'config_ocean_run_mode', config_ocean_run_mode)

      numThreads = mpas_threading_get_max_threads()

      call mpas_log_write( ' *****************************************************************************')
      call mpas_log_write( ' MPI Task $i has access to $i threads', intArgs=(/domain % dminfo % my_proc_id, numThreads/) )
      call mpas_log_write( ' *****************************************************************************')

      if ( trim(config_ocean_run_mode) == 'forward' ) then
         ierr = ocn_forward_mode_init(domain, startTimeStamp)
      else if ( trim(config_ocean_run_mode) == 'analysis' ) then
         ierr = ocn_analysis_mode_init(domain, startTimeStamp)
#ifndef EXCLUDE_INIT_MODE
      else if ( trim(config_ocean_run_mode) == 'init' ) then
         ierr = ocn_init_mode_init(domain, startTimeStamp)
#endif
      end if

   end function ocn_core_init!}}}

!***********************************************************************
!
!  function ocn_core_run
!
!> \brief   MPAS-Ocean Run Driver
!> \author  Doug Jacobsen
!> \date    06/15/2015
!> \details
!>  This function is a driver function for the run portion of the different
!>  run modes within MPAS-Ocean.
!
!-----------------------------------------------------------------------

   function ocn_core_run(domain) result(iErr)!{{{

      type (domain_type), intent(inout) :: domain

      integer :: iErr

      iErr = 0

      if ( trim(config_ocean_run_mode) == 'forward' ) then
         ierr = ocn_forward_mode_run(domain)
      else if ( trim(config_ocean_run_mode) == 'analysis' ) then
         ierr = ocn_analysis_mode_run(domain)
#ifndef EXCLUDE_INIT_MODE
      else if ( trim(config_ocean_run_mode) == 'init' ) then
         ierr = ocn_init_mode_run(domain)
#endif
      end if

   end function ocn_core_run!}}}

!***********************************************************************
!
!  function ocn_core_finalize
!
!> \brief   MPAS-Ocean Finalize Driver
!> \author  Doug Jacobsen
!> \date    06/15/2015
!> \details
!>  This function is a driver function for finalizing the different
!>  run modes within MPAS-Ocean.
!
!-----------------------------------------------------------------------
   function ocn_core_finalize(domain) result(ierr)!{{{

      type (domain_type), intent(inout) :: domain
      integer :: ierr

      ierr = 0

      if ( trim(config_ocean_run_mode) == 'forward' ) then
         ierr = ocn_forward_mode_finalize(domain)
      else if (trim(config_ocean_run_mode) == 'analysis' ) then
         ierr = ocn_analysis_mode_finalize(domain)
#ifndef EXCLUDE_INIT_MODE
      else if (trim(config_ocean_run_mode) == 'init' ) then
         ierr = ocn_init_mode_finalize(domain)
#endif
      end if

   end function ocn_core_finalize!}}}

end module ocn_core

! vim: foldmethod=marker

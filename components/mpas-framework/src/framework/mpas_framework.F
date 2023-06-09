! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
!-----------------------------------------------------------------------
!  mpas_framework
!
!> \brief MPAS Framework routines
!> \author Michael Duda, Doug Jacobsen
!> \date   03/26/13
!> \details
!>  This module contains all routines related to the general MPAS framework interface.
!
!-----------------------------------------------------------------------
module mpas_framework

   use mpas_dmpar
   use mpas_derived_types
   use mpas_domain_routines
   use mpas_pool_routines
   use mpas_timer
   use mpas_timekeeping
   use mpas_io
   use mpas_io_units
   use mpas_block_decomp


   contains


!-----------------------------------------------------------------------
!  routine mpas_framework_init_phase1
!
!> \brief MPAS framework initialization phase 1 routine.
!> \author Michael Duda, Doug Jacobsen
!> \date   03/26/13
!> \details
!>  This routine initializes the first parts of MPAS framework. It initializes
!>  MPI, the log unit numbers.
!
!-----------------------------------------------------------------------
   subroutine mpas_framework_init_phase1(dminfo, mpi_comm)!{{{

      implicit none

      type (dm_info), pointer :: dminfo
      integer, intent(in), optional :: mpi_comm

      allocate(dminfo)
      call mpas_dmpar_init(dminfo, mpi_comm)

   end subroutine mpas_framework_init_phase1!}}}

!-----------------------------------------------------------------------
!  routine mpas_framework_init_phase2
!
!> \brief MPAS framework initialization phase 2 routine.
!> \author Michael Duda, Doug Jacobsen
!> \date   03/26/13
!> \details
!>  This routine finalizes the initialization of the MPAS framework. It calls initializes
!>  the time keeper, and the IO infrastructure.
!
!-----------------------------------------------------------------------
   subroutine mpas_framework_init_phase2(domain, io_system, calendar)!{{{

      implicit none

      type (domain_type), pointer :: domain

      type (iosystem_desc_t), optional, pointer :: io_system
      character(len=*), intent(in), optional :: calendar

      character(len=StrKIND), pointer :: config_calendar_type
      integer, pointer :: config_pio_num_iotasks, config_pio_stride
      integer :: pio_num_iotasks
      integer :: pio_stride

      call mpas_timer_init(domain)

#ifdef MPAS_DEBUG
      call mpas_pool_set_error_level(MPAS_POOL_WARN)
#endif

      if (present(calendar)) then
         call mpas_timekeeping_init(calendar)
      else
         call mpas_pool_get_config(domain % configs, 'config_calendar_type', config_calendar_type)
         call mpas_timekeeping_init(config_calendar_type)
      end if

      !
      ! Note: pio_num_iotasks and pio_stride are only used in MPAS_io_init if io_system is
      !       not present. In stand-alone configurations, we expect that io_system will not
      !       be present and that pio_num_iotasks and pio_stride will be available from
      !       the namelist; in other systems, a PIO io_system may be provided.
      !
      if (.not. present(io_system)) then
         call mpas_pool_get_config(domain % configs, 'config_pio_num_iotasks', config_pio_num_iotasks)
         call mpas_pool_get_config(domain % configs, 'config_pio_stride', config_pio_stride)
         pio_num_iotasks = config_pio_num_iotasks
         pio_stride = config_pio_stride
      else
         pio_num_iotasks = -1    ! Not used when external io_system is provided
         pio_stride      = -1    ! Not used when external io_system is provided
      end if

      ! A value of 0 for pio_num_iotasks actually indicates that every task should be an I/O task
      if (pio_num_iotasks == 0) then
         pio_num_iotasks = domain % dminfo % nprocs
      end if

      domain % ioContext % dminfo => domain % dminfo

      call MPAS_io_init(domain % ioContext, pio_num_iotasks, pio_stride, io_system)

   end subroutine mpas_framework_init_phase2!}}}


!-----------------------------------------------------------------------
!  routine mpas_framework_finalize
!
!> \brief MPAS framework finalization routine.
!> \author Michael Duda, Doug Jacobsen
!> \date   03/26/13
!> \details
!>  This routine finalizes the MPAS framework. It calls routines related to finalizing different parts of MPAS, that are housed within the framework.
!
!-----------------------------------------------------------------------
   subroutine mpas_framework_finalize(dminfo, domain, io_system)!{{{

      implicit none

      type (dm_info), pointer :: dminfo
      type (domain_type), pointer :: domain
      type (iosystem_desc_t), optional, pointer :: io_system

      logical :: finalize_iosystem

      ! if there's an external PIO system so we don't want to finalize it here
      finalize_iosystem = .not. present(io_system)
      call MPAS_io_finalize(domain % ioContext, finalize_iosystem=finalize_iosystem)

      call mpas_deallocate_domain(domain)

      call mpas_dmpar_finalize(dminfo)

      call mpas_finish_block_proc_list(dminfo)

      call mpas_timekeeping_finalize()

   end subroutine mpas_framework_finalize!}}}

end module mpas_framework

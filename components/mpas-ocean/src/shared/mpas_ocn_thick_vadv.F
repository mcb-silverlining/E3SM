! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
!
!  ocn_thick_vadv
!
!> \brief MPAS ocean vertical advection for thickness
!> \author Doug Jacobsen
!> \date   16 September 2011
!> \details
!>  This module contains the routine for computing
!>  tendencies for thickness from vertical advection
!
!-----------------------------------------------------------------------

module ocn_thick_vadv

   use mpas_timer
   use mpas_derived_types
   use mpas_pool_routines
   use ocn_constants
   use ocn_config
   use ocn_mesh

   implicit none
   private
   save

   !--------------------------------------------------------------------
   !
   ! Public parameters
   !
   !--------------------------------------------------------------------

   !--------------------------------------------------------------------
   !
   ! Public member functions
   !
   !--------------------------------------------------------------------

   public :: ocn_thick_vadv_tend, &
             ocn_thick_vadv_init

   !--------------------------------------------------------------------
   !
   ! Private module variables
   !
   !--------------------------------------------------------------------

   logical :: thickVadvOn

!***********************************************************************

contains

!***********************************************************************
!
!  routine ocn_thick_vadv_tend
!
!> \brief   Computes tendency term from vertical advection of thickness
!> \author  Doug Jacobsen
!> \date    15 September 2011
!> \details
!>  This routine computes the vertical advection tendency for
!>  thicknes based on current state and user choices of forcings.
!
!-----------------------------------------------------------------------

   subroutine ocn_thick_vadv_tend(vertAleTransportTop, tend, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      real (kind=RKIND), dimension(:,:), intent(in) :: &
         vertAleTransportTop     !< Input: vertical velocity on top layer

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      real (kind=RKIND), dimension(:,:), intent(inout) :: &
         tend          !< Input/Output: velocity tendency

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: Error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      integer :: iCell, k

      !-----------------------------------------------------------------
      !
      ! call relevant routines for computing tendencies
      ! note that the user can choose multiple options and the
      !   tendencies will be added together
      !
      !-----------------------------------------------------------------

      err = 0

      if(.not.thickVadvOn) return

      call mpas_timer_start("thick vadv")

#ifdef MPAS_OPENACC
      !$acc parallel loop &
      !$acc     present(tend, vertAleTransportTop, minLevelCell, maxLevelCell) &
      !$acc     private(k)
#else
      !$omp parallel
      !$omp do schedule(runtime) private(k)
#endif
      do iCell = 1, nCellsOwned
         do k = minLevelCell(iCell), maxLevelCell(iCell)
            tend(k,iCell) = tend(k,iCell) + vertAleTransportTop(k+1,iCell) - vertAleTransportTop(k,iCell)
         end do
      end do
#ifndef MPAS_OPENACC
      !$omp end do
      !$omp end parallel
#endif

      call mpas_timer_stop("thick vadv")

   !--------------------------------------------------------------------

   end subroutine ocn_thick_vadv_tend!}}}

!***********************************************************************
!
!  routine ocn_thick_vadv_init
!
!> \brief   Initializes ocean thickness vertical advection
!> \author  Doug Jacobsen
!> \date    16 September 2011
!> \details
!>  This routine initializes quantities related to vertical advection of
!>  thickness in the ocean.
!
!-----------------------------------------------------------------------

   subroutine ocn_thick_vadv_init(err)!{{{

   !--------------------------------------------------------------------

      !-----------------------------------------------------------------
      !
      ! call individual init routines for each parameterization
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      thickVadvOn = .true.

      if(config_disable_thick_vadv) thickVadvOn = .false.

      err = 0

   !--------------------------------------------------------------------

   end subroutine ocn_thick_vadv_init!}}}

!***********************************************************************

end module ocn_thick_vadv

!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
! vim: foldmethod=marker

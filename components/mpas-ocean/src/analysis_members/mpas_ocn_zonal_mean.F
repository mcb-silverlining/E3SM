! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
!
!  ocn_zonal_mean
!
!> \brief MPAS ocean analysis core member: zonal_mean
!> \author Mark Petersen
!> \date   March 2014
!> \details
!>  MPAS ocean analysis core member: zonal_mean
!>  Compute zonal means of selected variables
!
!-----------------------------------------------------------------------

module ocn_zonal_mean

   use mpas_derived_types
   use mpas_pool_routines
   use mpas_dmpar
   use mpas_timekeeping
   use mpas_stream_manager

   use ocn_constants
   use ocn_config
   use ocn_diagnostics_variables

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

   public :: ocn_init_zonal_mean, &
             ocn_compute_zonal_mean, &
             ocn_restart_zonal_mean, &
             ocn_finalize_zonal_mean

   !--------------------------------------------------------------------
   !
   ! Private module variables
   !
   !--------------------------------------------------------------------

!***********************************************************************

contains

!***********************************************************************
!
!  routine ocn_init_zonal_mean
!
!> \brief   Initialize MPAS-Ocean analysis member
!> \author  Mark Petersen
!> \date    March 2014
!> \details
!>  This routine conducts all initializations required for the
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_init_zonal_mean(domain, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      type (domain_type), intent(inout) :: domain

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      type (dm_info) :: dminfo
      type (block_type), pointer :: block
      type (mpas_pool_type), pointer :: zonalMeanAMPool
      type (mpas_pool_type), pointer :: meshPool

      integer ::  iBin
      integer, pointer ::  nZonalMeanBins

      real (kind=RKIND) :: binWidth
      ! These are array size 1 because mpas_dmpar_min_real_array calls require arrays.
      real (kind=RKIND), dimension(1) :: minBin, maxBin, minBinDomain, maxBinDomain
      real (kind=RKIND), dimension(:), pointer ::  binCenterZonalMean, binBoundaryZonalMean, binVariable

      logical, pointer :: on_a_sphere

      dminfo = domain % dminfo

      err = 0

      minBin =  1.0e34_RKIND
      maxBin = -1.0e34_RKIND

      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nZonalMeanBins', nZonalMeanBins)
      call mpas_pool_get_subpool(domain % blocklist % structs, 'zonalMeanAM', zonalMeanAMPool)

      call mpas_pool_get_array(zonalMeanAMPool, 'binCenterZonalMean', binCenterZonalMean)
      call mpas_pool_get_array(zonalMeanAMPool, 'binBoundaryZonalMean', binBoundaryZonalMean)

      ! Find min and max values of binning variable.
      block => domain % blocklist
      do while (associated(block))
         call mpas_pool_get_subpool(block % structs, 'mesh', meshPool)
         call mpas_pool_get_config(meshPool, 'on_a_sphere', on_a_sphere)

         ! Bin by latitude on a sphere, by yCell otherwise.
         if (on_a_sphere) then
            call mpas_pool_get_array(meshPool, 'latCell', binVariable)
         else
            call mpas_pool_get_array(meshPool, 'yCell', binVariable)
         end if

         minBin = min(minBin, minval(binVariable) )
         maxBin = max(maxBin, maxval(binVariable) )

         block => block % next
      end do

      call mpas_dmpar_min_real_array(dminfo, 1, minBin, minBinDomain)
      call mpas_dmpar_max_real_array(dminfo, 1, maxBin, maxBinDomain)

      ! Set up bins.
      binBoundaryZonalMean = -1.0e34_RKIND
      binCenterZonalMean = -1.0e34_RKIND

      ! Change min and max bin bounds to configuration settings, if applicable.
      if (config_AM_zonalMean_min_bin > -1.0e33_RKIND) then
         minBinDomain(1) = config_AM_zonalMean_min_bin
      else
         ! use measured min value, but decrease slightly to include least value.
         minBinDomain(1) = minBinDomain(1) - 1.0e-10_RKIND * abs(minBinDomain(1))
      end if

      if (config_AM_zonalMean_max_bin > -1.0e33_RKIND) then
         maxBinDomain(1) = config_AM_zonalMean_max_bin
      else
         ! use measured max value, but increase slightly to include max value.
         maxBinDomain(1) = maxBinDomain(1) + 1.0e-10_RKIND * abs(maxBinDomain(1))
      end if

      binBoundaryZonalMean(1) = minBinDomain(1)
      binWidth = (maxBinDomain(1) - minBinDomain(1)) / nZonalMeanBins

      binCenterZonalMean(1) = minBinDomain(1) + binWidth/2.0_RKIND
      do iBin = 2, nZonalMeanBins
         binBoundaryZonalMean(iBin) = binBoundaryZonalMean(iBin-1) + binWidth
         binCenterZonalMean(iBin) = binCenterZonalMean(iBin-1) + binWidth
      end do
      binBoundaryZonalMean(nZonalMeanBins+1) = binBoundaryZonalMean(nZonalMeanBins) + binWidth

   end subroutine ocn_init_zonal_mean!}}}

!***********************************************************************
!
!  routine ocn_compute_zonal_mean
!
!> \brief   Compute MPAS-Ocean analysis member
!> \author  Mark Petersen
!> \date    March 2014
!> \details
!>  This routine conducts all computation required for this
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_compute_zonal_mean(domain, timeLevel, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      integer, intent(in) :: timeLevel

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      type (domain_type), intent(inout) :: domain

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      type (dm_info) :: dminfo
      type (block_type), pointer :: block
      type (mpas_pool_type), pointer :: zonalMeanAMPool
      type (mpas_pool_type), pointer :: statePool
      type (mpas_pool_type), pointer :: meshPool
      type (mpas_pool_type), pointer :: tracersPool

      integer :: iTracer, k, iCell, kMax
      integer :: iBin, iField, nZonalMeanVariables
      integer, pointer :: num_activeTracers, nCellsSolve, nVertLevels, nZonalMeanBins
      integer, dimension(:), pointer :: maxLevelCell

      real (kind=RKIND), dimension(:), pointer ::  areaCell, binVariable, binBoundaryZonalMean
      real (kind=RKIND), dimension(:,:), pointer :: velocityZonalZonalMean, velocityMeridionalZonalMean
      real (kind=RKIND), dimension(:,:,:), pointer :: activeTracers
      real (kind=RKIND), dimension(:,:,:), allocatable :: sumZonalMean, totalSumZonalMean, normZonalMean
      real (kind=RKIND), dimension(:,:,:), pointer :: tracersZonalMean

      logical, pointer :: on_a_sphere

      err = 0
      dminfo = domain % dminfo

      call mpas_pool_get_subpool(domain % blocklist % structs, 'zonalMeanAM', zonalMeanAMPool)
      call mpas_pool_get_subpool(domain % blocklist % structs, 'state', statePool)
      call mpas_pool_get_subpool(domain % blocklist % structs, 'mesh', meshPool)

      call mpas_pool_get_subpool(statePool, 'tracers', tracersPool)

      call mpas_pool_get_dimension(tracersPool, 'num_activeTracers', num_activeTracers)
      nZonalMeanVariables = num_activeTracers + 3

      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nZonalMeanBins', nZonalMeanBins)
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nVertLevels', nVertLevels)

      call mpas_pool_get_array(zonalMeanAMPool, 'binBoundaryZonalMean', binBoundaryZonalMean)

      allocate(sumZonalMean(nZonalMeanVariables,nVertLevels,nZonalMeanBins), &
         totalSumZonalMean(nZonalMeanVariables,nVertLevels,nZonalMeanBins), &
         normZonalMean(nZonalMeanVariables,nVertLevels,nZonalMeanBins))

      sumZonalMean = 0.0_RKIND

      block => domain % blocklist
      do while (associated(block))
         call mpas_pool_get_subpool(block % structs, 'state', statePool)
         call mpas_pool_get_subpool(block % structs, 'mesh', meshPool)
         call mpas_pool_get_subpool(statePool, 'tracers', tracersPool)


         !state => block % state % time_levs(timeLevel) % state
         !mesh => block % mesh
         !scratch => block % scratch
         !diagnostics => block % diagnostics

         call mpas_pool_get_dimension(tracersPool, 'num_activeTracers', num_activeTracers)

         call mpas_pool_get_dimension(block % dimensions, 'nCellsSolve', nCellsSolve)

         call mpas_pool_get_config(meshPool, 'on_a_sphere', on_a_sphere)

         call mpas_pool_get_array(meshPool, 'areaCell', areaCell)
         call mpas_pool_get_array(meshPool, 'maxLevelCell', maxLevelCell)
         call mpas_pool_get_array(tracersPool, 'activeTracers', activeTracers, timeLevel)

         ! Bin by latitude on a sphere, by yCell otherwise.
         if (on_a_sphere) then
            call mpas_pool_get_array(meshPool, 'latCell', binVariable)
         else
            call mpas_pool_get_array(meshPool, 'yCell', binVariable)
         end if

         ! note that sum is for each vertical index, which is a little wrong for z-star and very wrong for PBCs.
         do iCell = 1, nCellsSolve
            kMax = maxLevelCell(iCell)

            if (binVariable(iCell) .lt. binBoundaryZonalMean(1)) cycle

            do iBin = 1, nZonalMeanBins
               if (binVariable(iCell) .lt. binBoundaryZonalMean(iBin+1) ) then

                  do k = 1, kMax

                     ! Field 1 is the total area in this bin, which can vary by level due to land.
                     sumZonalMean(1,k,iBin) = sumZonalMean(1,k,iBin) + areaCell(iCell)

                     do iField = 1,num_activeTracers
                        sumZonalMean(iField+1,k,iBin) = sumZonalMean(iField+1,k,iBin) + activeTracers(iField,k,iCell) &
                                                      * areaCell(iCell)
                     enddo

                     iField = num_activeTracers+2
                     sumZonalMean(iField,k,iBin) = sumZonalMean(iField,k,iBin) + velocityZonal(k,iCell)*areaCell(iCell)
                     iField = iField+1
                     sumZonalMean(iField,k,iBin) = sumZonalMean(iField,k,iBin) + velocityMeridional(k,iCell)*areaCell(iCell)

                  end do
                  exit

               endif
            end do

         end do

         block => block % next
      end do

      ! mpi summation over all processors
      call mpas_dmpar_sum_real_array(dminfo, nVertLevels*nZonalMeanBins*nZonalMeanVariables, sumZonalMean, totalSumZonalMean)

      ! normalize by area
      do iBin = 1, nZonalMeanBins
         do k = 1, nVertLevels
            ! Check if there is any area accumulated.  If so, normalize by the area.
            if (totalSumZonalMean(1,k,iBin) > 1.0e-12_RKIND) then
               normZonalMean(:,k,iBin) = totalSumZonalMean(:,k,iBin) / totalSumZonalMean(1,k,iBin)
            else
               normZonalMean(:,k,iBin) = -1.0e34_RKIND
            end if
         end do
      end do
      do iBin = nZonalMeanBins + 1, nZonalMeanBins
         normZonalMean(:,:,iBin) = -1.0e34_RKIND
      end do

      ! Even though these variables do not include an index that is decomposed amongst
      ! domain partitions, we assign them within a block loop so that all blocks have the
      ! correct values for writing output.
      block => domain % blocklist
      do while (associated(block))
         call mpas_pool_get_dimension(block % dimensions, 'nZonalMeanBins', nZonalMeanBins)
         call mpas_pool_get_dimension(block % dimensions, 'nVertLevels', nVertLevels)

         call mpas_pool_get_subpool(block % structs, 'zonalMeanAM', zonalMeanAMPool)
         call mpas_pool_get_subpool(block % structs, 'state', statePool)
         call mpas_pool_get_subpool(statePool, 'tracers', tracersPool)

         call mpas_pool_get_dimension(tracersPool, 'num_activeTracers', num_activeTracers)

         call mpas_pool_get_array(zonalMeanAMPool, 'tracersZonalMean', tracersZonalMean)
         call mpas_pool_get_array(zonalMeanAMPool, 'velocityZonalZonalMean', velocityZonalZonalMean)
         call mpas_pool_get_array(zonalMeanAMPool, 'velocityMeridionalZonalMean', velocityMeridionalZonalMean)

         do iBin = 1, nZonalMeanBins
            do k = 1, nVertLevels

               do iField = 1, num_activeTracers
                  tracersZonalMean(iField,k,iBin) = normZonalMean(iField+1,k,iBin)
               enddo

               iField = num_activeTracers + 2
               velocityZonalZonalMean(k,iBin) = normZonalMean(iField,k,iBin)
               iField = iField+1
               velocityMeridionalZonalMean(k,iBin) = normZonalMean(iField,k,iBin)

            end do
         end do

         block => block % next
      end do

      deallocate(sumZonalMean,totalSumZonalMean,normZonalMean)

   end subroutine ocn_compute_zonal_mean!}}}

!***********************************************************************
!
!  routine ocn_restart_zonal_mean
!
!> \brief   Save restart for MPAS-Ocean analysis member
!> \author  Mark Petersen
!> \date    March 2014
!> \details
!>  This routine conducts computation required to save a restart state
!>  for the MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_restart_zonal_mean(domain, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      type (domain_type), intent(inout) :: domain

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      err = 0

   end subroutine ocn_restart_zonal_mean!}}}

!***********************************************************************
!
!  routine ocn_finalize_zonal_mean
!
!> \brief   Finalize MPAS-Ocean analysis member
!> \author  Mark Petersen
!> \date    March 2014
!> \details
!>  This routine conducts all finalizations required for this
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_finalize_zonal_mean(domain, err)!{{{

      !-----------------------------------------------------------------
      !
      ! input variables
      !
      !-----------------------------------------------------------------

      !-----------------------------------------------------------------
      !
      ! input/output variables
      !
      !-----------------------------------------------------------------

      type (domain_type), intent(inout) :: domain

      !-----------------------------------------------------------------
      !
      ! output variables
      !
      !-----------------------------------------------------------------

      integer, intent(out) :: err !< Output: error flag

      !-----------------------------------------------------------------
      !
      ! local variables
      !
      !-----------------------------------------------------------------

      err = 0

   end subroutine ocn_finalize_zonal_mean!}}}

end module ocn_zonal_mean

! vim: foldmethod=marker

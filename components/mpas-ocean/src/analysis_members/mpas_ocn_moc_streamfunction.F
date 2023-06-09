! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
!
!  ocn_moc_streamfunction
!
!> \brief MPAS ocean analysis mode member: moc_streamfunction
!> \author  Nils H. Feige, Mark R. Petersen
!> \date    2016-04-08
!> \brief   Computes Meridional Overturning Circulation streamfunction.
!>
!-----------------------------------------------------------------------

module ocn_moc_streamfunction

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

   public :: ocn_init_moc_streamfunction, &
             ocn_compute_moc_streamfunction, &
             ocn_restart_moc_streamfunction, &
             ocn_finalize_moc_streamfunction

   !--------------------------------------------------------------------
   !
   ! Private module variables
   !
   !--------------------------------------------------------------------

   integer :: nMocStreamfunctionBinsUsed

!***********************************************************************

contains

!***********************************************************************
!
!  routine ocn_init_moc_streamfunction
!
!> \brief   Initialize MPAS-Ocean analysis member
!> \author  Nils H. Feige, Mark R. Petersen
!> \date    2016-04-08
!> \details
!>  This routine conducts all initializations required for the
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_init_moc_streamfunction(domain, err)!{{{

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
      type (mpas_pool_type), pointer :: mocStreamfunctionAMPool
      type (mpas_pool_type), pointer :: meshPool

      integer ::  iBin

      real (kind=RKIND) :: binWidth
      ! These are array size 1 because mpas_dmpar_min_real_array calls require arrays.
      real (kind=RKIND), dimension(1) :: minBin, maxBin, minBinDomain, maxBinDomain
      ! the variable used to discriminate cells into Bins (either the y-value or the latitude)
      real (kind=RKIND), dimension(:), pointer :: binVariable, binBoundaryMocStreamfunction

      !determines if the simulation was run on a sphere or on a plane
      logical, pointer :: on_a_sphere

      !!!! REGION STUFF
      !! region moc calculation variables
      integer :: currentRegion, i, iCell

      !! region arrays/variables
      character (len=StrKIND), dimension(:), pointer :: regionGroupNames
      integer, dimension(:, :), pointer :: regionCellMasks, regionsInGroup
      integer, dimension(:), pointer ::  nRegionsInGroup
      integer, pointer :: nRegions, nRegionGroups, maxRegionsInGroup, nCellsSolve
      real (kind=RKIND), dimension(:,:), pointer :: minMaxLatRegion
      real (kind=RKIND), dimension(:)  , pointer :: minLatRegionLocal, maxLatRegionLocal, tminLatRegionLocal, tmaxLatRegionLocal

      !! region preliminary variables
      integer :: regionGroupNumber, regionsInAddGroup

      !!region pool
      type (mpas_pool_type), pointer :: regionPool

      !! region dimensions
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nRegions', nRegions)
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nRegionGroups', nRegionGroups)
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'maxRegionsInGroup', maxRegionsInGroup)

      !! get region values
      call mpas_pool_get_subpool(domain % blocklist % structs, 'regions', regionPool)
      call mpas_pool_get_array(regionPool, 'regionsInGroup', regionsInGroup)
      call mpas_pool_get_array(regionPool, 'nRegionsInGroup', nRegionsInGroup)
      call mpas_pool_get_array(regionPool, 'regionGroupNames', regionGroupNames)

      !!! region preliminaries
      regionGroupNumber=0
      do i = 1, nRegionGroups
         if (regionGroupNames(i) .eq. config_AM_mocStreamfunction_region_group) then
            regionGroupNumber = i
         end if
      end do
      if (regionGroupNumber.eq.0) then
         call mpas_log_write &
            ('ocn_moc_streamfunction AM: config_AM_mocStreamfunction_region_group not found in regionGroupNames')
         call mpas_log_write &
            ('ocn_moc_streamfunction AM: setting regionGroupNumber=1')
         regionGroupNumber = 1
      end if

      regionsInAddGroup = MIN(nRegionsInGroup(regionGroupNumber), maxRegionsInGroup)
      !!!! END REGION STUFF

      allocate(minLatRegionLocal(maxRegionsInGroup))
      allocate(maxLatRegionLocal(maxRegionsInGroup))
      allocate(tminLatRegionLocal(maxRegionsInGroup))
      allocate(tmaxLatRegionLocal(maxRegionsInGroup))

      dminfo = domain % dminfo

      err = 0

      minBin =  1.0e34_RKIND
      maxBin = -1.0e34_RKIND

      call mpas_pool_get_subpool(domain % blocklist % structs, 'mocStreamfunctionAM', mocStreamfunctionAMPool)

      call mpas_pool_get_array(mocStreamfunctionAMPool, 'minMaxLatRegion', minMaxLatRegion)

      minLatRegionLocal(:) =  4.0_RKIND
      maxLatRegionLocal(:) = -4.0_RKIND

      nMocStreamfunctionBinsUsed = config_AM_mocStreamfunction_num_bins

      call mpas_pool_get_array(mocStreamfunctionAMPool, 'binBoundaryMocStreamfunction', binBoundaryMocStreamfunction)

      ! Find min and max values of binning variable. For the whole domain as well as for each region
      ! in the current region group.
      block => domain % blocklist
      do while (associated(block))
         call mpas_pool_get_subpool(block % structs, 'mesh', meshPool)
         call mpas_pool_get_dimension(block % dimensions, 'nCellsSolve', nCellsSolve)

         call mpas_pool_get_array(regionPool, 'regionCellMasks', regionCellMasks)
         call mpas_pool_get_config(meshPool, 'on_a_sphere', on_a_sphere)

         ! Bin by latitude on a sphere, by yCell otherwise.
         if (on_a_sphere) then
            call mpas_pool_get_array(meshPool, 'latCell', binVariable)
         else
            call mpas_pool_get_array(meshPool, 'yCell', binVariable)
         end if

         minBin = min(minBin, minval(binVariable) )
         maxBin = max(maxBin, maxval(binVariable) )

         do i = 1, regionsInAddGroup
            currentRegion = regionsInGroup(i, regionGroupNumber)
            do iCell = 1, nCellsSolve
               if (regionCellMasks(currentRegion, iCell) .eq. 1) then
                  minLatRegionLocal(i) = min(minLatRegionLocal(i), binVariable(iCell))
                  maxLatRegionLocal(i) = max(maxLatRegionLocal(i), binVariable(iCell))
               end if
            end do
         end do

         block => block % next
      end do

      call mpas_dmpar_min_real_array(dminfo, 1, minBin, minBinDomain)
      call mpas_dmpar_max_real_array(dminfo, 1, maxBin, maxBinDomain)

      call mpas_dmpar_min_real_array(dminfo, maxRegionsInGroup, minLatRegionLocal(:), tminLatRegionLocal(:))
      call mpas_dmpar_max_real_array(dminfo, maxRegionsInGroup, maxLatRegionLocal(:), tmaxLatRegionLocal(:))
      minMaxLatRegion(1, :) = tminLatRegionLocal(:)
      minMaxLatRegion(2, :) = tmaxLatRegionLocal(:)

      deallocate(minLatRegionLocal)
      deallocate(maxLatRegionLocal)
      deallocate(tminLatRegionLocal)
      deallocate(tmaxLatRegionLocal)

      !print *, 'mins:', minMaxLatRegion(1,:)
      !print *, 'maxs:', minMaxLatRegion(2,:)

      ! Set up bins.
      binBoundaryMocStreamfunction = -1.0e34_RKIND

      ! Change min and max bin bounds to configuration settings, if applicable.
      if (config_AM_mocStreamfunction_min_bin > -1.0e33_RKIND) then
         minBinDomain(1) = config_AM_mocStreamfunction_min_bin
      else
         ! use measured min value, but decrease slightly to include least value.
         minBinDomain(1) = minBinDomain(1) - 1.0e-10_RKIND * abs(minBinDomain(1))
      end if

      if (config_AM_mocStreamfunction_max_bin > -1.0e33_RKIND) then
         maxBinDomain(1) = config_AM_mocStreamfunction_max_bin
      else
         ! use measured max value, but increase slightly to include max value.
         maxBinDomain(1) = maxBinDomain(1) + 1.0e-10_RKIND * abs(maxBinDomain(1))
      end if

      binBoundaryMocStreamfunction(1) = minBinDomain(1)
      binWidth = (maxBinDomain(1) - minBinDomain(1)) / nMocStreamfunctionBinsUsed

      ! Use the same bin boundaries for the regions and the global MOC.
      do iBin = 2, nMocStreamfunctionBinsUsed + 1
         binBoundaryMocStreamfunction(iBin) = binBoundaryMocStreamfunction(iBin-1) + binWidth
      end do

   end subroutine ocn_init_moc_streamfunction!}}}

!***********************************************************************
!
!  routine ocn_compute_moc_streamfunction
!
!> \brief   Compute MPAS-Ocean analysis member
!> \author  Nils H. Feige, Mark R. Petersen
!> \date    2016-04-08
!> \details
!>  This routine conducts all computation required for this
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_compute_moc_streamfunction(domain, timeLevel, err)!{{{
      implicit none
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

      type (mpas_pool_type), pointer :: mocStreamfunctionAMPool
      type (dm_info) :: dminfo
      type (block_type), pointer :: block
      type (mpas_pool_type), pointer :: meshPool
      type (mpas_pool_type), pointer :: statePool
      type (mpas_pool_type), pointer :: regionPool
      type (mpas_pool_type), pointer :: transectPool

      integer, pointer :: nVertLevels, nCellsSolve
      integer :: iCell, iBin, genericCounter, k
      real (kind=RKIND) :: binWidth
      real (kind=RKIND), dimension(:,:), pointer :: mocStreamValLatAndDepthLocal
      real (kind=RKIND), dimension(:), pointer :: latCell
      real (kind=RKIND), dimension(:), pointer ::  areaCell, binBoundaryMocStreamfunction
      real (kind=RKIND), dimension(:,:), pointer :: mocStreamvalLatAndDepth, mocStreamValLatAndDepthTotal
      real (kind=RKIND), dimension(:,:), pointer :: mocStreamvalLatAndDepthGM, mocStreamvalLatAndDepthMLE
      real (kind=RKIND), dimension(:,:), pointer :: sumVertBinVelocity

      !!!! TRANSECT VARIABLES !!!!
      integer, pointer :: nEdgesSolve, num_tracers
      integer :: iEdge, iTransect, c1, c2, currentTransect
      integer, dimension(:), pointer :: maxLevelCell, maxLevelEdgeTop
      integer, dimension(:,:), pointer :: transectEdgeMasks, transectEdgeMaskSigns, cellsOnEdge, &
            transectsInGroup

      real (kind=RKIND) :: m3ps_to_Sv
      real (kind=RKIND), dimension(:), pointer ::  dvEdge, refLayerThickness
      real (kind=RKIND), dimension(:,:), pointer :: layerThickness, normalVelocity
      real (kind=RKIND), dimension(:,:), allocatable ::  sumTransport, totalSumTransport
      character (len=STRKIND), dimension(:), pointer :: transectNames, transectGroupNames
      integer, dimension(:), pointer ::  nTransectsInGroup
      integer, pointer :: nTransects, nTransectGroups, maxTransectsInGroup
      integer :: transectGroupNumber, transectsInAddGroup
      !!!! END TRANSECT VARIABLES !!!!

      !!!! REGION VARIABLES
      real (kind=RKIND) :: maskFactor
      integer :: currentRegion, i
      real (kind=RKIND), dimension(:,:,:), pointer :: mocStreamValLatAndDepthRegionLocal, &
                         mocStreamvalLatAndDepthRegion, mocStreamValLatAndDepthRegionTotal, &
                         sumVertBinVelocityRegion, mocStreamvalLatAndDepthRegionGM, &
                         mocStreamvalLatAndDepthRegionMLE
      integer, dimension(:, :), pointer :: regionCellMasks, regionVertexMasks, regionsInGroup
      character (len=STRKIND), dimension(:), pointer :: regionNames, regionGroupNames
      integer, dimension(:), pointer ::  nRegionsInGroup
      integer, pointer :: nRegions, nRegionGroups, maxRegionsInGroup
      integer :: regionGroupNumber, regionsInAddGroup

      !!!! END REGION VARIABLES

      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nVertLevels', nVertLevels)

      !!!! REGION INITIALIZATION
      !! region dimensions
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nRegions', nRegions)
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nRegionGroups', nRegionGroups)
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'maxRegionsInGroup', maxRegionsInGroup)

      !! get region values
      call mpas_pool_get_subpool(domain % blocklist % structs, 'regions', regionPool)
      call mpas_pool_get_array(regionPool, 'regionsInGroup', regionsInGroup)
      call mpas_pool_get_array(regionPool, 'nRegionsInGroup', nRegionsInGroup)
      call mpas_pool_get_array(regionPool, 'regionNames', regionNames)
      call mpas_pool_get_array(regionPool, 'regionGroupNames', regionGroupNames)

      regionGroupNumber=0
      do i = 1, nRegionGroups
         if (regionGroupNames(i) .eq. config_AM_mocStreamfunction_region_group) then
            regionGroupNumber = i
         end if
      end do
      if (regionGroupNumber.eq.0) then
         call mpas_log_write &
            ('ocn_moc_streamfunction AM: config_AM_mocStreamfunction_region_group not found in regionGroupNames')
         call mpas_log_write &
            ('ocn_moc_streamfunction AM: setting regionGroupNumber=1')
         regionGroupNumber = 1
      end if

      regionsInAddGroup = MIN(nRegionsInGroup(regionGroupNumber), maxRegionsInGroup)

      !! allocate regional moc calculation arrays
      allocate(mocStreamValLatAndDepthRegionLocal(nMocStreamfunctionBinsUsed + 1, nVertLevels, maxRegionsInGroup))
      allocate(sumVertBinVelocityRegion(nMocStreamfunctionBinsUsed + 1, nVertLevels, maxRegionsInGroup))
      allocate(mocStreamValLatAndDepthRegionTotal(nMocStreamfunctionBinsUsed + 1, nVertLevels, maxRegionsInGroup))

      mocStreamValLatAndDepthRegionLocal = 0.0_RKIND
      mocStreamValLatAndDepthRegionTotal = 0.0_RKIND
      sumVertBinVelocityRegion = 0.0_RKIND
      !!!! END REGION INITIALIZATION

      !!!! TRANSECT INITIALIZATION
      !! transect dimensions
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nTransects', nTransects)
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'nTransectGroups', nTransectGroups)
      call mpas_pool_get_dimension(domain % blocklist % dimensions, 'maxTransectsInGroup', maxTransectsInGroup)

      !! get transect values
      call mpas_pool_get_subpool(domain % blocklist % structs, 'transects', transectPool)
      call mpas_pool_get_array(transectPool, 'transectsInGroup', transectsInGroup)
      call mpas_pool_get_array(transectPool, 'nTransectsInGroup', nTransectsInGroup)
      call mpas_pool_get_array(transectPool, 'transectNames', transectNames)
      call mpas_pool_get_array(transectPool, 'transectGroupNames', transectGroupNames)

      transectGroupNumber=0
      do i = 1, nTransectGroups
         if (transectGroupNames(i) .eq. config_AM_mocStreamfunction_transect_group) then
            transectGroupNumber = i
         end if
      end do
      if (transectGroupNumber.eq.0) then
         call mpas_log_write &
            ('ocn_moc_streamfunction AM: config_AM_mocStreamfunction_transect_group not found in transectGroupNames')
         call mpas_log_write &
            ('ocn_moc_streamfunction AM: setting transectGroupNumber=1')
         transectGroupNumber = 1
      end if

      transectsInAddGroup = nTransectsInGroup(transectGroupNumber)

      allocate(sumTransport(nVertLevels,maxTransectsInGroup))
      allocate(totalSumTransport(nVertLevels,maxTransectsInGroup))

      m3ps_to_Sv = 1e-6
      !!!! END TRANSECT INITIALIZATION

      if (transectsInAddGroup .ne. regionsInAddGroup) then
         ! This writes output every step, and is too verbose.
         !call mpas_log_write ('ocn_moc_streamfunction AM: transectsInGroup count does not ' &
         !   // 'match regionsInGroup count: $i, $i', intArgs = (/ transectsInAddGroup, regionsInAddGroup /) )
         i = min(transectsInAddGroup, regionsInAddGroup)
         transectsInAddGroup = i
         regionsInAddGroup = i
         !call mpas_log_write ('Setting both to min: $i, $i', intArgs = (/ transectsInAddGroup, regionsInAddGroup /) )
      end if

      err = 0

      dminfo = domain % dminfo

      allocate(mocStreamValLatAndDepthLocal(nMocStreamfunctionBinsUsed + 1, nVertLevels))
      allocate(sumVertBinVelocity(nMocStreamfunctionBinsUsed + 1, nVertLevels))
      allocate(mocStreamValLatAndDepthTotal(nMocStreamfunctionBinsUsed + 1, nVertLevels))

      block => domain % blocklist
      do while (associated(block))
         call mpas_pool_get_subpool(block % structs, 'mesh', meshPool)
         call mpas_pool_get_subpool(block % structs, 'mocStreamfunctionAM', mocStreamfunctionAMPool)

         call mpas_pool_get_array(mocStreamfunctionAMPool, 'binBoundaryMocStreamfunction', binBoundaryMocStreamfunction)

         binWidth = (binBoundaryMocStreamfunction(nMocStreamfunctionBinsUsed + 1) - binBoundaryMocStreamfunction(1)) &
         / nMocStreamfunctionBinsUsed

         call mpas_pool_get_dimension(block % dimensions, 'nCellsSolve', nCellsSolve)

         call mpas_pool_get_array(meshPool, 'latCell', latCell)
         call mpas_pool_get_array(meshPool, 'areaCell', areaCell)

         call mpas_pool_get_array(regionPool, 'regionCellMasks', regionCellMasks)

         !!!! TRANSECT DOMAINSPLIT VARIABLES
         call mpas_pool_get_array(meshPool, 'dvEdge', dvEdge)
         call mpas_pool_get_dimension(block % dimensions, 'nEdgesSolve', nEdgesSolve)
         call mpas_pool_get_array(transectPool,'transectEdgeMaskSigns',transectEdgeMaskSigns)
         call mpas_pool_get_array(transectPool,'transectEdgeMasks',transectEdgeMasks)
         call mpas_pool_get_subpool(block % structs, 'state', statePool)
         call mpas_pool_get_array(statePool, 'normalVelocity', normalVelocity, timeLevel)
         call mpas_pool_get_array(meshPool, 'cellsOnEdge', cellsOnEdge)
         call mpas_pool_get_array(meshPool, 'maxLevelEdgeTop', maxLevelEdgeTop)
         call mpas_pool_get_array(meshPool, 'maxLevelCell', maxLevelCell)
         call mpas_pool_get_array(statePool, 'layerThickness', layerThickness, timeLevel)


         !!!! TRANSECT CALCULATION
         sumTransport = 0.0_RKIND
         mocStreamValLatAndDepthLocal = 0.0_RKIND
         mocStreamValLatAndDepthTotal = 0.0_RKIND
         sumVertBinVelocity = 0.0_RKIND
         mocStreamValLatAndDepthRegionLocal = 0.0_RKIND
         mocStreamValLatAndDepthRegionTotal = 0.0_RKIND
         sumVertBinVelocityRegion = 0.0_RKIND

         do iTransect = 1,transectsInAddGroup
            currentTransect = transectsInGroup(iTransect, transectGroupNumber)
            do iEdge = 1,nEdgesSolve
               c1 = cellsOnEdge(1,iEdge)
               c2 = cellsOnEdge(2,iEdge)
               do k = 1, maxLevelEdgeTop(iEdge)
                  sumTransport(k,iTransect) = sumTransport(k,iTransect) + &
                     transectEdgeMaskSigns(currentTransect,iEdge) &
                     * transectEdgeMasks(currentTransect, iEdge) &
                     * normalVelocity(k,iEdge)*dvEdge(iEdge) &
                     * 0.5_RKIND*(layerThickness(k,c1) + layerThickness(k,c2))
               end do
            end do
            !Integrate transport from bottom to top, which switches the sign of sumTransport
            !there is also an implicit moc(nVertLevels+1,iTransect) = 0
            k = nVertLevels
            mocStreamValLatAndDepthRegionLocal(1, k, iTransect) = &
               - sumTransport(k, iTransect)
            do k = nVertLevels-1, 1, -1
               mocStreamValLatAndDepthRegionLocal(1, k, iTransect) = &
                  mocStreamValLatAndDepthRegionLocal(1, k + 1, iTransect) &
                  - sumTransport(k, iTransect)
            end do
         end do

         !!!! END TRANSECT CALCULATION

         do iCell = 1,nCellsSolve
            iBin = MAX(int((latCell(iCell) - binBoundaryMocStreamfunction(1)) / binWidth) + 2, 2)
            do k = 1,maxLevelCell(iCell)
               do i = 1, regionsInAddGroup
                  currentRegion = regionsInGroup(i, regionGroupNumber)
                  sumVertBinVelocityRegion(iBin, k, i) = sumVertBinVelocityRegion(iBin, k, i) + (vertVelocityTop(k, iCell) * &
                        areaCell(iCell) * regionCellMasks(currentRegion, iCell))
               end do
               sumVertBinVelocity(iBin, k) = sumVertBinVelocity(iBin, k) + (vertVelocityTop(k, iCell) * areaCell(iCell))
            end do
         end do

         do i = 1, regionsInAddGroup
            do k = 1,nVertLevels
               do iBin = 2, nMocStreamfunctionBinsUsed + 1
                  mocStreamValLatAndDepthLocal(iBin, k) = mocStreamValLatAndDepthLocal(iBin-1, k) &
                     + sumVertBinVelocity(iBin, k)
                  mocStreamValLatAndDepthRegionLocal(iBin, k, i) = mocStreamValLatAndDepthRegionLocal(iBin-1, k, i) &
                     + sumVertBinVelocityRegion(iBin, k, i)
               end do
            end do
         end do

         block => block % next
     end do

     call mpas_dmpar_sum_real_array(dminfo, nVertLevels * (nMocStreamfunctionBinsUsed + 1), mocStreamValLatAndDepthLocal, &
         mocStreamvalLatAndDepthTotal)

     call mpas_dmpar_sum_real_array(dminfo, nVertLevels * (nMocStreamfunctionBinsUsed + 1) * maxRegionsInGroup, &
         mocStreamValLatAndDepthRegionLocal, mocStreamvalLatAndDepthRegionTotal)

     call mpas_pool_get_subpool(domain % blocklist % structs, 'mocStreamfunctionAM', mocStreamfunctionAMPool)
     call mpas_pool_get_array(mocStreamfunctionAMPool, 'mocStreamvalLatAndDepth', mocStreamvalLatAndDepth)
     mocStreamvalLatAndDepth = mocStreamvalLatAndDepthTotal * m3ps_to_Sv

     call mpas_pool_get_array(mocStreamfunctionAMPool, 'mocStreamvalLatAndDepthRegion', mocStreamvalLatAndDepthRegion)
     mocStreamvalLatAndDepthRegion = mocStreamvalLatAndDepthRegionTotal * m3ps_to_Sv

     if(config_use_GM) THEN !compute GM bolus contribution to the streamfunction
       block => domain % blocklist
       do while (associated(block))
           call mpas_pool_get_subpool(block % structs, 'mesh', meshPool)
           call mpas_pool_get_subpool(block % structs, 'mocStreamfunctionAM', mocStreamfunctionAMPool)

           call mpas_pool_get_array(mocStreamfunctionAMPool, 'binBoundaryMocStreamfunction', binBoundaryMocStreamfunction)

           binWidth = (binBoundaryMocStreamfunction(nMocStreamfunctionBinsUsed + 1) - binBoundaryMocStreamfunction(1)) &
           / nMocStreamfunctionBinsUsed

           call mpas_pool_get_dimension(block % dimensions, 'nCellsSolve', nCellsSolve)

           call mpas_pool_get_array(meshPool, 'latCell', latCell)
           call mpas_pool_get_array(meshPool, 'areaCell', areaCell)

           call mpas_pool_get_array(regionPool, 'regionCellMasks', regionCellMasks)

           !!!! TRANSECT DOMAINSPLIT VARIABLES
           call mpas_pool_get_array(meshPool, 'dvEdge', dvEdge)
           call mpas_pool_get_dimension(block % dimensions, 'nEdgesSolve', nEdgesSolve)
           call mpas_pool_get_array(transectPool,'transectEdgeMaskSigns',transectEdgeMaskSigns)
           call mpas_pool_get_array(transectPool,'transectEdgeMasks',transectEdgeMasks)
           call mpas_pool_get_array(meshPool, 'cellsOnEdge', cellsOnEdge)
           call mpas_pool_get_array(meshPool, 'maxLevelEdgeTop', maxLevelEdgeTop)
           call mpas_pool_get_array(meshPool, 'maxLevelCell', maxLevelCell)
           call mpas_pool_get_array(statePool, 'layerThickness', layerThickness, timeLevel)

           !!!! TRANSECT CALCULATION
           sumTransport = 0.0_RKIND
           mocStreamValLatAndDepthLocal = 0.0_RKIND
           mocStreamValLatAndDepthTotal = 0.0_RKIND
           sumVertBinVelocity = 0.0_RKIND
           mocStreamValLatAndDepthRegionLocal = 0.0_RKIND
           mocStreamValLatAndDepthRegionTotal = 0.0_RKIND
           sumVertBinVelocityRegion = 0.0_RKIND

           do iTransect = 1,transectsInAddGroup
              currentTransect = transectsInGroup(iTransect, transectGroupNumber)
              do iEdge = 1,nEdgesSolve
                 c1 = cellsOnEdge(1,iEdge)
                 c2 = cellsOnEdge(2,iEdge)
                 do k = 1, maxLevelEdgeTop(iEdge)
                    sumTransport(k,iTransect) = sumTransport(k,iTransect) + &
                       transectEdgeMaskSigns(currentTransect,iEdge) &
                       * transectEdgeMasks(currentTransect, iEdge) &
                       * normalGMBolusVelocity(k,iEdge)*dvEdge(iEdge) &
                       * 0.5_RKIND*(layerThickness(k,c1) + layerThickness(k,c2))
                 end do
              end do
              !Integrate transport from bottom to top, which switches the sign of sumTransport
              !there is also an implicit moc(nVertLevels+1,iTransect) = 0
              k = nVertLevels
              mocStreamValLatAndDepthRegionLocal(1, k, iTransect) = &
                 - sumTransport(k, iTransect)
              do k = nVertLevels - 1, 1, -1
                 mocStreamValLatAndDepthRegionLocal(1, k, iTransect) = &
                    mocStreamValLatAndDepthRegionLocal(1, k + 1, iTransect) &
                    - sumTransport(k, iTransect)
              end do
           end do

           !!!! END TRANSECT CALCULATION

           do iCell = 1,nCellsSolve
              iBin = MAX(int((latCell(iCell) - binBoundaryMocStreamfunction(1)) / binWidth) + 2, 2)
              do k = 1,maxLevelCell(iCell)
                 do i = 1, regionsInAddGroup
                    currentRegion = regionsInGroup(i, regionGroupNumber)
                    sumVertBinVelocityRegion(iBin, k, i) = sumVertBinVelocityRegion(iBin, k, i) + &
                          (vertGMBolusVelocityTop(k, iCell) * &
                          areaCell(iCell) * regionCellMasks(currentRegion, iCell))
                 end do
                 sumVertBinVelocity(iBin, k) = sumVertBinVelocity(iBin, k) + &
                          (vertGMBolusVelocityTop(k, iCell) * areaCell(iCell))
              end do
           end do

           do i = 1, regionsInAddGroup
              do k = 1,nVertLevels
                 do iBin = 2, nMocStreamfunctionBinsUsed + 1
                    mocStreamValLatAndDepthLocal(iBin, k) = mocStreamValLatAndDepthLocal(iBin-1, k) &
                       + sumVertBinVelocity(iBin, k)
                    mocStreamValLatAndDepthRegionLocal(iBin, k, i) = mocStreamValLatAndDepthRegionLocal(iBin-1, k, i) &
                       + sumVertBinVelocityRegion(iBin, k, i)
                 end do
              end do
           end do

           block => block % next
       end do

       call mpas_dmpar_sum_real_array(dminfo, nVertLevels * (nMocStreamfunctionBinsUsed + 1), mocStreamValLatAndDepthLocal, &
           mocStreamvalLatAndDepthTotal)

       call mpas_dmpar_sum_real_array(dminfo, nVertLevels * (nMocStreamfunctionBinsUsed + 1) * maxRegionsInGroup, &
           mocStreamValLatAndDepthRegionLocal, mocStreamvalLatAndDepthRegionTotal)

       call mpas_pool_get_subpool(domain % blocklist % structs, 'mocStreamfunctionAM', mocStreamfunctionAMPool)
       call mpas_pool_get_array(mocStreamfunctionAMPool, 'mocStreamvalLatAndDepthGM', mocStreamvalLatAndDepthGM)
       mocStreamvalLatAndDepthGM = mocStreamvalLatAndDepthTotal * m3ps_to_Sv

       call mpas_pool_get_array(mocStreamfunctionAMPool, 'mocStreamvalLatAndDepthRegionGM', mocStreamvalLatAndDepthRegionGM)
       mocStreamvalLatAndDepthRegionGM = mocStreamvalLatAndDepthRegionTotal * m3ps_to_Sv

       !Add GM bolus contribution to resolved streamfunction to create total streamfunction
       mocStreamvalLatAndDepthRegion = mocStreamvalLatAndDepthRegion + mocStreamvalLatAndDepthRegionGM
       mocStreamvalLatAndDepth = mocStreamvalLatAndDepth + mocStreamvalLatAndDepthGM

     endif !config_use_GM

     if(config_submesoscale_enable) THEN !compute submesoscale eddy bolus contribution to the streamfunction
       block => domain % blocklist
       do while (associated(block))
           call mpas_pool_get_subpool(block % structs, 'mesh', meshPool)
           call mpas_pool_get_subpool(block % structs, 'mocStreamfunctionAM', mocStreamfunctionAMPool)

           call mpas_pool_get_array(mocStreamfunctionAMPool, 'binBoundaryMocStreamfunction', binBoundaryMocStreamfunction)

           binWidth = (binBoundaryMocStreamfunction(nMocStreamfunctionBinsUsed + 1) - binBoundaryMocStreamfunction(1)) &
           / nMocStreamfunctionBinsUsed

           call mpas_pool_get_dimension(block % dimensions, 'nCellsSolve', nCellsSolve)

           call mpas_pool_get_array(meshPool, 'latCell', latCell)
           call mpas_pool_get_array(meshPool, 'areaCell', areaCell)

           call mpas_pool_get_array(regionPool, 'regionCellMasks', regionCellMasks)

           !!!! TRANSECT DOMAINSPLIT VARIABLES
           call mpas_pool_get_array(meshPool, 'dvEdge', dvEdge)
           call mpas_pool_get_dimension(block % dimensions, 'nEdgesSolve', nEdgesSolve)
           call mpas_pool_get_array(transectPool,'transectEdgeMaskSigns',transectEdgeMaskSigns)
           call mpas_pool_get_array(transectPool,'transectEdgeMasks',transectEdgeMasks)
           call mpas_pool_get_array(meshPool, 'cellsOnEdge', cellsOnEdge)
           call mpas_pool_get_array(meshPool, 'maxLevelEdgeTop', maxLevelEdgeTop)
           call mpas_pool_get_array(meshPool, 'maxLevelCell', maxLevelCell)
           call mpas_pool_get_array(statePool, 'layerThickness', layerThickness, timeLevel)

           !!!! TRANSECT CALCULATION
           sumTransport = 0.0_RKIND
           mocStreamValLatAndDepthLocal = 0.0_RKIND
           mocStreamValLatAndDepthTotal = 0.0_RKIND
           sumVertBinVelocity = 0.0_RKIND
           mocStreamValLatAndDepthRegionLocal = 0.0_RKIND
           mocStreamValLatAndDepthRegionTotal = 0.0_RKIND
           sumVertBinVelocityRegion = 0.0_RKIND

           do iTransect = 1,transectsInAddGroup
              currentTransect = transectsInGroup(iTransect, transectGroupNumber)
              do iEdge = 1,nEdgesSolve
                 c1 = cellsOnEdge(1,iEdge)
                 c2 = cellsOnEdge(2,iEdge)
                 do k = 1, maxLevelEdgeTop(iEdge)
                    sumTransport(k,iTransect) = sumTransport(k,iTransect) + &
                       transectEdgeMaskSigns(currentTransect,iEdge) &
                       * transectEdgeMasks(currentTransect, iEdge) &
                       * normalMLEvelocity(k,iEdge)*dvEdge(iEdge) &
                       * 0.5_RKIND*(layerThickness(k,c1) + layerThickness(k,c2))
                 end do
              end do
              !Integrate transport from bottom to top, which switches the sign of sumTransport
              !there is also an implicit moc(nVertLevels+1,iTransect) = 0
              k = nVertLevels
              mocStreamValLatAndDepthRegionLocal(1, k, iTransect) = &
                 - sumTransport(k, iTransect)
              do k = nVertLevels - 1, 1, -1
                 mocStreamValLatAndDepthRegionLocal(1, k, iTransect) = &
                    mocStreamValLatAndDepthRegionLocal(1, k + 1, iTransect) &
                    - sumTransport(k, iTransect)
              end do
           end do

           !!!! END TRANSECT CALCULATION

           do iCell = 1,nCellsSolve
              iBin = MAX(int((latCell(iCell) - binBoundaryMocStreamfunction(1)) / binWidth) + 2, 2)
              do k = 1,maxLevelCell(iCell)
                 do i = 1, regionsInAddGroup
                    currentRegion = regionsInGroup(i, regionGroupNumber)
                    sumVertBinVelocityRegion(iBin, k, i) = sumVertBinVelocityRegion(iBin, k, i) + &
                          (vertMLEBolusVelocityTop(k,iCell) * &
                          areaCell(iCell) * regionCellMasks(currentRegion, iCell))
                 end do
                 sumVertBinVelocity(iBin, k) = sumVertBinVelocity(iBin, k) + &
                          (vertMLEBolusVelocityTop(k,iCell) * areaCell(iCell))
              end do
           end do

           do i = 1, regionsInAddGroup
              do k = 1,nVertLevels
                 do iBin = 2, nMocStreamfunctionBinsUsed + 1
                    mocStreamValLatAndDepthLocal(iBin, k) = mocStreamValLatAndDepthLocal(iBin-1, k) &
                       + sumVertBinVelocity(iBin, k)
                    mocStreamValLatAndDepthRegionLocal(iBin, k, i) = mocStreamValLatAndDepthRegionLocal(iBin-1, k, i) &
                       + sumVertBinVelocityRegion(iBin, k, i)
                 end do
              end do
           end do

           block => block % next
       end do

       call mpas_dmpar_sum_real_array(dminfo, nVertLevels * (nMocStreamfunctionBinsUsed + 1), mocStreamValLatAndDepthLocal, &
           mocStreamvalLatAndDepthTotal)

       call mpas_dmpar_sum_real_array(dminfo, nVertLevels * (nMocStreamfunctionBinsUsed + 1) * maxRegionsInGroup, &
           mocStreamValLatAndDepthRegionLocal, mocStreamvalLatAndDepthRegionTotal)

       call mpas_pool_get_subpool(domain % blocklist % structs, 'mocStreamfunctionAM', mocStreamfunctionAMPool)
       call mpas_pool_get_array(mocStreamfunctionAMPool, 'mocStreamvalLatAndDepthMLE', mocStreamvalLatAndDepthMLE)
       mocStreamvalLatAndDepthMLE = mocStreamvalLatAndDepthTotal * m3ps_to_Sv

       call mpas_pool_get_array(mocStreamfunctionAMPool, 'mocStreamvalLatAndDepthRegionMLE', mocStreamvalLatAndDepthRegionMLE)
       mocStreamvalLatAndDepthRegionMLE = mocStreamvalLatAndDepthRegionTotal * m3ps_to_Sv

       !Add submesoscale eddy bolus contribution to resolved streamfunction to create total streamfunction
       mocStreamvalLatAndDepthRegion = mocStreamvalLatAndDepthRegion + mocStreamvalLatAndDepthRegionMLE
       mocStreamvalLatAndDepth = mocStreamvalLatAndDepth + mocStreamvalLatAndDepthMLE

     endif !config_submesoscale_enable

     deallocate(mocStreamvalLatAndDepthTotal)
     deallocate(mocStreamvalLatAndDepthLocal)
     deallocate(sumVertBinVelocity)

     deallocate(mocStreamvalLatAndDepthRegionTotal)
     deallocate(mocStreamvalLatAndDepthRegionLocal)
     deallocate(sumVertBinVelocityRegion)

     !!!! TRANSECT CELANUP
     deallocate(sumTransport)
     deallocate(totalSumTransport)

   end subroutine ocn_compute_moc_streamfunction!}}}

!***********************************************************************
!
!  routine ocn_restart_moc_streamfunction
!
!> \brief   Save restart for MPAS-Ocean analysis member
!> \author  Nils H. Feige, Mark R. Petersen
!> \date    2016-04-08
!> \details
!>  This routine conducts computation required to save a restart state
!>  for the MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_restart_moc_streamfunction(domain, err)!{{{

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

   end subroutine ocn_restart_moc_streamfunction!}}}

!***********************************************************************
!
!  routine ocn_finalize_moc_streamfunction
!
!> \brief   Finalize MPAS-Ocean analysis member
!> \author  Nils H. Feige, Mark R. Petersen
!> \date    2016-04-08
!> \details
!>  This routine conducts all finalizations required for this
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_finalize_moc_streamfunction(domain, err)!{{{

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

   end subroutine ocn_finalize_moc_streamfunction!}}}

end module ocn_moc_streamfunction

! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
module sw_global_diagnostics

   use mpas_derived_types
   use mpas_pool_routines
   use mpas_constants
   use mpas_dmpar

   use sw_constants

   implicit none
   save
   public

   contains

   subroutine sw_compute_global_diagnostics(dminfo, statePool, meshPool, timeIndex, dt, timeLevelIn)

      ! Note: this routine assumes that there is only one block per processor. No looping
      ! is preformed over blocks.
      ! dminfo is the domain info needed for global communication
      ! state contains the state variables needed to compute global diagnostics
      ! grid conains the meta data about the grid
      ! timeIndex is the current time step counter
      ! dt is the duration of each time step

      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      !                            INSTRUCTIONS                               !
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      ! To add a new Diagnostic as a Global Stat, follow these steps.
      ! 1. Define the array to integrate, and the variable for the value above.
      ! 2. Allocate the array with the correct dimensions.
      ! 3. Fill the array with the data to be integrated.
      !     eg. GlobalFluidThickness = Sum(h dA)/Sum(dA), See below for array filling
      ! 4. Call Function to compute Global Stat that you want.
      ! 5. Finish computing the global stat/integral
      ! 6. Write out your global stat to the file
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      implicit none

      type (dm_info), intent(in) :: dminfo
      type (mpas_pool_type), intent(inout) :: statePool
      type (mpas_pool_type), intent(in) :: meshPool
      integer, intent(in) :: timeIndex
      real (kind=RKIND), intent(in) :: dt
      integer, intent(in), optional :: timeLevelIn

      integer :: nCellsGlobal, nEdgesGlobal, nVerticesGlobal, iTracer
      integer, pointer :: nCells, nVertLevels, nCellsSolve, nEdgesSolve, nVerticesSolve

      ! Step 1
      ! 1. Define the array to integrate, and the variable for the value to be stored in after the integration
      real (kind=RKIND), dimension(:), pointer ::  areaCell, dcEdge, dvEdge, areaTriangle, h_s, fCell, fEdge
      real (kind=RKIND), dimension(:,:), pointer :: h, u, v, h_edge, pv_edge, pv_vertex, pv_cell, h_vertex, weightsOnEdge

      real (kind=RKIND), dimension(:,:,:), pointer :: tracers

      real (kind=RKIND), dimension(:), allocatable :: volumeWeightedPotentialEnergyReservoir, averageThickness
      real (kind=RKIND), dimension(:), allocatable :: potentialEnstrophyReservior, areaEdge, h_s_edge

      real (kind=RKIND), dimension(:,:), allocatable :: cellVolume, cellArea, volumeWeightedPotentialVorticity
      real (kind=RKIND), dimension(:,:), allocatable :: volumeWeightedPotentialEnstrophy, vertexVolume, volumeWeightedKineticEnergy 
      real (kind=RKIND), dimension(:,:), allocatable :: volumeWeightedPotentialEnergy, volumeWeightedPotentialEnergyTopography 
      real (kind=RKIND), dimension(:,:), allocatable :: keTend_CoriolisForce, keTend_PressureGradient 
      real (kind=RKIND), dimension(:,:), allocatable ::peTend_DivThickness, refAreaWeightedSurfaceHeight, refAreaWeightedSurfaceHeight_edge

      real (kind=RKIND) :: sumCellVolume, sumCellArea, sumVertexVolume, sumrefAreaWeightedSurfaceHeight

      real (kind=RKIND) :: globalFluidThickness, globalPotentialVorticity, globalPotentialEnstrophy, globalEnergy 
      real (kind=RKIND) :: globalCoriolisEnergyTendency, globalKEPETendency, globalPotentialEnstrophyReservoir 
      real (kind=RKIND) :: globalKineticEnergy, globalPotentialEnergy, globalPotentialEnergyReservoir
      real (kind=RKIND) :: globalKineticEnergyTendency, globalPotentialEnergyTendency
      real (kind=RKIND) ::  global_temp, workpv, q
      real (kind=RKIND) :: volumeCellGlobal, volumeEdgeGlobal, CFLNumberGlobal

      integer :: elementIndex, variableIndex, nVariables, nSums, nMaxes, nMins
      integer :: timeLevel, eoe, iLevel, iCell, iEdge, iVertex
      integer :: fileID, iCell1, iCell2, j
      integer, pointer :: config_stats_interval

      integer, dimension(:,:), pointer :: cellsOnEdge, edgesOnCell, edgesOnEdge
      integer, dimension(:), pointer :: nEdgesOnEdge

      if (present(timeLevelIn)) then
         timeLevel = timeLevelIn
      else
         timeLevel = 1
      endif

      call mpas_pool_get_config(swConfigs, 'config_stats_interval', config_stats_interval)
      
      call mpas_pool_get_dimension(meshPool, 'nVertLevels', nVertLevels)
      call mpas_pool_get_dimension(meshPool, 'nCellsSolve', nCellsSolve)
      call mpas_pool_get_dimension(meshPool, 'nEdgesSolve', nEdgesSolve)
      call mpas_pool_get_dimension(meshPool, 'nVerticesSolve', nVerticesSolve)
      call mpas_pool_get_dimension(meshPool, 'nCells', nCells)

      call mpas_pool_get_array(meshPool, 'cellsOnEdge', cellsOnEdge)
      call mpas_pool_get_array(meshPool, 'edgesOnCell', edgesOnCell)
      call mpas_pool_get_array(meshPool, 'h_s', h_s)
      call mpas_pool_get_array(meshPool, 'areaCell', areaCell)
      call mpas_pool_get_array(meshPool, 'dcEdge', dcEdge)
      call mpas_pool_get_array(meshPool, 'dvEdge', dvEdge)
      call mpas_pool_get_array(meshPool, 'areaTriangle', areaTriangle)
      call mpas_pool_get_array(meshPool, 'fCell', fCell)
      call mpas_pool_get_array(meshPool, 'fEdge', fEdge)
      call mpas_pool_get_array(meshPool, 'edgesOnEdge', edgesOnEdge)
      call mpas_pool_get_array(meshPool, 'nEdgesOnEdge', nEdgesOnEdge)
      call mpas_pool_get_array(meshPool, 'weightsOnEdge', weightsOnEdge)

      allocate(areaEdge(1:nEdgesSolve))
      areaEdge = dcEdge(1:nEdgesSolve)*dvEdge(1:nEdgesSolve)

      call mpas_pool_get_array(statePool, 'h', h, timeLevel)
      call mpas_pool_get_array(statePool, 'u', u, timeLevel)
      call mpas_pool_get_array(statePool, 'v', v, timeLevel)
      call mpas_pool_get_array(statePool, 'tracers', tracers, timeLevel)
      call mpas_pool_get_array(statePool, 'h_edge', h_edge, timeLevel)
      call mpas_pool_get_array(statePool, 'h_vertex', h_vertex, timeLevel)
      call mpas_pool_get_array(statePool, 'pv_edge', pv_edge, timeLevel)
      call mpas_pool_get_array(statePool, 'pv_vertex', pv_vertex, timeLevel)
      call mpas_pool_get_array(statePool, 'pv_cell', pv_cell, timeLevel)

      ! Step 2
      ! 2. Allocate the array with the correct dimensions.
      allocate(cellVolume(nVertLevels,nCellsSolve))
      allocate(cellArea(nVertLevels,nCellsSolve))
      allocate(refAreaWeightedSurfaceHeight(nVertLevels,nCellsSolve))
      allocate(refAreaWeightedSurfaceHeight_edge(nVertLevels,nEdgesSolve))
      allocate(volumeWeightedPotentialVorticity(nVertLevels,nVerticesSolve))
      allocate(volumeWeightedPotentialEnstrophy(nVertLevels,nVerticesSolve))
      allocate(potentialEnstrophyReservior(nCellsSolve))
      allocate(vertexVolume(nVertLevels,nVerticesSolve))
      allocate(volumeWeightedKineticEnergy(nVertLevels,nEdgesSolve))
      allocate(volumeWeightedPotentialEnergy(nVertLevels,nCellsSolve))
      allocate(volumeWeightedPotentialEnergyTopography(nVertLevels,nCellsSolve))
      allocate(volumeWeightedPotentialEnergyReservoir(nCellsSolve))
      allocate(keTend_CoriolisForce(nVertLevels,nEdgesSolve))
      allocate(keTend_PressureGradient(nVertLevels,nEdgesSolve))
      allocate(peTend_DivThickness(nVertLevels,nCells))

      allocate(averageThickness(nCellsSolve))

      allocate(h_s_edge(nEdgesSOlve))


      cellVolume = 0
      refAreaWeightedSurfaceHeight = 0
      refAreaWeightedSurfaceHeight_edge = 0
      vertexVolume = 0
      cellArea = 0
      averageThickness = 0
      volumeWeightedPotentialVorticity = 0
      volumeWeightedPotentialEnstrophy = 0
      volumeWeightedKineticEnergy = 0
      volumeWeightedPotentialEnergy = 0
      volumeWeightedPotentialEnergyTopography = 0
      volumeWeightedPotentialEnergyReservoir = 0
      keTend_PressureGradient = 0
      peTend_DivThickness = 0
      keTend_CoriolisForce = 0
      h_s_edge = 0

      ! Build Arrays for Global Integrals
      ! Step 3
      ! 3. Fill the array with the data to be integrated.
      !     eg. GlobalFluidThickness = Sum(h dA)/Sum(dA), See below for array filling
      do iLevel = 1,nVertLevels
        ! eg. GlobalFluidThickness top (Sum( h dA)) = Sum(cellVolume)
        cellVolume(iLevel,:) = h(iLevel,1:nCellsSolve)*areaCell(1:nCellsSolve)
        ! eg. GlobalFluidThickness bot (Sum(dA)) = Sum(cellArea)
        cellArea(iLevel,:) = areaCell(1:nCellsSolve)
        volumeWeightedPotentialVorticity(iLevel,:) = pv_vertex(iLevel,1:nVerticesSolve) &
                *h_vertex(iLevel,1:nVerticesSolve)*areaTriangle(1:nVerticesSolve) 
        volumeWeightedPotentialEnstrophy(iLevel,:) = pv_vertex(iLevel,1:nVerticesSolve) & 
                *pv_vertex(iLevel,1:nVerticesSolve)*h_vertex(iLevel,1:nVerticesSolve)*areaTriangle(1:nVerticesSolve)
        vertexVolume(iLevel,:) = h_vertex(iLevel,1:nVerticesSolve)*areaTriangle(1:nVerticesSolve)
        volumeWeightedKineticEnergy(iLevel,:) = u(iLevel,1:nEdgesSolve)*u(iLevel,1:nEdgesSolve) &
                *h_edge(iLevel,1:nEdgesSolve)*areaEdge(1:nEdgesSolve)*0.5
        volumeWeightedPotentialEnergy(iLevel,:) = gravity*h(iLevel,1:nCellsSolve)*h(iLevel,1:nCellsSolve)*areaCell(1:nCellsSolve)*0.5
        volumeWeightedPotentialEnergyTopography(iLevel,:) = gravity*h(iLevel,1:nCellsSolve)*h_s(1:nCellsSolve)*areaCell(1:nCellsSolve)
        refAreaWeightedSurfaceHeight(iLevel,:) = areaCell(1:nCellsSolve)*(h(iLevel,1:nCellsSolve)+h_s(1:nCellsSolve))

        do iEdge = 1,nEdgesSolve
            q = 0.0
            do j = 1,nEdgesOnEdge(iEdge)
               eoe = edgesOnEdge(j,iEdge)
               workpv = 0.5 * (pv_edge(iLevel,iEdge) + pv_edge(iLevel,eoe))
               q = q + weightsOnEdge(j,iEdge) * u(iLevel,eoe) * workpv * h_edge(iLevel,eoe) 
            end do
            keTend_CoriolisForce(iLevel,iEdge) = h_edge(iLevel,iEdge) * u(iLevel,iEdge) * q * areaEdge(iEdge)

            iCell1 = cellsOnEdge(1,iEdge)
            iCell2 = cellsOnEdge(2,iEdge)

            refAreaWeightedSurfaceHeight_edge(iLevel,iEdge) = areaEdge(iEdge)*(h_edge(iLevel,iEdge) + 0.5*(h_s(iCell1) + h_s(iCell2)))

            keTend_PressureGradient(iLevel,iEdge) = areaEdge(iEdge)*h_edge(iLevel,iEdge)*u(iLevel,iEdge) &
                        *gravity*(h(iLevel,iCell2)+h_s(iCell2) - h(iLevel,iCell1)-h_s(iCell1))/dcEdge(iEdge)
            peTend_DivThickness(iLevel,iCell1) = peTend_DivThickness(iLevel,iCell1) &
                        + h_edge(iLevel,iEdge)*u(iLevel,iEdge)*dvEdge(iEdge)
            peTend_DivThickness(iLevel,iCell2) = peTend_DivThickness(iLevel,iCell2) &
                        - h_edge(iLevel,iEdge)*u(iLevel,iEdge)*dvEdge(iEdge)
        end do

        peTend_DivThickness(iLevel,:) = peTend_DivThickness(iLevel,1:nCells)*gravity &
                   *(h(iLevel,1:nCells)+h_s(1:nCells))
      end do

      do iEdge = 1,nEdgesSolve
          iCell1 = cellsOnEdge(1,iEdge)
          iCell2 = cellsOnEdge(2,iEdge)
          
          h_s_edge(iEdge) = 0.5*(h_s(iCell1) + h_s(iCell2))
      end do

      ! Step 4
      ! 4. Call Function to compute Global Stat that you want.
      ! Computing Kinetic and Potential Energy Tendency Terms
      call sw_compute_global_sum(dminfo, nVertLevels, nEdgesSolve, keTend_PressureGradient, globalKineticEnergyTendency)
      call sw_compute_global_sum(dminfo, nVertLevels, nCells, peTend_DivThickness, globalPotentialEnergyTendency)

      ! Computing top and bottom of global mass integral
      call sw_compute_global_sum(dminfo, nVertLevels, nCellsSolve, cellVolume, sumCellVolume)
      call sw_compute_global_sum(dminfo, nVertLevels, nCellsSolve, cellArea, sumCellArea)

      globalKineticEnergyTendency = globalKineticEnergyTendency / sumCellVolume
      globalPotentialEnergyTendency = globalPotentialEnergyTendency / sumCellVolume

      ! Step 5
      ! 5. Finish computing the global stat/integral
      globalFluidThickness = sumCellVolume/sumCellArea

      ! Compute Average Sea Surface Height for Potential Energy and Enstrophy
      ! Reservoir computations
      call sw_compute_global_sum(dminfo, nVertLevels, nCellsSolve, refAreaWeightedSurfaceHeight, sumrefAreaWeightedSurfaceHeight)

      averageThickness(:) = (sumrefAreaWeightedSurfaceHeight/sumCellArea)-h_s(1:nCellsSolve)

      ! Compute Volume Weighted Averages of Potential Vorticity and Potential Enstrophy
      call sw_compute_global_sum(dminfo, nVertLevels, nVerticesSolve, volumeWeightedPotentialVorticity, globalPotentialVorticity)
      call sw_compute_global_sum(dminfo, nVertLevels, nVerticesSolve, volumeWeightedPotentialEnstrophy, globalPotentialEnstrophy)
      call sw_compute_global_sum(dminfo, nVertLevels, nVerticesSolve, vertexVolume, sumVertexVolume)

      globalPotentialVorticity = globalPotentialVorticity/sumVertexVolume
      globalPotentialEnstrophy = globalPotentialEnstrophy/sumVertexVolume

      ! Compte Potential Enstrophy Reservior
      potentialEnstrophyReservior(:) = areaCell(1:nCellsSolve)*fCell(1:nCellsSolve)*fCell(1:nCellsSolve)/averageThickness
      call sw_compute_global_sum(dminfo, 1, nCellsSolve, potentialEnstrophyReservior, globalPotentialEnstrophyReservoir)
      globalPotentialEnstrophyReservoir = globalPotentialEnstrophyReservoir/sumCellVolume

      globalPotentialEnstrophy = globalPotentialEnstrophy - globalPotentialEnstrophyReservoir

      ! Compute Kinetic and Potential Energy terms to be combined into total energy
      call sw_compute_global_sum(dminfo, nVertLevels, nEdgesSolve, volumeWeightedKineticEnergy, globalKineticEnergy)
      call sw_compute_global_sum(dminfo, nVertLevels, nCellsSolve, volumeWeightedPotentialEnergy, globalPotentialEnergy)
      call sw_compute_global_sum(dminfo, nVertLevels, nCellsSolve, volumeWeightedPotentialEnergyTopography, global_temp)

      globalKineticEnergy = globalKineticEnergy/sumCellVolume
      globalPotentialEnergy = (globalPotentialEnergy + global_temp)/sumCellVolume

      ! Compute Potential energy reservoir to be subtracted from potential energy term
      volumeWeightedPotentialEnergyReservoir(1:nCellsSolve) = areaCell(1:nCellsSolve)*averageThickness*averageThickness*gravity*0.5
      call sw_compute_global_sum(dminfo, nVertLevels, nCellsSolve, volumeWeightedPotentialEnergyReservoir, globalPotentialEnergyReservoir)
      volumeWeightedPotentialEnergyReservoir(1:nCellsSolve) = areaCell(1:nCellsSolve)*averageThickness*h_s(1:nCellsSolve)*gravity
      call sw_compute_global_sum(dminfo, nVertLevels, nCellsSolve, volumeWeightedPotentialEnergyReservoir, global_temp)

      globalPotentialEnergyReservoir = (globalPotentialEnergyReservoir + global_temp)/sumCellVolume

      globalPotentialEnergy = globalPotentialEnergy - globalPotentialEnergyReservoir
      globalEnergy = globalKineticEnergy + globalPotentialEnergy

      ! Compute Coriolis energy tendency term
      call sw_compute_global_sum(dminfo, nVertLevels, nEdgesSolve, keTend_CoriolisForce, globalCoriolisEnergyTendency)
      globalCoriolisEnergyTendency = globalCoriolisEnergyTendency/sumCellVolume

      ! Step 6
      ! 6. Write out your global stat to the file
      if (dminfo % my_proc_id == IO_NODE) then
         fileID = sw_get_free_unit()

         if (timeIndex/config_stats_interval == 1) then
             open(fileID, file='GlobalIntegrals.txt',STATUS='unknown')
         else
             open(fileID, file='GlobalIntegrals.txt',POSITION='append')
         endif 
         write(fileID,'(1i0, 100es24.16)') timeIndex, timeIndex*dt, globalFluidThickness, globalPotentialVorticity, globalPotentialEnstrophy, &
                        globalEnergy, globalCoriolisEnergyTendency, globalKineticEnergyTendency+globalPotentialEnergyTendency, &
                        globalKineticEnergy, globalPotentialEnergy
         close(fileID)
      end if

      deallocate(areaEdge)
   end subroutine sw_compute_global_diagnostics

   integer function sw_get_free_unit()
      implicit none

      integer :: index
      logical :: isOpened

      sw_get_free_unit = 0
      do index = 1,99
         if((index /= 5) .and. (index /= 6)) then
            inquire(unit = index, opened = isOpened)
            if( .not. isOpened) then
               sw_get_free_unit = index
               return
            end if
         end if
      end do
   end function sw_get_free_unit

   subroutine sw_compute_global_sum(dminfo, nVertLevels, nElements, field, globalSum)

      implicit none

      type (dm_info), intent(in) :: dminfo
      integer, intent(in) :: nVertLevels, nElements
      real (kind=RKIND), dimension(nVertLevels, nElements), intent(in) :: field
      real (kind=RKIND), intent(out) :: globalSum

      real (kind=RKIND) :: localSum

      localSum = sum(field)
      call mpas_dmpar_sum_real(dminfo, localSum, globalSum)

   end subroutine sw_compute_global_sum

   subroutine sw_compute_global_min(dminfo, nVertLevels, nElements, field, globalMin)

      implicit none

      type (dm_info), intent(in) :: dminfo
      integer, intent(in) :: nVertLevels, nElements
      real (kind=RKIND), dimension(nVertLevels, nElements), intent(in) :: field
      real (kind=RKIND), intent(out) :: globalMin

      real (kind=RKIND) :: localMin

      localMin = minval(field)
      call mpas_dmpar_min_real(dminfo, localMin, globalMin)

   end subroutine sw_compute_global_min

   subroutine sw_compute_global_max(dminfo, nVertLevels, nElements, field, globalMax)

      implicit none

      type (dm_info), intent(in) :: dminfo
      integer, intent(in) :: nVertLevels, nElements
      real (kind=RKIND), dimension(nVertLevels, nElements), intent(in) :: field
      real (kind=RKIND), intent(out) :: globalMax

      real (kind=RKIND) :: localMax

      localMax = maxval(field)
      call mpas_dmpar_max_real(dminfo, localMax, globalMax)

   end subroutine sw_compute_global_max

   subroutine compute_global_vert_sum_horiz_min(dminfo, nVertLevels, nElements, field, globalMin)

      implicit none

      type (dm_info), intent(in) :: dminfo
      integer, intent(in) :: nVertLevels, nElements
      real (kind=RKIND), dimension(nVertLevels, nElements), intent(in) :: field
      real (kind=RKIND), intent(out) :: globalMin

      real (kind=RKIND) :: localMin

      localMin = minval(sum(field,1))
      call mpas_dmpar_min_real(dminfo, localMin, globalMin)

   end subroutine compute_global_vert_sum_horiz_min

   subroutine sw_compute_global_vert_sum_horiz_max(dminfo, nVertLevels, nElements, field, globalMax)

      implicit none

      type (dm_info), intent(in) :: dminfo
      integer, intent(in) :: nVertLevels, nElements
      real (kind=RKIND), dimension(nVertLevels, nElements), intent(in) :: field
      real (kind=RKIND), intent(out) :: globalMax

      real (kind=RKIND) :: localMax

      localMax = maxval(sum(field,1))
      call mpas_dmpar_max_real(dminfo, localMax, globalMax)

   end subroutine sw_compute_global_vert_sum_horiz_max

end module sw_global_diagnostics

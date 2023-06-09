! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
!
!  ocn_sediment_transport
!
!> \brief MPAS ocean analysis mode member: sediment_transport
!> \author Zhendong Cao and Phillip J. Wolfram
!> \date   2019/03/07
!> \details
!>  MPAS ocean analysis mode member: sediment_transport
!-----------------------------------------------------------------------

module ocn_sediment_transport

   use mpas_derived_types
   use mpas_pool_routines
   use mpas_dmpar
   use mpas_timekeeping
   use mpas_stream_manager

   use ocn_constants
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

   public :: ocn_init_sediment_transport, &
             ocn_compute_sediment_transport, &
             ocn_restart_sediment_transport, &
             ocn_finalize_sediment_transport

   !--------------------------------------------------------------------
   !
   ! Private module variables
   !
   !--------------------------------------------------------------------

!***********************************************************************

contains

!***********************************************************************
!
!  routine ocn_init_sediment_transport
!
!> \brief   Initialize MPAS-Ocean analysis member
!> \author  Zhendong Cao and Phillip J. Wolfram
!> \date    2019/03/07
!> \details
!>  This routine conducts all initializations required for the
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_init_sediment_transport(domain, err)!{{{

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

   end subroutine ocn_init_sediment_transport!}}}

!***********************************************************************
!
!  routine ocn_compute_sediment_transport
!
!> \brief   Compute MPAS-Ocean analysis member
!> \author  Zhendong Cao and Phillip J. Wolfram
!> \date    2019/03/07
!> \details
!>  This routine conducts all computation required for this
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_compute_sediment_transport(domain, timeLevel, err)!{{{

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

      type (mpas_pool_type), pointer :: sedimentTransportAMPool
      type (dm_info) :: dminfo
      type (block_type), pointer :: block
      type (mpas_pool_type), pointer :: statePool
      type (mpas_pool_type), pointer :: meshPool

      real (kind=RKIND), pointer :: salpha, SD50, rho0, rhoS, Vh, Dv,Ws
      real (kind=RKIND), pointer :: tau_ce, Erate, poro, tau_cd, Cd, Manning
      real (kind=RKIND), dimension(:,:), pointer :: velX, velY, velZ
      real (kind=RKIND), dimension(:), pointer :: posX, posY, bottomDepth, ssh
      real (kind=RKIND), dimension(:), pointer :: sedFluxVAx, sedFluxVAy, sedFluxBx, sedFluxBy
      real (kind=RKIND), dimension(:), pointer :: ero_flux, dep_flux
      real (kind=RKIND), dimension(:), pointer :: bedld_x, bedld_y
      real (kind=RKIND), dimension(:), pointer :: SSC_ref
      real (kind=RKIND), dimension(:,:), pointer :: SSC

      logical, pointer :: on_a_sphere, use_lat_lon_coords
      logical, pointer :: bedload, suspended
      integer, pointer :: nCells, nVertLevels, nCellsSolve
      character (len=StrKIND), pointer :: ws_formula, bedld_formula
      character (len=StrKIND), pointer :: SSC_ref_formula

      integer k, iCell, i
      real ratio1, rho_R, ND50, Umag, Umagb, dstar, Chezy, Usf, RouseN
      real cff1, cff2, cff3, cff4, cff5
      real phicw, w_asym   !! parameters related to waves, assigned ZEROs for just now
      real tau_tide, tau_wave, tau_mean, theta_mean, theta_wave, theta_ce,theta_sf,za
      real velXb, velYb, velXm, velYm
      real phi_x1, phi_x2, phi_x, phi_y
      real, parameter :: g = 9.81_RKIND
      real, parameter :: eps = 1.0E-14_RKIND
      real zCell
      err = 0

      dminfo = domain % dminfo
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_alpha',salpha)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_grain_size',SD50)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_drag_coefficient',Cd)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_grain_porosity',poro)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_erate',Erate)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_tau_ce',tau_ce)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_tau_cd',tau_cd)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_Manning_coef',Manning)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_water_density',rho0)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_grain_density',rhoS)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_kinematic_viscosity',Vh)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_vertical_diffusion_coefficient',Dv)

      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_use_lat_lon_coords', use_lat_lon_coords)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_bedload', bedload)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_suspended', suspended)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_ws_formula', ws_formula)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_bedld_formula', bedld_formula)
      call mpas_pool_get_config(ocnConfigs, 'config_AM_sedimentTransport_SSC_ref_formula', SSC_ref_formula)


      block => domain % blocklist
      do while (associated(block))
         ! get dimensions
         call mpas_pool_get_dimension(block % dimensions, 'nCells', nCells)
         call mpas_pool_get_dimension(block % dimensions, 'nCellsSolve', nCellsSolve)
         call mpas_pool_get_dimension(block % dimensions, 'nVertLevels', nVertLevels)

         ! get pointers to pools
         call mpas_pool_get_subpool(block % structs, 'state', statePool)
         call mpas_pool_get_subpool(block % structs, 'mesh', meshPool)
         call mpas_pool_get_subpool(block % structs, 'sedimentTransportAM', sedimentTransportAMPool)

         call mpas_pool_get_array(statePool, 'ssh', ssh, 1)
         call mpas_pool_get_array(meshPool, 'bottomDepth', bottomDepth)
         call mpas_pool_get_config(meshPool, 'on_a_sphere', on_a_sphere)
         if (.not. on_a_sphere) then
            use_lat_lon_coords = .false.
         end if

         if (use_lat_lon_coords) then
            call mpas_pool_get_array(meshPool, 'lonCell', posX)
            call mpas_pool_get_array(meshPool, 'latCell', posY)
            velX => velocityZonal
            velY => velocityMeridional
         else
            call mpas_pool_get_array(meshPool, 'xCell', posX)
            call mpas_pool_get_array(meshPool, 'yCell', posY)
            velX => velocityX
            velY => velocityY
         end if 


         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentFallVelocity', Ws)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentErosionFlux', ero_flux)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentDepositionFlux', dep_flux)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentFluxVAX', sedFluxVAx)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentFluxVAY', sedFluxVAy)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentFluxBX', sedFluxBx)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentFluxBY', sedFluxBy)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentBedloadX', bedld_x)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentBedloadY', bedld_y)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentBottomReferenceConcentration', SSC_ref)
         call mpas_pool_get_array(sedimentTransportAMPool, 'sedimentConcentration', SSC)

!======> COMPUTE SedimentFallVelocity [m/s] 
         ! sieve diameter (SD50) to nominal diameter (ND50), Raudkivi [1990]
         ND50 = SD50*1.1_RKIND
         ! sediment/water density comparsion  -> specific graivity
         rho_R = rhoS/rho0-1
         if (ws_formula == 'Goldstein-Coco2013') then
           !Goldstein & Coco [2013]
           Ws = (37.8_RKIND*ND50*rho_R*(1+100.0_RKIND*ND50))/   &
              (0.383_RKIND+1E4*rho_R*Vh+1E2*ND50*rho_R**2)
         elseif (ws_formula == 'Cheng1997') then
           dstar = SD50* (rho_R*g/Vh**2.0_RKIND)**0.333_RKIND
           Ws = Vh/SD50*(sqrt(25.0_RKIND+1.2_RKIND*dstar**2)-5.0_RKIND)**1.5_RKIND
         elseif (ws_formula == 'VanRijn1993') then
           if (SD50<1.0E-4) then
             Ws = rho_R*g*SD50**2.0_RKIND/(18.0_RKIND*Vh)
           elseif (SD50>1.0E-3) then
             Ws = 1.1_RKIND*sqrt(rho_R*g*SD50)
           else
             Ws = 10.0_RKIND*Vh/SD50 *(sqrt(1.0_RKIND+0.01_RKIND*rho_R*g*SD50**3.0_RKIND/Vh**2.0_RKIND)-1)
           end if
         elseif (ws_formula == 'Soulsby1997') then
           Ws = 10.36_RKIND*Vh/SD50 * (sqrt(1.0_RKIND+0.156_RKIND*rho_R*g*SD50**3.0_RKIND/(16.0_RKIND*Vh**2.0))-1)
         else
           print*,'please select the ws_formula from one of the following:'
           print*, 'VanRijn1993, Soulsby1997, Cheng1997, Goldstein-Coco2013'
           print*, 'Model will stop ...'
           exit
         end if
!<======

!======> COMPUTE SedimentTransportFlux [kg/m/s]   
        ! compute ratio1 in sedFlux = ratio1*U^3, Grawe et al. [2014]
        ratio1 = salpha*Dv/Ws**2

        do iCell = 1,nCellsSolve
            velXm = sum(velX(:,iCell))/float(nVertLevels)
            velYm = sum(velY(:,iCell))/float(nVertLevels)
            velXb = velX(size(velX,1),iCell)
            velYb = velY(size(velY,1),iCell)

            sedFluxVAx(iCell) = ratio1*velXm**3.0_RKIND
            sedFluxVAy(iCell) = ratio1*velYm**3.0_RKIND
            sedFluxBx(iCell) = ratio1*velXb**3.0_RKIND
            sedFluxBy(iCell) = ratio1*velYb**3.0_RKIND
        end do
!<======

        cff1 = rho_R*g*SD50+eps
        cff2 = sqrt(rho_R*g*SD50)*SD50*rhoS
        !wave-related parameters
        w_asym = 0.0_RKIND
        phicw = 0.0_RKIND

        do iCell = 1,nCellsSolve
            velXm = sum(velX(:,iCell))/float(nVertLevels)
            velYm = sum(velY(:,iCell))/float(nVertLevels)
            velXb = velX(size(velX,1),iCell)
            velYb = velY(size(velY,1),iCell)
            Umag = sqrt(velXm**2.0_RKIND + velYm**2.0_RKIND)
            Umagb = sqrt(velXb**2.0_RKIND + velYb**2.0_RKIND)

            ! compute bottom friction Cd = [von_Karmann/(1+log(z0/h))]^2, von_karmann=0.4, z0=SD50/12, h=bottomDepth+ssh
            cff3 = SD50/12.0_RKIND
            cff4 = 1+log(cff3/(eps+ssh(iCell)+bottomDepth(iCell)))
            Cd = (0.4_RKIND/cff4)**2.0_RKIND
            ! compute shear velocity, tau= rho0*Cd*Umag**2 = rho0*Usf**2 => Usf=sqrt(Cd)*Umag
            Usf = Umag * sqrt(Cd)
            ! compute Rouse number, RouseN=Ws/(von_karmann*Usf)
            RouseN = Ws/(0.4_RKIND*(Usf+eps))
!! Rouse number (suspension parameter) indicates the balance between sediment suspension and settling. According to the
!!  equation of it, when Ws>Usf, which also means RouseN>2.5, there should be no sediment in suspension. To avoid the
!! "Float-point exception" error when Usf is very small and RouseN is super huge, we mannually set a maximum value of
!! 25 for RouseN, which is 10 times bigger than RouseN with ideally no suspended sediment.
            RouseN = min(RouseN, 25.0_RKIND)

            ! compute shear stress [m^2 s^{-2}]
            tau_tide = Cd*Umagb**2.0_RKIND
            tau_wave = 0.0_RKIND
            tau_mean = tau_tide*(1.0_RKIND+1.2_RKIND*(tau_wave/(tau_wave+tau_tide+eps))**1.5_RKIND)

!======> COMPUTE Suspended Transport [] <--- to be continued
            if (suspended) then
              ! surface erosion mass flux ero_flux in unit (kg m-2 s-1) 
              ero_flux(iCell) = (1.0_RKIND-poro)*Erate*MAX(tau_mean/tau_ce -1.0_RKIND, 0.0_RKIND)
            end if
!<======

!======> COMPUTE SSC_ref: near-bottom suspended sediment concentration (reference concentration) [kg/m3]
            ! Three equations:
            ! 1) Lee2004,JGR; 2) Goldstein2014,Earth Surface Dynamics; 3) Zyserman-Fredsoe1994, J. Hydraul. Eng.
            if (SSC_ref_formula == 'Lee2004') then
              theta_sf = Usf**2.0_RKIND/cff1
              SSC_ref(iCell) = 2.58_RKIND*(theta_sf*Usf/Ws)**1.45_RKIND
            elseif (SSC_ref_formula == 'Goldstein2014') then
              SSC_ref(iCell) = (0.328_RKIND*Umagb/(0.0688_RKIND+1E3*SD50))**2_RKIND
            elseif (SSC_ref_formula == 'Zyserman-Fredsoe1994') then
              theta_sf = tau_mean/cff1
              theta_sf = max(theta_sf, 0.045_RKIND)              
              cff3 = 0.331_RKIND*(theta_sf-0.045_RKIND)**1.75_RKIND
              cff4 = 1.0_RKIND+0.72_RKIND*(theta_sf-0.045_RKIND)**1.75_RKIND
              SSC_ref(iCell) = cff3/cff4
            else
                print*, 'Please pick one SSC_ref_formula from the following three:'
                print*, 'Lee2004, Goldstein2014,Zyserman-Fredsoe1994'
                print*, 'Model will stop ...'
                exit
            endif
!<======

!======> Compute SSC based on the Rouse Profile
        ! SSC(z) = SSC_ref*[z/za * (h-za)/(h-z)]**(-b), where b is the Rouse number (or suspension parameter)
        ! b = Ws/(von_karmann*usf); za is reference height (0.01m), h is bottomDepth
        ! zMid in MPAS-O is the distance under free surface and is negative most of the time
        ! In the above equation, z means the depth above the bottom, so z=h+zMid --> h-z = -zMid
!! Since the reference concentration is the largest SSC at height za above bed, we need make sure h+zMid>=za
!! that is to say zMid = max(zMid,za-h)
           za = 0.01_RKIND
           if (SSC_ref_formula == 'Zyserman-Fredsoe1994') za=2.0_RKIND*SD50
           do k=1,nVertLevels
             zMid(k,iCell) = max(za-bottomDepth(iCell), zMid(k,iCell)) ! make sure -zMid>=za
             zCell = bottomDepth(iCell)+zMid(k,iCell)+eps
             cff3 = za/(bottomDepth(iCell)-za+eps)
             if (zCell/bottomDepth(iCell) .lt. 0.5_RKIND) then
               cff4 = -zMid(k,iCell)/zCell*cff3
               SSC(k,iCell) = SSC_ref(iCell)*cff4**RouseN
             else
               cff4 = exp(-4.0_RKIND*RouseN*(zCell/bottomDepth(iCell)-0.5_RKIND))
               SSC(k,iCell) = SSC_ref(iCell)*cff4*cff3**RouseN
             endif
           enddo !! k loop
!<======          

!======> COMPUTE Bedload Transport [kg/m/s], using one of the three formulae define in bedld_formula
           if (bedload) then
               theta_mean = tau_mean/cff1
               theta_wave = tau_wave/cff1
               theta_ce = tau_ce/cff1

              if (bedld_formula == 'Soulsby-Damgaard')then
               cff3 = 0.5*(1.0_RKIND+SIGN(1.0_RKIND,theta_mean/theta_ce-1.0_RKIND))

               phi_x1 = 12.0_RKIND*sqrt(theta_mean)*MAX(theta_mean-theta_ce,0.0_RKIND)
               phi_x2 = 12.0_RKIND*(0.9534_RKIND+0.1907_RKIND*COS(2.0_RKIND*phicw))* &
                        sqrt(theta_wave)*theta_mean +                                       &
                        12.0_RKIND*(0.229_RKIND*w_asym*theta_wave**1.5_RKIND*COS(phicw))

               if (ABS(phi_x2) .gt. phi_x1) then
                 phi_x = phi_x2
               else
                 phi_x = phi_x1
               end if

               bedld_x(iCell) = phi_x*cff2*cff3

               phi_y = 12.0_RKIND*0.1907_RKIND*theta_wave**2* &
                       (theta_mean*SIN(2.0_RKIND*phicw)+1.2_RKIND*w_asym*theta_wave*SIN(phicw)) &
                       /(theta_wave**1.5_RKIND + 1.5_RKIND*theta_mean**1.5_RKIND+eps)
               bedld_y = phi_y*cff2*cff3

              elseif (bedld_formula == 'Meyer-Peter-Meuller') then
                cff3 = 1.0_RKIND/sqrt(velXb**4.0_RKIND+velYb**4.0_RKIND+eps)
                phi_x = max(8.0_RKIND*(theta_mean-0.047_RKIND), 0.0_RKIND)*velXb**2.0_RKIND
                phi_y = max(8.0_RKIND*(theta_mean-0.047_RKIND), 0.0_RKIND)*velYb**2.0_RKIND

                bedld_x(iCell) = phi_x*cff2*cff3
                bedld_y(iCell) = phi_y*cff2*cff3

              elseif (bedld_formula == 'Engelund-Hansen') then
                ! Chezy = 1/Manning * water_depth^(1/6) with unit [m^0.5 s^(-1)]
                ! In ocean water, Manning coeffcient varies between [0.012 0.025],see P.C. Kerr et al, 2013 JGR-Ocean
                Chezy = 1.0_RKIND/Manning*abs(ssh(iCell)+bottomDepth(iCell))**(1.0_RKIND/6.0_RKIND)
                Chezy = max(20.0_RKIND, Chezy)
                Chezy = min(100.0_RKIND, Chezy)
                cff4 = 0.05_RKIND*Umag**4.0_RKIND*rhoS
                cff5 = sqrt(g)*Chezy**3.0_RKIND*rho_R**2.0_RKIND*SD50
                bedld_x(iCell) = cff4/cff5*velXb
                bedld_y(iCell) = cff4/cff5*velYb
              else
                print*, 'pick one bedld_formula from the following three:'
                print*, 'Soulsby-Damgaard, Meyer-Peter-Meuller, Engelund-Hansen'
                print*, 'Model will stop ...'
                exit
              end if
            end if

         end do !! iCell loop

         block => block % next
      end do !! do while (associated(block)) loop

   end subroutine ocn_compute_sediment_transport!}}}

!***********************************************************************
!
!  routine ocn_restart_sediment_transport
!
!> \brief   Save restart for MPAS-Ocean analysis member
!> \author  Zhendong Cao and Phillip J. Wolfram
!> \date    2019/03/07
!> \details
!>  This routine conducts computation required to save a restart state
!>  for the MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_restart_sediment_transport(domain, err)!{{{

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

   end subroutine ocn_restart_sediment_transport!}}}

!***********************************************************************
!
!  routine ocn_finalize_sediment_transport
!
!> \brief   Finalize MPAS-Ocean analysis member
!> \author  Zhendong Cao and Phillip J. Wolfram
!> \date    2019/03/07
!> \details
!>  This routine conducts all finalizations required for this
!>  MPAS-Ocean analysis member.
!
!-----------------------------------------------------------------------

   subroutine ocn_finalize_sediment_transport(domain, err)!{{{

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

   end subroutine ocn_finalize_sediment_transport!}}}

end module ocn_sediment_transport

! vim: foldmethod=marker

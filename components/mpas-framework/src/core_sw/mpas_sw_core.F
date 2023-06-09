! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.io/license.html
!
module sw_core

   use mpas_framework
   use mpas_timekeeping
   use mpas_log

   type (MPAS_Clock_type), pointer :: clock

   contains


   function sw_core_init(domain, startTimeStamp) result(iErr)
   
      use mpas_derived_types
      use mpas_pool_routines
      use mpas_stream_manager
      use sw_test_cases
      use sw_constants
   
      implicit none
   
      type (domain_type), intent(inout) :: domain
      character(len=*), intent(out) :: startTimeStamp
      integer :: ierr
   
      real (kind=RKIND) :: dt
      type (block_type), pointer :: block
      type (mpas_pool_type), pointer :: meshPool
      type (mpas_pool_type), pointer :: statePool

      logical, pointer :: config_do_restart
      real (kind=RKIND), pointer :: config_dt
      character (len=StrKIND), pointer :: xtime
      type (MPAS_Time_Type) :: startTime

      iErr = 0

      call mpas_pool_get_config(domain % configs, 'config_do_restart', config_do_restart)
      call mpas_pool_get_config(domain % configs, 'config_dt', config_dt)

      !
      ! Set "local" clock to point to the clock contained in the domain type
      !
      clock => domain % clock

      !
      ! Set startTimeStamp based on the start time of the simulation clock
      !
      startTime = mpas_get_clock_time(clock, MPAS_START_TIME, ierr)
      call mpas_get_time(startTime, dateTimeString=startTimeStamp) 

      !
      ! If this is a restart run, read the restart stream, else read the input stream.
      ! Regardless of which stream we read for initial conditions, reset the
      ! input alarms for both input and restart before reading any remaining input streams.
      !
      if (config_do_restart) then
         call MPAS_stream_mgr_read(domain % streamManager, streamID='restart', ierr=ierr)
      else
         call MPAS_stream_mgr_read(domain % streamManager, streamID='input', ierr=ierr)
      end if
      call MPAS_stream_mgr_reset_alarms(domain % streamManager, streamID='input', direction=MPAS_STREAM_INPUT, ierr=ierr)
      call MPAS_stream_mgr_reset_alarms(domain % streamManager, streamID='restart', direction=MPAS_STREAM_INPUT, ierr=ierr)

      ! Read all other inputs
      call MPAS_stream_mgr_read(domain % streamManager, ierr=ierr)
      call MPAS_stream_mgr_reset_alarms(domain % streamManager, direction=MPAS_STREAM_INPUT, ierr=ierr)

      call sw_constants_init(domain % configs, domain % packages)

      if (.not. config_do_restart) call setup_sw_test_case(domain)

      !
      ! Initialize core
      !
      dt = config_dt

      block => domain % blocklist
      do while (associated(block))
         call mpas_pool_get_subpool(block % structs, 'mesh', meshPool)
         call mpas_pool_get_subpool(block % structs, 'state', statePool)

         call mpas_init_block(block, meshPool, dt)

         call mpas_pool_get_array(statePool, 'xtime', xtime, 1)

         xtime = startTimeStamp
         block => block % next
      end do

   end function sw_core_init


   subroutine simulation_clock_init(core_clock, configs, ierr)

      implicit none

      type (MPAS_Clock_type), intent(inout) :: core_clock
      type (mpas_pool_type), intent(inout) :: configs
      integer, intent(out) :: ierr

      type (MPAS_Time_Type) :: startTime, stopTime, alarmStartTime
      type (MPAS_TimeInterval_type) :: runDuration, timeStep, alarmTimeStep
      integer :: local_err

      character (len=StrKIND), pointer :: config_start_time, config_run_duration, config_stop_time
      real (kind=RKIND), pointer :: config_dt

      ierr = 0

      call mpas_pool_get_config(configs, 'config_dt', config_dt)
      call mpas_pool_get_config(configs, 'config_start_time', config_start_time)
      call mpas_pool_get_config(configs, 'config_run_duration', config_run_duration)
      call mpas_pool_get_config(configs, 'config_stop_time', config_stop_time)

      call mpas_set_time(curr_time=startTime, dateTimeString=config_start_time, ierr=local_err)
      call mpas_set_timeInterval(timeStep, dt=config_dt, ierr=local_err)

      if (trim(config_run_duration) /= "none") then
         call mpas_set_timeInterval(runDuration, timeString=config_run_duration, ierr=local_err)
         call mpas_create_clock(core_clock, startTime=startTime, timeStep=timeStep, runDuration=runDuration, ierr=local_err)

         if (trim(config_stop_time) /= "none") then
            call mpas_set_time(curr_time=stopTime, dateTimeString=config_stop_time, ierr=local_err)
            if(startTime + runduration /= stopTime) then
               call mpas_log_write('config_run_duration and config_stop_time are inconsitent: using config_run_duration.', MPAS_LOG_WARN)
            end if
         end if
      else if (trim(config_stop_time) /= "none") then
         call mpas_set_time(curr_time=stopTime, dateTimeString=config_stop_time, ierr=local_err)
         call mpas_create_clock(core_clock, startTime=startTime, timeStep=timeStep, stopTime=stopTime, ierr=local_err)
      else
          call mpas_log_write('Neither config_run_duration nor config_stop_time were specified.', MPAS_LOG_ERR)
          ierr = 1
      end if

      !TODO: use this code if we desire to convert config_stats_interval to alarms 
      !(must also change config_stats_interval type to character) 
      ! set stats alarm, if necessary
      !if (trim(config_stats_interval) /= "none") then      
      !   call mpas_set_timeInterval(alarmTimeStep, timeString=config_stats_interval, ierr=local_err)
      !   alarmStartTime = startTime + alarmTimeStep
      !   call mpas_add_clock_alarm(core_clock, statsAlarmID, alarmStartTime, alarmTimeStep, ierr=local_err)
      !end if

   end subroutine simulation_clock_init


   subroutine mpas_init_block(block, meshPool, dt)
   
      use mpas_derived_types
      use mpas_pool_routines
      use sw_time_integration
      use mpas_rbf_interpolation
      use mpas_vector_reconstruction
   
      implicit none
   
      type (block_type), intent(inout) :: block
      type (mpas_pool_type), intent(inout) :: meshPool
      real (kind=RKIND), intent(in) :: dt

      type (mpas_pool_type), pointer :: statePool

      real (kind=RKIND), dimension(:,:), pointer :: u, uReconstructX, uReconstructY, uReconstructZ, uReconstructZonal, uReconstructMeridional
   
      call mpas_pool_get_subpool(block % structs, 'state', statePool)


      call mpas_pool_get_array(statePool, 'u', u, 1)
      call mpas_pool_get_array(statePool, 'uReconstructX', uReconstructX, 1)
      call mpas_pool_get_array(statePool, 'uReconstructY', uReconstructY, 1)
      call mpas_pool_get_array(statePool, 'uReconstructZ', uReconstructZ, 1)
      call mpas_pool_get_array(statePool, 'uReconstructZonal', uReconstructZonal, 1)
      call mpas_pool_get_array(statePool, 'uReconstructMeridional', uReconstructMeridional, 1)

      call sw_compute_solve_diagnostics(dt, statePool, meshPool, 1)
      call compute_mesh_scaling(meshPool) 

      call mpas_rbf_interp_initialize(meshPool)
      call mpas_init_reconstruct(meshPool)
      call mpas_reconstruct(meshPool, u,                  &
                       uReconstructX, uReconstructY, uReconstructZ, &
                       uReconstructZonal, uReconstructMeridional)

   
   end subroutine mpas_init_block
   
   
   function sw_core_run(domain) result(iErr)
   
      use mpas_derived_types
      use mpas_pool_routines
      use mpas_kind_types
      use mpas_stream_manager
      use mpas_timer
   
      implicit none
   
      type (domain_type), intent(inout) :: domain
      integer :: ierr

      integer :: itimestep
      real (kind=RKIND) :: dt
      type (block_type), pointer :: block_ptr
      type (mpas_pool_type), pointer :: statePool

      type (MPAS_Time_Type) :: currTime
      character(len=StrKIND) :: timeStamp
      
      real (kind=RKIND), pointer :: config_dt

      iErr = 0

      call mpas_pool_get_config(domain % configs, 'config_dt', config_dt)
   
      ! Eventually, dt should be domain specific
      dt = config_dt

      currTime = mpas_get_clock_time(clock, MPAS_NOW, ierr)
      call mpas_get_time(curr_time=currTime, dateTimeString=timeStamp, ierr=ierr)         
      call mpas_log_write('Initial timestep ' // trim(timeStamp))

      ! Avoid writing a restart file at the initial time
      call MPAS_stream_mgr_reset_alarms(domain % streamManager, streamID='restart', direction=MPAS_STREAM_OUTPUT, ierr=ierr)

      call mpas_stream_mgr_write(domain % streamManager, ierr=ierr)
      call mpas_stream_mgr_reset_alarms(domain % streamManager, direction=MPAS_STREAM_OUTPUT, ierr=ierr)

      ! During integration, time level 1 stores the model state at the beginning of the
      !   time step, and time level 2 stores the state advanced dt in time by timestep(...)
      itimestep = 0
      do while (.not. mpas_is_clock_stop_time(clock))

         itimestep = itimestep + 1
         call mpas_advance_clock(clock)

         currTime = mpas_get_clock_time(clock, MPAS_NOW, ierr)
         call mpas_get_time(curr_time=currTime, dateTimeString=timeStamp, ierr=ierr)         
         call mpas_log_write('Doing timestep ' // trim(timeStamp))

         call mpas_timer_start("time integration")
         call mpas_timestep(domain, itimestep, dt, timeStamp)
         call mpas_timer_stop("time integration")

         ! Move time level 2 fields back into time level 1 for next time step
         block_ptr => domain % blocklist
         do while(associated(block_ptr))
            call mpas_pool_get_subpool(block_ptr % structs, 'state', statePool)
            call mpas_pool_shift_time_levels(statePool)
            block_ptr => block_ptr % next
         end do

         call mpas_stream_mgr_write(domain % streamManager, ierr=ierr)
         call mpas_stream_mgr_reset_alarms(domain % streamManager, direction=MPAS_STREAM_OUTPUT, ierr=ierr)

      end do

   end function sw_core_run
   
   
   subroutine mpas_timestep(domain, itimestep, dt, timeStamp)
   
      use mpas_derived_types
      use mpas_pool_routines
      use sw_time_integration
      use mpas_timer
      use sw_global_diagnostics
   
      implicit none
   
      type (domain_type), intent(inout) :: domain 
      integer, intent(in) :: itimestep
      real (kind=RKIND), intent(in) :: dt
      character(len=*), intent(in) :: timeStamp
      
      type (block_type), pointer :: block_ptr
      type (mpas_pool_type), pointer :: statePool, meshPool
      integer :: ierr
      integer, pointer :: config_stats_interval

      call mpas_pool_get_config(domain % configs, 'config_stats_interval', config_stats_interval)
   
      call sw_timestep(domain, dt, timeStamp)
   
      if(config_stats_interval .gt. 0) then
          if(mod(itimestep, config_stats_interval) == 0) then
              block_ptr => domain % blocklist
              if(associated(block_ptr % next)) then
                  call mpas_log_write('computeGlobalDiagnostics assumes '//&
                             'that there is only one block per processor.', MPAS_LOG_ERR)
              end if

              call mpas_pool_get_subpool(block_ptr % structs, 'state', statePool)
              call mpas_pool_get_subpool(block_ptr % structs, 'mesh', meshPool)
   
              call mpas_timer_start("global_diagnostics")
              call sw_compute_global_diagnostics(domain % dminfo, &
                       statePool, meshPool, itimestep, dt, 2)
              call mpas_timer_stop("global_diagnostics")
          end if
      end if

      !TODO: replace the above code block with this if we desire to convert config_stats_interval to use alarms
      !if (mpas_is_alarm_ringing(clock, statsAlarmID, ierr=ierr)) then
      !   call mpas_reset_clock_alarm(clock, statsAlarmID, ierr=ierr)

      !   block_ptr => domain % blocklist
      !   if(associated(block_ptr % next)) then
      !      write(0,*) 'Error: computeGlobalDiagnostics assumes ',&
      !                 'that there is only one block per processor.'
      !   end if

      !   call mpas_timer_start("global_diagnostics")
      !   call sw_compute_global_diagnostics(domain % dminfo, &
      !            block_ptr % state % time_levs(2) % state, block_ptr % mesh, &
      !            timeStamp, dt)
      !   call mpas_timer_stop("global_diagnostics")
      !end if
   
   end subroutine mpas_timestep
   
   
   function sw_core_finalize(domain) result(iErr)
   
      use mpas_derived_types
   
      implicit none

      type (domain_type), intent(inout) :: domain 
      integer :: ierr

      iErr = 0
 
      call mpas_destroy_clock(clock, ierr)

   end function sw_core_finalize


   subroutine compute_mesh_scaling(meshPool)

      use mpas_derived_types
      use mpas_pool_routines
      use sw_constants

      implicit none

      type (mpas_pool_type), intent(inout) :: meshPool

      integer :: iEdge, cell1, cell2
      integer, pointer :: nEdges
      integer, dimension(:,:), pointer :: cellsOnEdge
      real (kind=RKIND), dimension(:), pointer :: meshDensity, meshScalingDel2, meshScalingDel4

      logical, pointer :: config_h_ScaleWithMesh

      call mpas_pool_get_dimension(meshPool, 'nEdges', nEdges)

      call mpas_pool_get_array(meshPool, 'cellsOnEdge', cellsOnEdge)
      call mpas_pool_get_array(meshPool, 'meshDensity', meshDensity)
      call mpas_pool_get_array(meshPool, 'meshScalingDel2', meshScalingDel2)
      call mpas_pool_get_array(meshPool, 'meshScalingDel4', meshScalingDel4)

      call mpas_pool_get_config(swConfigs, 'config_h_ScaleWithMesh', config_h_ScaleWithMesh)

      !
      ! Compute the scaling factors to be used in the del2 and del4 dissipation
      !
      meshScalingDel2(:) = 1.0
      meshScalingDel4(:) = 1.0
      if (config_h_ScaleWithMesh) then
         do iEdge = 1, nEdges
            cell1 = cellsOnEdge(1,iEdge)
            cell2 = cellsOnEdge(2,iEdge)
            meshScalingDel2(iEdge) = 1.0 / ( (meshDensity(cell1) + meshDensity(cell2) )/2.0)**(5.0/12.0)
            meshScalingDel4(iEdge) = 1.0 / ( (meshDensity(cell1) + meshDensity(cell2) )/2.0)**(5.0/6.0)
         end do
      end if

   end subroutine compute_mesh_scaling

   !***********************************************************************
   !
   !  routine mpas_core_setup_packages
   !
   !> \brief   Pacakge setup routine
   !> \author  Doug Jacobsen
   !> \date    September 2011
   !> \details 
   !>  This routine is intended to correctly configure the packages for this MPAS
   !>   core. It can use any Fortran logic to properly configure packages, and it
   !>   can also make use of any namelist options. All variables in the model are
   !>   *not* allocated until after this routine is called.
   !
   !-----------------------------------------------------------------------
   subroutine mpas_core_setup_packages(configPool, packagePool, ierr)!{{{

      use mpas_derived_types

      implicit none

      type (mpas_pool_type), intent(in) :: configPool
      type (mpas_pool_type), intent(in) :: packagePool
      integer, intent(out) :: ierr

      ierr = 0

   end subroutine mpas_core_setup_packages!}}}


   !***********************************************************************
   !
   !  routine mpas_core_setup_clock
   !
   !> \brief   Pacakge setup routine
   !> \author  Michael Duda
   !> \date    6 August 2014
   !> \details 
   !>  The purpose of this routine is to allow the core to set up a simulation
   !>  clock that will be used by the I/O subsystem for timing reads and writes
   !>  of I/O streams.
   !>  This routine is called from the superstructure after the framework 
   !>  has been initialized but before any fields have been allocated and 
   !>  initial fields have been read from input files. However, all namelist
   !>  options are available.
   !
   !-----------------------------------------------------------------------
   subroutine mpas_core_setup_clock(core_clock, configs, ierr)

      use mpas_derived_types

      implicit none

      type (MPAS_Clock_type), intent(inout) :: core_clock
      type (mpas_pool_type), intent(inout) :: configs
      integer, intent(out) :: ierr

      call simulation_clock_init(core_clock, configs, ierr)

   end subroutine mpas_core_setup_clock


   !***********************************************************************
   !
   !  routine mpas_core_get_mesh_stream
   !
   !> \brief   Returns the name of the stream containing mesh information
   !> \author  Michael Duda
   !> \date    8 August 2014
   !> \details 
   !>  This routine returns the name of the I/O stream containing dimensions,
   !>  attributes, and mesh fields needed by the framework bootstrapping 
   !>  routine. At the time this routine is called, only namelist options 
   !>  are available.
   !
   !-----------------------------------------------------------------------
   subroutine mpas_core_get_mesh_stream(configs, stream, ierr)

      use mpas_derived_types
      use mpas_pool_routines

      implicit none

      type (mpas_pool_type), intent(in) :: configs
      character(len=*), intent(out) :: stream
      integer, intent(out) :: ierr

      logical, pointer :: config_do_restart

      ierr = 0

      call mpas_pool_get_config(configs, 'config_do_restart', config_do_restart)

      if (.not. associated(config_do_restart)) then
         ierr = 1
      else if (config_do_restart) then
         write(stream,'(a)') 'restart'
      else
         write(stream,'(a)') 'input'
      end if

   end subroutine mpas_core_get_mesh_stream

end module sw_core

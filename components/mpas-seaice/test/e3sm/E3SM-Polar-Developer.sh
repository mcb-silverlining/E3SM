#!/bin/bash 
shopt -s extglob

usage() {
cat << EOF | less
NAME   

 E3SM-Polar-Developer.sh - Extensible polar climate development script for E3SM


SYNOPSIS 

 E3SM-Polar-Developer.sh [-s|--sandbox]   (CODE SANBDOX NAME)

                         [-f|--fetch]     (FORK) (BRANCH)

                         [-t|--testsuite]    

                         [-n|--newcase]
                         [-d|--duration]  (MONTHS)
                         [-c|--config]    (CONFIG)
                         [-e|--emc]
                         [-k|--kombo]     (NAMEFILE)

                         [-b|--build] 
                         [-q|--qsubmit]

                         [-a|--analyze]   (COMPARISON CASE)

                         [-h|--help]       

 This is an extensible tool to develop new polar physics and BGC in E3SM from initial
 inception through to production simulations. This script creates a structure of
 sandboxes, cases, simulations and methods to compare them. Example workflows
 are provided after first listing the available options. This script version focuses 
 on developing the sea ice model in the coupled E3SM framework.  Planned version 2 
 extensions to the full polar system are listed at the bottom of this help page. This 
 script must use one of the -s, -c, or -h options, the former in combination with 
 options listed below.  Casenames created from the -s sandbox are assigned according 
 to the combined information in the -s, -c, -d, -e, and -k options.  The script will 
 work using the following machines: ${joinedmachines%,}.


OPTIONS

 [-s|--sandbox]   - One of three possible mandatory options giving the name of the 
                    code sandbox, which will be located under the directory:
                    ${CODE_BASE}
                    The associated case will be located under the directory:
                    ${CASE_BASE}
 
 [-f|--fetch]     - Clones to a sandbox code from an E3SM repository. You may specify 
                    arguments for the code FORK and BRANCH if different from defaults:
                    FORK:   ${FORK}, BRANCH: ${BRANCH} 
                    The branch may be specified as a git hash. If the sandbox already
                    exists, it will only be overwritten if explicitly requested when
                    the user is challenged with a Y/N prompt. 

 [-t|--testsuite] - Runs preset polar ERT, ERI, PEM, and PET tests on: ${joinedmachines%,}.
                    This option is not available in Version 1.

 [-n|--newcase]   - Creates or overwrites a case for a given code sandbox. If the
                    sandbox needs to be overwritten, the user will be challenged 
                    for confirmation prior to proceeding.

 [-d|--duration]  - Change the maximum duration in months with annual restarts from
                    a default run length of ${DURATION} months. A specification of more than
                    12 months will round up the number of months to the nearest year; 
                    A duration of 11 months will run for that amount of simulated
                    time, but 13 months will run for 2 simulated years (24 months),
                    with resubmition after the first 12-month simulation. Using this 
                    option, where the duration exceeds 12 months, one may set up a 
                    self-sustaining year-on-year production run. 

 [-c|--config]    - Specifies one of many available configurations. This option
                    does not need to be specified if the default  ${CONFIG}-Case is used. 
                    To list all availale configurations, enter 'E3SM-Polar-Developer.sh -c'
                    on the command line. Only configurations relevant to E3SM Phase 3 will 
                    be maintained.

 [-e|--emc]       - Check for energy and mass conservation using analysis members
                    in the sea ice and ocean models. Coming in Version 2: graphing
                    and summarizing conservation properties with combined -ea options.

 [-k|--kombo]     - Test namelist combinations in the sea ice model using the input 
                    namelist file '<kombotag>_nlk_mpassi' giving options to be tested 
                    using the following format:

                    NAMELIST_ENTRY1 = {false,true}
                    NAMELIST_ENTRY2 = {'string1','string2','string3'} 
                    NAMELIST_ENTRY3 = {number1,number2} 

                    This option should be entered as -k <kombotag>_nlk_mpassi where
                    <kombotag> is used in the name of the case. Coming in Verion 2:
                    Extension to all E3SM component model namelists.

 [-b|--build]     - Builds or rebuilds the case for given 

 [-q|--qsubmit]   - Submits case(s) to the queue.

 [-a|--analyze]   - Analyze the output of a given simulation, and compare it against
                    equivalent simulations from other sandboxes. At present this o
                    option provides a difference between integrations. Version 2 will 
                    provide graphical interpretation of energy, mass and state 
                    variables.

 [-h|--help]      - Provides this help page.


SANDBOX, CASES, AND COMBINATIONS

 When a new sandbox is created, it is assigned a directory according to its name,
 situated at ${CODE_BASE}/<sandbox>. 

 When a new  case is created, it is assigned a name according to the configuration, 
 duration, energy and mass conservation, namelist combination, and sandbox
 <config><duration>.<kombotag>.emc.<sandbox>.<machine> under:
 ${CASE_BASE}
 If one or other of the -k and -e options are omitted, the <kombotag>.emc modifiers
 are respectively removed from the case name. Note that the -e and -k options must
 always be specified to point to a case that includes them.

 When multiple (n>1) combinations are specified with the -k option, seperate 
 case_script and run directories are sequentially numbered under the case directory 
 as case_scripts.k000 ... case_scripts.k<n> and as run.k000 ... run.k<n> directories. 


EXAMPLE-A WORKFLOW - Simple three-month baseline simulation

 1) E3SM-Polar-Developer.sh -s baseline -fnb 

 2) E3SM-Polar-Developer.sh -s baseline -q

 3) E3SM-Polar-Developer.sh -s baseline -a

 This clones ${FORK} and sets up the sandbox 'baseline' ${BRANCH} 
 in ${CODE_BASE}, then creates the default ${DURATION}-Month ${CONFIG}-Case, submits it 
 to the queue, and indicates when the run is complete. The case directory 
 ${CONFIG}${DURATION}.baseline.${MACHINES[$MACH]} is located in ${CASE_BASE}.


EXAMPLE-B WORKFLOW - Create a comparable case for a branch with changes

 1) E3SM-Polar-Developer.sh -s change1 -f git@github.com:eclare108213/E3SM \\
                                          eclare108213/seaice/icepack-integration

 2) E3SM-Polar-Developer.sh -c

 3) E3SM-Polar-Developer.sh -s change1 -c D -d 3 -nb -k set1_nlk_mpassi

    Where set1_nlk_mpassi is a file that include a line testing the
    column package and icepack:
    config_column_physics_type = {'column_package','icepack'}

 4) E3SM-Polar-Developer.sh -s change1 -c ${CONFIG} -d ${DURATION} -k set1_nlk_mpassi -q

 5) E3SM-Polar-Developer.sh -s change1 -c ${CONFIG} -d ${DURATION} -k set1_nlk_mpassi -a ${CONFIG}${DURATION}.baseline.${MACHINES[$MACH]}

 This creates the sandbox 'change1' from the fork git@github.com:eclare108213/E3SM with
 branch eclare108213/seaice/icepack-integration. The second step lists all of the
 available configurations' compsets and resolutions, including the "D" configuration. 
 The third step generates a new case and builds for the two combinations in the file
 nset1_nlk_mpassi under the case D3.nset1.outputtest.anvil in 
 ${CASE_BASE} with subdirectories *.k000 and *.k001 for 
 each of the respective namelist combinations. The fourth step queues the two cases, 
 and the final step compares these two simulations with the baseline case established
 in the EXAMPLE-A WORKFLOW above.


EXAMPLE-C WORKFLOW

 1) E3SM-Polar-Developer.sh -c

 2) E3SM-Polar-Developer.sh -s baseline -c BSORRM -d 24 -e -nb

 3) E3SM-Polar-Developer.sh -s baseline -c BSORRM -d 24 -e -q

 4) E3SM-Polar-Developer.sh -s baseline -c BSORRM -d 24 -e -a

 After checking the available configurations in the first step, the second step
 uses the baseline sandbox created in EXAMPLE-A WORKFLOW to create and build a
 new case for the fully coupled model on the SORRM ice-ocean mesh with standard
 atmosphere and land resolution that runs for 12 months and resubmits for a second
 12 months using steps (2) and (3). Step (4) tells you if and when it is complete. 
 The -e option generates a timeseries of conservation residuals for both ice and
 ocean.


AUTHORS

 Andrew Roberts, Jon Wolfe, Elizabeth Hunke, Darin Comeau, Nicole Jeffery, Erin Thomas


VERSIONS

 This Version: 1.0 March 2023

 Version 2 is being designed to include the following additional features:
 1) Extension to Perlmutter 
 2) Addition of a dedicated E3SM polar test suite for the -t option
 3) Epansion of namelist combinations to multiple models, rather than just sea ice
 4) Addition of continue, hybrid, and branch simulations for production
 5) Switch to upcoming V3 Meshes in place of V2 meshes
 6) Graphical output of mass and energy evolution and sea ice thickness fields 
 7) Easy comparison of output between machines


EOF
}

#---------------------------------
main() {

# For debugging this script, uncomment line below
#set -x

# For running E3SM with debug on, change line below to true
readonly DEBUG_COMPILE=false

# Make directories created by this script world-readable
umask 022

# Get the command line options and set defaults
get_configuration $*

# Copy script into case_script directory for provenance
copy_script $*

# Fetch code from Github
clone_code

if [ -d ${CODE_ROOT} ]; then

 # Create namelist combinations
 namelist_kombo

 # Create case
 create_newcase

 if [ -d ${CASE_ROOT} ]; then

  # Build
  case_build

  if [ "${exit_script,,}" != "true" ]; then

   # Submit
   case_queue

   # Generate analysis scripts
   case_analyze
 
  fi

  printf "\n--- Case root: $(cd ${CASE_ROOT} && dirs +0)\n" 

 else

  printf "\n--- \x1B[31mNo case exists for this configuration\e[0m ---\n"

 fi

 # Provide directory stemming from home with tilde shorthand
 printf "\n--- Code root: $(cd ${CODE_ROOT} && dirs +0)\n" 

else

 printf "\n--- \x1B[31mNo code cloned\e[0m ---\n"

fi

# Provide directory stemming from home with tilde shorthand
echo $'\n--- Provenance:' "$(cd ${SCRIPT_PROVENANCE_DIR} && dirs +0)"

echo $'\n--- Script saved:' "${SCRIPT_PROVENANCE_NAME}"

echo $'\n'


}

#---------------------------------
get_configuration() {

    declare -Ag  MAXCOMBINATIONS
    declare -Ag  COMPSET
    declare -Ag  RESOLUTION
    declare -Ag  PELAYOUT
    declare -Ag  CONFIGDESCRIPTION

    # Change forks and branches here if you wish to switch defaults
    DEFAULT_FORK="git@github.com:E3SM-Project/E3SM.git" 
    DEFAULT_BRANCH="master" 

    # Change default configuration and run length here
    DEFAULT_CONFIG='D'
    DEFAULT_DURATION=3

    FORK="${DEFAULT_FORK}"
    # --- Auto-detect the machine and set project ---
    local host_node=`uname -n | cut -f 1 -d . | rev | cut -c 2- | rev`
    MACHINES=("anvil" "chrysalis")
    printf -v joinedmachines '%s,' "${MACHINES[@]}"

    PROJECTS=("condo" "e3sm")
    SCRATCHS=("/lcrc/group/e3sm" "/lcrc/group/e3sm")
    if [ "${host_node,,}" == "blueslogin" ]; then
     MACH=0
    elif [ "${host_node,,}" == "chrlogin" ]; then
     MACH=1
    else
     echo $'\n--- ERROR: Unable to auto-detect machine'
     echo $'\n'
     exit 
    fi

    # --- Default Settings ---
    do_code_clone=false
    do_test_suite=false
    do_case_create=false
    do_case_build=false
    do_case_queue=false
    do_case_kombo=false
    do_energy_mass=false
    do_case_analyze=false

    exit_script=false

    readonly CASE_GROUP='E3SM-Polar'
    readonly CODE_BASE="${HOME}/${CASE_GROUP}/code"
    readonly CASE_BASE="${SCRATCHS[$MACH]}/${USER}/${CASE_GROUP}"

    SANDBOX=''
    CASE2_NAME=''

    BRANCH="${DEFAULT_BRANCH}"

    CONFIG="${DEFAULT_CONFIG}"
    DURATION="${DEFAULT_DURATION}"

    # --- Parse options ---
    needs_arg() { if [ -z "$OPTARG" ]; then printf "\n--- ${OPT} needs an argument"; fi; }

    while getopts s:ftd:cek:nbqah-: OPT; do
      if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
        OPT="${OPTARG%%=*}"       # extract long option name
        OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
        OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
      fi
      case "$OPT" in
        s | sandbox )  needs_arg; SANDBOX="$OPTARG" ;;
        f | fetch )    eval "FORK=\${$((OPTIND))}" # allows two optional arguments
                       if [[ $FORK  =~ ^-.* ]] || [ -z ${FORK} ] ; then 
                        FORK="${DEFAULT_FORK}";
                       elif [ -n ${FORK} ]; then 
                        OPTIND=$((OPTIND+1)); 
                       fi
                       eval "BRANCH=\${$((OPTIND))}"
                       if [[ $BRANCH =~ ^-.* ]] || [ -z ${BRANCH} ] ; then 
                        BRANCH="${DEFAULT_BRANCH}";
                       elif [ -n ${BRANCH} ]; then 
                        OPTIND=$((OPTIND+1)) 
                       fi 
                       do_code_clone=true ;;
        t | test )     do_test_suite=true ;;
        n | newcase )  do_case_create=true ;;
        d | duration ) needs_arg; DURATION="$OPTARG" ;;
        c | config )   eval "CONFIG=\${$((OPTIND))}" # allows one optional argument
                       if [[ $CONFIG =~ ^-.* ]] || [ -z ${CONFIG} ] ; then
                        CONFIG="";
                       elif [ -n ${CONFIG} ]; then
                        OPTIND=$((OPTIND+1));
                       fi ;;
        e | emc )      do_energy_mass=true ;;
        k | kombo )    needs_arg; NAMEFILE="$OPTARG";
                       do_case_kombo=true;;
        b | build )    do_case_build=true ;;
        q | qsubmit )  do_case_queue=true ;;
        a | analyze )  eval "CASE2_NAME=\${$((OPTIND))}" # allows one optional argument
                       if [[ $CASE2_NAME =~ ^-.* ]] || [ -z ${CASE2_NAME} ] ; then
                        CASE2_NAME="";
                       elif [ -n ${CASE2_NAME} ]; then
                        OPTIND=$((OPTIND+1))
                       fi
		       do_case_analyze=true ;;
        h | help )     usage; exit ;;
        ??* )          printf "\n--- ERROR: No $OPT option. Get help with -h\n\n"; 
                       exit ;; # bad long opt
        ? )            printf "\n--- ERROR: Options awry. Get help with -h\n\n"; 
                       exit ;;  # getopt error
      esac
    done
    shift $((OPTIND-1)) # remove parsed options and args from $@ list

    # Check and set flags and variables dependent on command line options
    if [ -z $SANDBOX ] && [ ! -z $CONFIG ]; then
     printf "\n--- ERROR: Specify a sandbox (-s), list configurations (-c), or get help (-h)\n\n"
     exit 
    elif [ ! -z $SANDBOX ] && \
         [ "${do_code_clone,,}" != "true" ] && \
         [ "${do_test_suite,,}" != "true" ] && \
         [ "${do_case_create,,}" != "true" ] && \
         [ "${do_case_build,,}" != "true" ] && \
         [ "${do_case_queue,,}" != "true" ] && \
         [ "${do_case_kombo,,}" != "true" ] && \
         [ "${do_case_analyze,,}" != "true" ]  ; then
     printf "\n--- ERROR: Nothing to do for ${SANDBOX}. Use -h for help.\n\n"
     exit 
    elif [ "${do_case_build,,}" == "true" ] && [ "${do_case_queue,,}" == "true" ]; then
     printf "\n--- ERROR: Need to build and queue in seperate steps.\n\n"
     exit
    fi

    re='^[0-9]+$'
    if ! [[ $DURATION =~ $re ]] ; then 
     echo "--- ERROR: duration ${DURATION} is not an integer" >&2; 
    fi

    # Set compset, resolution, pe-layout, walltime and based on specific tests
    if [ "${do_test_suite,,}" == "true" ]; then

     echo $"--- UNDER CONSTRUCTION: E3SM Sea Ice Test Suite" 
     exit  

    # Setup run configurations if no over-riding test is specified
    else

     readonly MODEL_START_TYPE="initial"  # set to 'initial' or 'continue' only
     readonly START_DATE="0001-01-01"

     ####################################################################
     # SETTINGS FOR V2 MODEL CONFIGURATIONS. THESE WILL CHANGE TO V3 WHEN 
     # AVAILABLE. MAXCOMBINATIONS=0 INDICATES NOT YET READY TO RUN

     # D-CASES ##########################################################

     # D-CASE STANDARD RESOLUTION MESH
     CONFIGDESCRIPTION[D]="D-CASE AT STANDARD RESOLUTION WITH JRA 1.5 FORCING" 
     COMPSET[D]="2000_DATM%JRA-1p5_SLND_MPASSI_DOCN%SOM_DROF%JRA-1p5_SGLC_SWAV_TEST"
     RESOLUTION[D]="TL319_EC30to60E2r2"
     PELAYOUT[D]="S"
     MAXCOMBINATIONS[D]=32

     # D-CASE COLUMN-WISE SEA ICE MODEL (CURRENTLY UNDER CONSTRUCTION)
     CONFIGDESCRIPTION[DC]="D-CASE COLUMN TEST OF SEA ICE MODEL" 
     COMPSET[DC]=""
     RESOLUTION[DC]=""
     PELAYOUT[DC]=""
     MAXCOMBINATIONS[DC]=0

     # D-CASE WC14 MESH
     CONFIGDESCRIPTION[DWC14]="D-CASE ON WC14 MESH WITH JRA 1.5 FORCING" 
     COMPSET[DWC14]="2000_DATM%JRA-1p5_SLND_MPASSI_DOCN%SOM_DROF%JRA-1p5_SGLC_SWAV_TEST"
     RESOLUTION[DWC14]="TL319_WC14to60E2r3"
     PELAYOUT[DWC14]="S"
     MAXCOMBINATIONS[DWC14]=8

     # D-CASE SORRM MESH WITH ICE SHELVES 
     CONFIGDESCRIPTION[DSORRM]="D-CASE ON SORRM MESH WITH JRA 1.5 FORCING" 
     COMPSET[DSORRM]="2000_DATM%JRA-1p5_SLND_MPASSI_DOCN%SOM_DROF%JRA-1p5_SGLC_SWAV_TEST"
     RESOLUTION[DSORRM]="TL319_SOwISC12to60E2r4"
     PELAYOUT[DSORRM]="S"
     MAXCOMBINATIONS[DSORRM]=8

     # D-CASE WAVES (CURRENTLY UNDER CONSTRUCTION)
     CONFIGDESCRIPTION[DW]="D-CASE WITH WAVES ON STANDARD MESH WITH JRA 1.5 FORCING" 
     COMPSET[DW]="DTEST-JRA1p5-WW3"
     RESOLUTION[DW]="TL319_EC30to60E2r2_wQU225EC30to60E2r2"
     PELAYOUT[DW]="S"
     MAXCOMBINATIONS[DW]=0

     # D-CASE SEA ICE WITH BGC (CURRENTLY UNDER CONSTRUCTION)
     CONFIGDESCRIPTION[DBGC]="D-CASE WITH BGC ON STANDARD MESH WITH JRA 1.5 FORCING" 
     COMPSET[DBGC]="DTESTM-BGC"
     RESOLUTION[DBGC]="T62_EC30to60E2r2"
     PELAYOUT[DBGC]="S"
     MAXCOMBINATIONS[DBGC]=0


     # G-CASES ##########################################################

     # G-CASE ON STANDARD RESOLUTION 
     CONFIGDESCRIPTION[G]="G-CASE AT STANDARD RESOLUTION WITH JRA 1.5 FORCING" 
     COMPSET[G]="GMPAS-JRA1p5"
     RESOLUTION[G]="TL319_EC30to60E2r2"
     PELAYOUT[G]="L"
     MAXCOMBINATIONS[G]=8

     # G-CASE WC14 MESH WITH JRA1p4
     CONFIGDESCRIPTION[GWC14]="G-CASE ON WC14 MESH WITH JRA 1.5 FORCING" 
     COMPSET[GWC14]="GMPAS-JRA1p5" # (or GMPAS-JRA1p5)
     RESOLUTION[GWC14]="TL319_WC14to60E2r3"
     PELAYOUT[GWC14]="" 
     MAXCOMBINATIONS[GWC14]=0

     # G-CASE SORRM MESH WITH JRA1p4
     CONFIGDESCRIPTION[GSORRM]="G-CASE ON SORRM MESH WITH JRA 1.5 FORCING" 
     COMPSET[GSORRM]="GMPAS-JRA1p5-DIB-ISMF"
     RESOLUTION[GSORRM]="TL319_SOwISC12to60E2r4"
     PELAYOUT[GSORRM]="S"
     MAXCOMBINATIONS[GSORRM]=4

     # G-CASE STANDARD RESOLUTION WITH WAVES (UNDER CONSTRUCTION)
     CONFIGDESCRIPTION[GW]="G-CASE WITH WAVES ON STANDARD MESH WITH JRA 1.5 FORCING" 
     COMPSET[GW]="GMPAS-JRA1p5-WW3"
     RESOLUTION[GW]="TL319_EC30to60E2r2_wQU225EC30to60E2r2"
     PELAYOUT[GW]="L"
     MAXCOMBINATIONS[GW]=0

     # G-CASE WITH BGC 
     CONFIGDESCRIPTION[GBGC]="G-CASE WITH BGC ON STANDARD MESH WITH JRA 1.5 FORCING" 
     COMPSET[GBGC]="GMPAS-JRA1p5"
     RESOLUTION[GBGC]="TL319_EC30to60E2r2"
     PELAYOUT[GBGC]="L"
     MAXCOMBINATIONS[GBGC]=4


     # B-CASES ##########################################################

     # B-CASE STANDARD RESOLUTION
     CONFIGDESCRIPTION[B]="B-CASE ON STANDARD MESH" 
     COMPSET[B]="WCYCL1850"
     RESOLUTION[B]="ne30pg2_EC30to60E2r2"
     PELAYOUT[B]="L"
     MAXCOMBINATIONS[B]=2

     # B-CASE WITH WC14 MESH
     CONFIGDESCRIPTION[BWC14]="B-CASE WITH STANDARD RESOLUTION ATM/LND AND WC14 OCN/ICE" 
     COMPSET[BWC14]="WCYCL1850"
     RESOLUTION[BWC14]="ne30pg2_WC14to60E2r3"
     if [ "${MACHINES[${MACH}],,}" == "chrysalis" ]; then
      PELAYOUT[BWC14]="M"
      MAXCOMBINATIONS[BWC14]=2
     else
      MAXCOMBINATIONS[BWC14]=0
     fi

     # B-CASE NARRM CONFIGURATION (UNDER CONSTRUCTION)
     CONFIGDESCRIPTION[BNARRM]="B-CASE NORTH AMERICAN REGIONALLY REFINED MODEL" 
     COMPSET[BNARRM]="WCYCL1850"
     RESOLUTION[BNARRM]="northamericax4v1pg2_WC14to60E2r3"
     if [ "${MACHINES[${MACH}],,}" == "chrysalis" ]; then
      PELAYOUT[BNARRM]="M"
      MAXCOMBINATIONS[BNARRM]=2
     else
      MAXCOMBINATIONS[BNARRM]=0
     fi

     # B-CASE SORRM WITH STANDARD RESOLUTION ATMOSPHERE
     CONFIGDESCRIPTION[BSORRM]="B-CASE WITH ICE SHELVES AND REFINED SOUTHERN OCEAN" 
     COMPSET[BSORRM]="CRYO1850"
     RESOLUTION[BSORRM]="ne30pg2_SOwISC12to60E2r4"
     if [ "${MACHINES[${MACH}],,}" == "chrysalis" ]; then
      PELAYOUT[BSORRM]="M"
      MAXCOMBINATIONS[BSORRM]=2
     else
      PELAYOUT[BSORRM]="L"
      MAXCOMBINATIONS[BSORRM]=2
     fi

     # B-CASE STANDARD RESOLUTION WITH WAVES
     CONFIGDESCRIPTION[BW]="B-CASE WITH WAVES AT STANDARD RESOLUTION" 
     COMPSET[BW]="WCYCL1850-WW3"
     RESOLUTION[BW]="ne30pg2_EC30to60E2r2_wQU225EC30to60E2r2"
     PELAYOUT[BW]="L"
     MAXCOMBINATIONS[BW]=0

     # B-CASE STANDARD RESOLUTION WITH BGC 
     CONFIGDESCRIPTION[BBGC]="B-CASE WITH BGC AT STANDARD RESOLUTION" 
     COMPSET[BBGC]="BGCEXP_CNTL_CNPECACNT_1850"
     RESOLUTION[BBGC]="ne30pg2_r05_EC30to60E2r2"
     PELAYOUT[BBGC]="L"
     MAXCOMBINATIONS[BBGC]=2

     #
     ####################################################################

     # print entire configuration options of -c is specified without an argument
     if [ -z $CONFIG ]; then

      # sort keys alphabetically
      local sortedkey=($(echo ${!MAXCOMBINATIONS[@]}| tr " " "\n" | sort -n))

      printf "\n--- Available ${MACHINES[${MACH}]} configs "
      printf "(compset, res, layout, max namelist combos):\n"
      for key in "${sortedkey[@]}"; do 
       if [[ ${MAXCOMBINATIONS[$key]} > 0 ]]; then
        if [[ ${DEFAULT_CONFIG} == ${key} ]]; then
         printf "\n    $key => \t\e[1;34mDEFAULT\e[0m ${CONFIGDESCRIPTION[$key]}\n"
        else
         printf "\n    $key => \t${CONFIGDESCRIPTION[$key]}\n"
        fi
        printf '\t%s' "        ${COMPSET[$key]}, " 
        printf "\n            \t${RESOLUTION[$key]}, "
        printf "${PELAYOUT[$key]}, "; 
        printf "${MAXCOMBINATIONS[$key]}\n"; 
       fi
      done

      printf "\n--- Draft configs not yet available on ${MACHINES[${MACH}]}:\n"
      for key in "${!MAXCOMBINATIONS[@]}"; do 
       if [[ ${MAXCOMBINATIONS[$key]} == 0 ]]; then
        printf "\n    $key => \t${CONFIGDESCRIPTION[$key]}"
       fi
      done 
      echo $'\n'
      exit

     # otherwise just provide configuration options
     else
      printf "\n--- \x1B[34m${CONFIGDESCRIPTION[$CONFIG]}\e[0m\n" 
      printf '%s' "    ${COMPSET[$CONFIG]}, " 
      printf "\n    ${RESOLUTION[$CONFIG]}, "
      printf "${PELAYOUT[$CONFIG]} layout, "; 
      printf "${MAXCOMBINATIONS[$CONFIG]} combos\n"; 

     fi

     readonly HOURS=$(((DURATION+2-1)/2)) # walltime is min(ceil(months/2),12) hours
     printf -v WALLTIME "%2.2i:00:00" $((HOURS<12 ? HOURS : 12))

     readonly STOP_OPTION="nmonths"
     readonly STOP_N="$((DURATION<12 ? DURATION : 12))"
     readonly REST_OPTION="${STOP_OPTION}"
     readonly REST_N="${STOP_N}"
     readonly HIST_OPTION="${STOP_OPTION}"
     readonly HIST_N="${STOP_N}"
     readonly RESUBMIT="$(((DURATION+12-1)/12-1))"
     readonly DO_SHORT_TERM_ARCHIVING=false

    fi

    # process namefile and prepare for the casename
    if [ "${do_case_kombo,,}" == "true" ]; then
     if [[ "${NAMEFILE}" =~ "_nlk_mpassi" ]]; then
      readonly KOMBOTAG=`echo ${NAMEFILE} | cut -d _ -f 1`
     else
      printf "\n--- ERROR: Specify a <kombotag>_nlk_mpassi namelist file with -k\n\n"
     fi
    fi

    # set case name
    local CASE_MODIFIER="${CONFIG}${DURATION}${TEST}"
    [ "${do_case_kombo,,}" == "true" ] && CASE_MODIFIER="${CASE_MODIFIER}.${KOMBOTAG}"
    [ "${do_energy_mass,,}" == "true" ] && CASE_MODIFIER="${CASE_MODIFIER}.emc"
    readonly CASE_NAME="${CASE_MODIFIER}.${SANDBOX}.${MACHINES[${MACH}]}"

    # case directories
    readonly CODE_ROOT="${CODE_BASE}/${SANDBOX}"
    readonly CASE_ROOT="${CASE_BASE}/${CASE_NAME}"
    readonly CASE_BUILD_DIR=${CASE_ROOT}/build
    readonly CASE_ARCHIVE_DIR=${CASE_ROOT}/archive
    readonly CASE_SCRIPTS_DIR=${CASE_ROOT}/case_scripts
    readonly CASE_RUN_DIR=${CASE_ROOT}/run


    # check that the cloned code has same fork as ${FORK} and uses ${BRANCH}
    # and post warning if not. This situation could arise if the code has
    # aleady been cloned from a different fork and branch than the default
    # or from the original specification when -f was last used.  The value
    # of FORK and BRANCH is reset accordingly so that the provenance records
    # the correct code being used in the sandbox.

    if [ "${do_code_clone,,}" != "true" ] && [ -d ${CODE_ROOT} ] ; then 
     pushd ${CODE_ROOT} 

     # check origin url
     local checkurl=($(git config --get remote.origin.url))
     if [[ ! "${checkurl}" == "${FORK}" ]]; then
      printf "\n--- Fork origin different from default ${FORK}"
      printf "\n    Sandbox origin is: \x1B[34m${checkurl}\e[0m\n"
      FORK=${checkurl}        
     fi

     # check local branch
     local checkbranch=($(git rev-parse --abbrev-ref HEAD))
     if [[ ! "${checkbranch}" == "${BRANCH}" ]]; then
      printf "\n--- Branch being used not default ${BRANCH}"
      printf "\n    Current branch is: \x1B[34m${checkbranch}\e[0m\n"
      BRANCH=${checkbranch}
     fi

     popd
    fi

    # analysis checks and assignments
    if [ "${do_case_analyze,,}" == "true" ]  ; then
     if [ ! -z ${CASE2_NAME} ] && [ "${CASE2_NAME}" != "${CASE_NAME}" ] ; then
      readonly CASE2_ROOT="${CASE_BASE}/${CASE2_NAME}"
      if [ ! -d ${CASE2_ROOT} ]; then
       printf "\n--- ANALYSIS ERROR: ${CASE2_NAME} does not exist\n\n" 
       exit 
      fi
     elif [ "${CASE2_NAME}" == "${CASE_NAME}" ] && (( combinations == 1 )); then
      printf "\n--- ERROR: The comparison case and -s sandbox case are identical ---\n\n" 
      exit 
     elif [ -z ${CASE2_NAME} ] && (( combinations == 1 )); then 
      printf "\n--- ERROR: No comparison case given with -a. Use -h for help ---\n\n" 
      exit 
     else
      readonly CASE2_ROOT=""
     fi
    fi

}

#---------------------------------
copy_script() {

    local THIS_SCRIPT_NAME=`basename $0`
    local THIS_SCRIPT_DIR=`dirname $0`
    readonly SCRIPT_PROVENANCE_NAME=${THIS_SCRIPT_NAME}.`date +%Y%m%d-%H%M%S`
    local SCRIPT_PROVENANCE_BASE="${HOME}/${CASE_GROUP}/provenance"
    readonly SCRIPT_PROVENANCE_DIR="${SCRIPT_PROVENANCE_BASE}/${SANDBOX}/${CASE_NAME}"

    if [ ! -d ${SCRIPT_PROVENANCE_DIR} ]; then
     mkdir -p ${SCRIPT_PROVENANCE_DIR}
    fi

    # improve readability of provenance
    if [ "${do_energy_mass,,}" == "true" ]; then
      local energy_mass_conservation="ON"
    else
      local energy_mass_conservation="OFF"
    fi

    cat << EOF > ${SCRIPT_PROVENANCE_DIR}/${SCRIPT_PROVENANCE_NAME}
#!${SHELL}
#######################################################################
#
# Specifications for ${SCRIPT_PROVENANCE_NAME}
#
# ${THIS_SCRIPT_DIR}/${THIS_SCRIPT_NAME}
#
# Command:    ${THIS_SCRIPT_NAME} $*
# Origin:     ${FORK}
# Branch:     ${BRANCH}
# Sandbox:    ${CODE_ROOT}
# Case:	      ${CASE_NAME}
# Casedir:    ${CASE_ROOT}
#
# Start Type: ${MODEL_START_TYPE}
# Start Date: ${START_DATE}
# Simulation: ${CONFIGDESCRIPTION[$CONFIG]}
# Compset:    ${COMPSET[$CONFIG]} 
# Resolution: ${RESOLUTION[$CONFIG]}
# PE Layout:  ${PELAYOUT[$CONFIG]}
# Walltime:   ${WALLTIME}
# Duration:   ${STOP_N} months
# Resubmit:   ${RESUBMIT} count
# Machine:    ${MACHINES[${MACH}]}
#
# Conservation checking is ${energy_mass_conservation}
#
#######################################################################
EOF

    # add additional information if namelist combinations are included
    if [ "${do_case_kombo,,}" == "true" ] & [ -f "${NAMEFILE}" ]; then
     echo "# " >> ${SCRIPT_PROVENANCE_DIR}/${SCRIPT_PROVENANCE_NAME}
     echo "# Sea ice namelist combinations summary for ${NAMEFILE}:" >> \
             ${SCRIPT_PROVENANCE_DIR}/${SCRIPT_PROVENANCE_NAME}
     echo "# " >> ${SCRIPT_PROVENANCE_DIR}/${SCRIPT_PROVENANCE_NAME}
     while IFS= read -r line; do
      nmline=`echo "$line" | cut -d = -f 1 | rev | cut -c 2- | rev`
      if [ ! -z $nmline ]; then # remove blank lines
       echo "# ${line}" >> ${SCRIPT_PROVENANCE_DIR}/${SCRIPT_PROVENANCE_NAME}
      fi
     done < "$NAMEFILE"
     echo "# " >> ${SCRIPT_PROVENANCE_DIR}/${SCRIPT_PROVENANCE_NAME}
     echo "#######################################################################" >> \
           ${SCRIPT_PROVENANCE_DIR}/${SCRIPT_PROVENANCE_NAME}
    fi

    # add entire script beneath this
    cat ${THIS_SCRIPT_DIR}/${THIS_SCRIPT_NAME} | sed '1d' >> \
        ${SCRIPT_PROVENANCE_DIR}/${SCRIPT_PROVENANCE_NAME} 

    # provide an ASCII call tree in the base provenance directory
    pushd ${SCRIPT_PROVENANCE_BASE}
    find . -print | sed -e 's;/*/;|;g;s;|; |;g' >| "`echo ${THIS_SCRIPT_NAME} | cut -f 1 -d .`"
    popd

}

#---------------------------------
clone_code() {

    if [ "${do_code_clone,,}" != "true" ]; then
        echo $'\n--- Skipping clone of code ---'
        return
    elif [ -e ${CODE_ROOT} ]; then
        while true; do
         read -p $'\n--- Sandbox already exists. Overwrite (Y/N)?' yn
         case $yn in
          [Yy]* ) local stop_clone=false; break;;
          [Nn]* ) local stop_clone=true; break;;
          * ) echo "Please answer yes or no.";;
         esac
        done

        if [ "${stop_clone,,}" == "true" ]; then
         echo $'\n--- Keeping existing clone ---\n'
         exit 
        else
         rm -rf ${CODE_ROOT}
        fi
    fi

    echo $'\n--- Cloning code ---'

    echo $'\n---' "Fork: ${FORK}"

    echo $'\n---' "Branch: ${BRANCH}"

    echo $'\n'

    mkdir -p ${CODE_ROOT}

    pushd ${CODE_ROOT}

    # This will put repository, with all code
    git clone ${FORK} . 
    
    # Check out desired branch
    git checkout ${BRANCH}

    # Bring in all submodule components
    git submodule update --init --recursive

    popd
}

#---------------------------------
namelist_kombo() {

    # initialize 2D arrays of all the namelist options to be read in and
    # and the final namelists to be constructed and made globally available. 

    declare -A option
    declare -gA namelist

    if [ "${do_case_kombo,,}" != "true" ]; then
        printf "\n--- Skipping namelist combinations ---\n"
        combinations=1
        komboname[0]="k000"
        return
    elif [ -f "${CASE_ROOT}/${NAMEFILE}" ] ; then
        printf "\n--- Reading namelist combinations from ${CASE_NAME}/${NAMEFILE}\n"
        NAMEFILE="${CASE_ROOT}/${NAMEFILE}"
    elif [ ! -f "${NAMEFILE}" ]; then
        printf "\n--- ERROR: '${NAMEFILE}' not in $(cd `pwd` && dirs +0)\n\n"
        exit
    else
        printf "\n--- Reading namelist combinations from ${NAMEFILE}\n"
    fi


    # read in the namelist combinations from the file. These must appear in the 
    # format of one line for one namelist option, with comma-seperated values
    # to be tested, surrounded by brackets, as in this example:
    #
    # NAMELIST_ENTRY1 = {false,true}
    # NAMELIST_ENTRY2 = {'string1','string2','string3'}
    # NAMELIST_ENTRY3 = {number1,number2}
    #
    # Note that a single namelist entry can be provided, e.g.:
    #
    # NAMELIST_ENTRY4 = 'evp'
    #
    # The namelist combinations file is read in line-by-line. Blank lines are 
    # discarded. Three main things are recorded: 1) namechangenumber, which is 
    # the total number of namelist entries to change; 2) numberofoptions, which
    # is the total number of comma-separated entries to be tested for a given
    # namelist options, and; 3) the list of options in an array with dimensions
    # option[namechangenumber,numberofoptions].

    local i=0
    while IFS= read -r line; do
     namechange[$i]=`echo "$line" | cut -d = -f 1 | rev | cut -c 2- | rev`  
     if [ ! -z ${namechange[$i]} ]; then # remove blank lines
      case $line in 
         *"{"*) # where brackets are provided, multiple options provided
           options=`echo "$line" | cut -d { -f 2 | cut -d } -f 1`
           commas=${options//[^,]}
           ((numberofoptions[$i]=${#commas}+1))
           for ((j=0;j<${numberofoptions[$i]};j++)); do
            ((jj=j+1))
            option[$i,$j]="${namechange[$i]} = `echo ${options} | cut -d , -f $jj`"
           done
           ;;
         *) # where only one option is provided
           numberofoptions[$i]=1
           option[$i,0]=${line}
           ;;
      esac
      ((i=i+1))
     fi
    done < "$NAMEFILE"
    namechangenumber=$i

    # now calculate the total number of combinations based on the nuber of
    # options to be tested, and limit according the case type.  

    combinations=1
    for ((m=0;m<${namechangenumber};m++)); do
     index[m]=0
     combinations=$((${combinations}*${numberofoptions[m]}));
    done
    if (( combinations > ${MAXCOMBINATIONS[$CONFIG]} )) ; then
     echo $'\n--- ERROR: Permutations exceed maximum for config:' "${MAXCOMBINATIONS}"
     echo $'\n'
     exit
    fi

    # now construct the individual namelists to be used for each combination
    # and write them to an output array, namelist[combinations,namechangenumber]
    # with the combination labels in komboname[combinations]

    for ((i=0;i<${combinations};i++)); do
     printf -v komboname[${i}] "k%3.3i" ${i}
     printf $'\n'"    \x1B[34m${komboname[${i}]}\e[0m ->\n" 
     for ((m=$((${namechangenumber}-1));m>=0;m--)); do
      namelist[${i},${m}]=${option[${m},${index[${m}]}]}
      echo "    ${namelist[${i},${m}]}"
      if [ $m == $((${namechangenumber}-1)) ]; then
       ((index[m]=${index[m]}+1)) 
      elif [ ${index[m+1]} == ${numberofoptions[m+1]} ]; then
       ((index[m]=${index[m]}+1))       
       index[m+1]=0
      fi
      if [[ $i < $((${combinations}-1)) ]] && [[ ${index[0]} == ${numberofoptions[0]} ]] 
      then 
       echo $'\n---- INTERNAL ERROR: Permutations incorrect:' "$i $((${combinations}-1))"
       exit
      fi
     done
    done

}

#---------------------------------
create_newcase() {

    if [ "${do_case_create,,}" != "true" ]; then
        echo $'\n--- Skipping create newcase ---'
        return
    elif [ ! -d ${CODE_ROOT} ]; then
        echo $'\n--- No code sandbox from which to create a new case ---\n'
        exit
    elif [ -e ${CASE_ROOT} ]; then
        while true; do
         read -p $'\n--- Case root already exists. Overwrite (Y/N)?' yn
         case $yn in
          [Yy]* ) local stop_script=false; break;;
          [Nn]* ) local stop_script=true; break;;
          * ) echo "Please answer yes or no.";;
         esac
        done
        if [ "${stop_script,,}" == "true" ]; then
         echo $'\n--- Stopping the script ---\n'
         exit
        else
         rm -rf ${CASE_ROOT}
        fi
    fi

    echo $'\n--- Starting to create a new case ---'
    echo $'\n'

    for ((i=0;i<${combinations};i++)); do

      ${CODE_ROOT}/cime/scripts/create_newcase \
        --case ${CASE_NAME} \
        --case-group ${CASE_GROUP} \
        --output-root ${CASE_ROOT} \
        --script-root "${CASE_SCRIPTS_DIR}.${komboname[${i}]}" \
        --handle-preexisting-dirs u \
        --compset "${COMPSET[$CONFIG]}" \
        --res "${RESOLUTION[$CONFIG]}" \
        --machine "${MACHINES[${MACH}]}" \
        --project "${PROJECTS[${MACH}]}" \
        --walltime ${WALLTIME} \
        --pecount "${PELAYOUT[$CONFIG]}"

      if [ $? != 0 ]; then
       echo $'\n If create new case failed because sub-directory already exists:'
       echo $'  * delete old case_script sub-directory'
       echo $'  * or set do_newcase=false\n'
       exit
      fi

    done

    if [ "${do_case_kombo,,}" == "true" ]; then
     cp ${NAMEFILE} ${CASE_ROOT}
     chmod 644 ${CASE_ROOT}/${NAMEFILE}
    fi

}

#---------------------------------
case_build() {

    for ((i=0;i<${combinations};i++)); do

     if [ -d ${CASE_SCRIPTS_DIR}.${komboname[${i}]} ]; then
      pushd ${CASE_SCRIPTS_DIR}.${komboname[${i}]}
     else
      echo $'\n--- Case does not exist to build ---'
      return
     fi

     # do_case_build = false
     if [ "${do_case_build,,}" != "true" ]; then

      # Use previously built executable, make sure it exists
      if [ ! -x ${CASE_BUILD_DIR}/e3sm.exe ]; then
       if [ $i == 0 ]; then
        if [ "${do_case_queue,,}" == "true" ]; then
         do_case_queue=false
         exit_script=true
         echo $'\n---' "No executable yet for ${SANDBOX}, queue cancelled ---" 
        else
         echo $'\n---' "No executable yet for ${SANDBOX}. See -h for help ---" 
        fi
       fi
      else
        ./xmlchange BUILD_COMPLETE=TRUE > /dev/null
        echo $'\n--- Skipping build for' "${komboname[${i}]}" 
      fi

     # do_case_build = true
     elif [ "${do_case_build,,}" == "true" ]; then

      printf "\n--- Building ${komboname[${i}]} ---\n\n"

      # Setup some CIME directories
      ./xmlchange EXEROOT=${CASE_BUILD_DIR} > /dev/null
      ./xmlchange RUNDIR="${CASE_RUN_DIR}.${komboname[${i}]}" > /dev/null

      # Short term archiving
      ./xmlchange DOUT_S=${DO_SHORT_TERM_ARCHIVING^^}
      ./xmlchange DOUT_S_ROOT="${CASE_ARCHIVE_DIR}.${komboname[${i}]}"

      # Build with COSP, except for a data atmosphere (datm)
      if [ `./xmlquery --value COMP_ATM` != "datm"  ]; then 
       echo $'\nConfiguring E3SM to use the COSP simulator\n'
       ./xmlchange --id CAM_CONFIG_OPTS --append --val='-cosp'
      fi

      # Extracts input_data_dir in case it is needed for user edits to the namelist later
      local input_data_dir=`./xmlquery DIN_LOC_ROOT --value`

      # clear namelist alterations
      if compgen -G "user_nl_mpassi" > /dev/null; then
       rm user_nl_mpassi
      fi
      if compgen -G "user_nl_mpaso" > /dev/null; then
       rm user_nl_mpaso
      fi

      # Finally, run CIME case.setup
      ./case.setup --reset

      # Switch on conservation analysis members if -e option given
      if [ "${do_energy_mass,,}" == "true" ]; then
       echo $'\n--- Setting up mass and energy conservation analysis ---\n'
       if [ -f "user_nl_mpaso" ]; then
        echo "config_am_conservationcheck_enable = true" >> user_nl_mpaso
       fi
       if [ -f "user_nl_mpassi" ]; then
        echo "config_am_conservationcheck_enable = true" >> user_nl_mpassi
       fi
      fi

      # If specifying namelist settings, add them to user_nl_mpassi here
      if [ "${do_case_kombo,,}" == "true" ]; then
       for ((m=0;m<${namechangenumber};m++)); do
        echo ${namelist[${i},${m}]} >> user_nl_mpassi
       done
      fi

      # Turn on debug compilation option if requested
      if [ "${DEBUG_COMPILE^^}" == "TRUE" ]; then
        ./xmlchange DEBUG=${DEBUG_COMPILE^^}
      fi

      # Remove any existing output files so they aren't erroneously used
      pushd ${CASE_RUN_DIR}.${komboname[${i}]}
      for x in `ls ${CASE_RUN_DIR}.${komboname[${i}]}`; do
       if [[ ${x} =~ ${CASE_NAME} ]]; then
        rm ${x}
       fi
      done
      popd

      # Run CIME case.build, which only needs to be done for the first combination
      if [ ${i} == 0 ]; then
       ./case.build
      fi

      # Call preview_namelists to make sure *_in and user_nl files are consistent.
      ./preview_namelists

     else

      echo '--- INTERNAL ERROR: Build option nondescript'
      exit 

     fi

     popd

    done

}

#---------------------------------
case_queue() {

    for ((i=0;i<${combinations};i++)); do

     if [ ! -d "${CASE_SCRIPTS_DIR}.${komboname[${i}]}" ]; then

      echo $'\n--- Case does not exist to queue ---'

     elif [ "${do_case_queue,,}" != "true" ]; then

      echo $'\n--- Skipping queue for' "${komboname[${i}]}"

     else

      echo $'\n--- Starting queue for' "${komboname[${i}]}"
      pushd "${CASE_SCRIPTS_DIR}.${komboname[${i}]}"

      # Set simulation start date
      ./xmlchange RUN_STARTDATE=${START_DATE}

      # Segment length
      ./xmlchange STOP_OPTION=${STOP_OPTION,,},STOP_N=${STOP_N}

      # Restart frequency
      ./xmlchange REST_OPTION=${REST_OPTION,,},REST_N=${REST_N}

      # Coupler history
      ./xmlchange HIST_OPTION=${HIST_OPTION,,},HIST_N=${HIST_N}

      # Coupler budgets (always on)
      ./xmlchange BUDGETS=TRUE

      # Set resubmissions
      if (( RESUBMIT > 0 )); then
        ./xmlchange RESUBMIT=${RESUBMIT}
      fi

      # Run type
      # Start from default of user-specified initial conditions
      if [ "${MODEL_START_TYPE,,}" == "initial" ]; then
        ./xmlchange RUN_TYPE="startup"
        ./xmlchange CONTINUE_RUN="FALSE"
        if [ "${MACHINES[${MACH}],,}" == "chrysalis" ]; then
          ./xmlchange JOB_QUEUE="compute"
        fi

      # Continue existing run
      elif [ "${MODEL_START_TYPE,,}" == "continue" ]; then
        ./xmlchange CONTINUE_RUN="TRUE"

      elif [ "${MODEL_START_TYPE,,}" == "branch" ] || \
           [ "${MODEL_START_TYPE,,}" == "hybrid" ]; then

       ./xmlchange RUN_TYPE=${MODEL_START_TYPE,,}
       ./xmlchange GET_REFCASE=${GET_REFCASE}
       ./xmlchange RUN_REFDIR=${RUN_REFDIR}
       ./xmlchange RUN_REFCASE=${RUN_REFCASE}
       ./xmlchange RUN_REFDATE=${RUN_REFDATE}
       echo 'Warning: $MODEL_START_TYPE = '${MODEL_START_TYPE} 
       echo '$RUN_REFDIR = '${RUN_REFDIR}
       echo '$RUN_REFCASE = '${RUN_REFCASE}
       echo '$RUN_REFDATE = '${START_DATE}
 
      else
       echo '\n--- ERROR: '${MODEL_START_TYPE}' is unrecognized. Exiting.'
       exit
      fi

      # Run CIME case.submit
      ./case.submit

      popd

      if [ "${MACHINES[${MACH}],,}" == "chrysalis" ]; then
       squeue -u ${USER}
      elif [ "${MACHINES[${MACH}],,}" == "anvil" ]; then
       squeue -u ${USER}
      else
       echo '\n--- ERROR: No scripting setup for this machine ---'
       exit
      fi

     fi

    done
 
}

#---------------------------------
case_analyze() {

    if [ "${do_case_analyze,,}" != "true" ]; then
     echo $'\n--- Skipping analysis ---'
     return
    else
     # set up provenance
     echo $'\n--- Starting analysis ---'
     local pscript="${SCRIPT_PROVENANCE_DIR}/${SCRIPT_PROVENANCE_NAME}"
     echo ": '" >> ${pscript}
    fi

    pushd ${CASE_ROOT}

    # set fields and month to analyze
    local AVE_FREQ="Monthly"
    FIELDS+=( "iceAreaCell" "iceVolumeCell" "icePressure" "uVelocityGeo" "vVelocityGeo" )
    printf -v MONTH "%2.2i" $((DURATION<12 ? DURATION : 12))
    FILE_EXTE="mpassi.hist.am.timeSeriesStats${AVE_FREQ}.0001-${MONTH}-01.nc"

    # find all available combinations in cases for analysis
    if [ -z ${CASE2_ROOT} ]; then
     local casekombos=(${CASE_ROOT}/run.k*)
     local casescript=(${CASE_ROOT}/case_scripts.k*)
    else
     local casekombos=(${CASE_ROOT}/run.k* ${CASE2_ROOT}/run.k*)
     local casescript=(${CASE_ROOT}/case_scripts.k* ${CASE2_ROOT}/case_scripts.k*)
    fi 

    # check latest simulation run log being interrogated completed
    for ((i=0;i<${#casescript[@]};i++)); do
     pushd ${casescript[i]}
     local dirname=`dirname ${casescript[${i}]}`
     local casename=`basename ${dirname}`
     local komboname=`basename ${casescript[i]} | cut -d . -f 2`
     local runoutputs=(run.${casename}.*)
     if [[ ! -f ${runoutputs[-1]} ]]; then
      printf "\n    $casename $komboname: \t\x1B[31mNot run\e[0m" 
      printf "\n    $casename $komboname: \tNot run" >> "${pscript}"
     else
      for ((j=0;j<${#runoutputs[@]};j++)); do
       local lastline=`tail -1 ${runoutputs[j]}`
       if [[ ${lastline} =~ "CASE.RUN HAS FINISHED" ]]; then
        printf "\n    ${runoutputs[j]} $komboname: \t\x1B[32mComplete\e[0m" 
        printf "\n    ${runoutputs[j]} $komboname: \tComplete" >> "${pscript}"
       else
        printf "\n    ${runoutputs[j]} $komboname: \t\x1B[31mIncomplete\e[0m"
        printf "\n    ${runoutputs[j]} $komboname: \tIncomplete" >> "${pscript}"
       fi
      done
     fi
     popd
     printf "\n" | tee -a "${pscript}"
    done

    # check to make sure there are two simulations to compare
    if [[ ${#casekombos[@]} < 2 ]]; then
     printf "\n--- Need two cases to compare\n\n"
     echo "'" >> ${pscript}
     exit
    fi

    # check to make sure the necessary files exist
    for ((i=0;i<${#casekombos[@]};i++)); do
     dirnames[i]=`dirname ${casekombos[${i}]}`
     casenames[i]=`basename ${dirnames[${i}]}`
     if [ ! -d ${casekombos[${i}]} ]; then
      printf "\n--- Missing run directory for ${casenames[i]} \n\n"
      #echo "'" >> ${pscript}
      #exit
     else
      kombonames[i]="${casenames[i]} `basename ${casekombos[${i}]} | cut -d . -f 2`"
      if [ ! -f ${casekombos[i]}/${casenames[i]}.${FILE_EXTE} ]; then
       printf "\n--- Missing ${FILE_EXTE}\n"
       printf "    for ${kombonames[i]}\n"
      fi
     fi
    done

    # cycle through cases and compare them, output to screen and provenance 
    source /lcrc/soft/climate/e3sm-unified/load_latest_e3sm_unified_${MACHINES[${MACH}]}.sh

    printf "\n--- ${AVE_FREQ} min/max diff:\n" | tee -a "${pscript}"

    for ((i=0;i<${#casekombos[@]};i++)); do
     for ((j=i+1;j<${#casekombos[@]};j++)); do

      textoutput="${kombonames[i]} - ${kombonames[j]}"
      printf "\n    \x1B[34m${textoutput}\e[0m:\n\n" 
      printf "\n    ${textoutput}:\n\n" >> "${pscript}"

      if [ -f ${casekombos[i]}/${casenames[i]}.${FILE_EXTE} ] && \
         [ -f ${casekombos[j]}/${casenames[j]}.${FILE_EXTE} ]; then

       # overall flag indicating if for all tested variables the test is BFB
       local bfbflag=true

       for ((k=0;k<${#FIELDS[@]};k++)); do

        ncdiff -O -v time${AVE_FREQ}_avg_${FIELDS[k]} \
                     ${casekombos[i]}/${casenames[i]}.${FILE_EXTE} \
                     ${casekombos[j]}/${casenames[j]}.${FILE_EXTE} \
                     ${casekombos[i]}/${casenames[i]}.${casenames[j]}.diff.nc

        ncwa -O -y min ${casekombos[i]}/${casenames[i]}.${casenames[j]}.diff.nc \
                      ${casekombos[i]}/${casenames[i]}.${casenames[j]}.min.nc

        ncwa -O -y max ${casekombos[i]}/${casenames[i]}.${casenames[j]}.diff.nc \
                      ${casekombos[i]}/${casenames[i]}.${casenames[j]}.max.nc

        MINDIFF[k]=`ncdump -v time${AVE_FREQ}_avg_${FIELDS[k]} \\
               ${casekombos[i]}/${casenames[i]}.${casenames[j]}.min.nc | tail -2 | \\
               grep -Eo '[+-]?[0-9]+([.][0-9]+)?'`

        MAXDIFF[k]=`ncdump -v time${AVE_FREQ}_avg_${FIELDS[k]} \\
               ${casekombos[i]}/${casenames[i]}.${casenames[j]}.max.nc | tail -2 | \\
               grep -Eo '[+-]?[0-9]+([.][0-9]+)?'`

        if (( $(echo "${MINDIFF[k]} != 0" | bc -l) )) &&
           (( $(echo "${MAXDIFF[k]} != 0" | bc -l) )) ; then
         bfbflag=false
         printf "    ${FIELDS[k]}: \t${MINDIFF[k]} \t${MAXDIFF[k]}\n" | tee -a "${pscript}"
        else
         printf "    ${FIELDS[k]}: \t\x1B[32mBFB\e[0m\n" 
         printf "    ${FIELDS[k]}: \tBFB\n" >> "${pscript}"
        fi

       done

      else
  
       printf "    \x1B[31mUnavailable\e[0m\n" 
       printf "    Unavailable\n" >> "${pscript}"

      fi

     done
    done

    echo "'" >> ${pscript}

    popd

}

#---------------------------------
# Silent versions of popd and pushd
pushd() {
    command pushd "$@" > /dev/null
}
popd() {
    command popd "$@" > /dev/null
}

# Run the script
#---------------------------------
main $* 

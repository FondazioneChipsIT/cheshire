# Copyright 2025 ETH Zurich and University of Bologna.
# Proprietary, not for release

set faultsim_tb $::env(FAULTSIM_TB)
set num_fault_sim $::env(NUM_FAULT_SIM)
set bootmode $::env(BOOTMODE)
set prelmode $::env(PRELMODE)
set binary   $::env(BINARY)


# Configure grid -> To figure out with IT...
set_config -global_max_jobs 12
# set_submit_cmd -grid_type TODO
# set_config -max_faults_per_fsim_task 50

# Create fault campaign (Build fault universe through VC FCC)
create_campaign -localhost -args "-full64 -daidir simv.daidir -dut ${faultsim_tb}.fix.dut.gen_cva6_cores[0].i_core_cva6 -sff states.sff -sff ${faultsim_tb}.sff -campaign fc1 -sample num:${num_fault_sim} -overwrite"
#create_campaign -localhost -args "-full64 -daidir $simv.daidir -sff states.sff -sff ${faultsim_tb}.sff -campaign fc1 -sample num:${num_fault_sim} -overwrite"
# Create testcases
create_testcases -name {test1} -exec simv -daidir simv.daidir -campaign fc1 -args "-no_save +BOOTMODE=\"$bootmode\" +PRELMODE=\"$prelmode\" +BINARY=\"$binary\""

# dump -fids {1} -tc test1 -mode gmfm -fsdb gmfmdump.fsdb -args "+fsdb+all=on"
# dump -fids {1} -tc test1 -mode fm -fsdb fmdump.fsdb -args "+fsdb+all=on"

set_config -fsdb_outdated_behavior 0

#fcm::show_faults

# Run fault simulation campaign
fsim -fsim_args "-no_save" -localhost -selected_status {NA}

set output [string trim [show_fault_results -status {"HA"}]]

if {$output ne "No fault results found."} {
    set_config -fsim_mode serial
    fsim -fsim_args "-no_save" -localhost -selected_status {HA}
}

# Reporting after fault simulation
report -campaign fc1

# Dump waves for all failing testcases
set failing_cases {}
#lappend failing_cases [show_fault_results -status {FE}]

# Initialize list of FIDs
set fid_list {}

# Process output line by line
foreach state $failing_cases {
    foreach line [split $state "\n"] {
        # Trim leading/trailing spaces
        set line [string trim $line]

        # Skip header or empty lines
        if {[regexp {^#} $line] || $line eq "" || [regexp {^\-} $line]} {
            continue
        }

        # Check if the line starts with a number (FID)
        if {[regexp {^([0-9]+)} $line match fid]} {
            # Save the FID
            lappend fid_list $fid
        }
    }
}

#dump -fids $fid_list -tc test1 -mode gmfm -fsdb gmfmdump_all.fsdb -args "+fsdb+all=on"
#dump -fids $fid_list -tc test1 -mode fm -fsdb fmdump_all.fsdb -args "+fsdb+all=on"

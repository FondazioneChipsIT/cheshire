# Copyright 2020-2022 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
source $::env(SCRIPTS_DIR)/openroad/common/resizer.tcl

read_current_odb

set_dont_touch_objects

set ::insts [$::block getInsts]

set placement_needed 0

foreach inst $::insts {
	if { ![$inst isFixed] } {
		set placement_needed 1
		break
	}
}

if { !$placement_needed } {
	puts "\[INFO\] All instances are FIXED/FIRM."
	puts "\[INFO\] No need to perform global placement."
	puts "\[INFO\] Skipping…"
	write_views
	exit_unless_gui
}

source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl

set GPL_ARGS {  -routability_driven
                -routability_check_overflow 0.40
                -routability_inflation_ratio_coef 1.2
                -routability_max_inflation_ratio 1.2
                -max_phi_coef 1.04 }

lappend GPL_ARGS -density [expr $::env(PL_TARGET_DENSITY_PCT) / 100.0]

set GPL2_ARGS { -routability_driven
                -routability_inflation_ratio_coef 1.2
                -routability_max_inflation_ratio 1.2
                -max_phi_coef 1.02 }

lappend GPL2_ARGS -density [expr $::env(PL_TARGET_DENSITY_PCT) / 100.0]

lappend GPL2_ARGS -routability_check_overflow $::env(PL_ROUTABILITY_OVERFLOW_THRESHOLD)

if { [info exists ::env(PL_TIMING_DRIVEN)] && $::env(PL_TIMING_DRIVEN) } {
	lappend GPL2_ARGS -timing_driven
}

# set_thread_count 16

#log_cmd remove_buffers

#log_cmd global_placement {*}$GPL_ARGS
#estimate_parasitics -placement
#log_cmd buffer_ports
#log_cmd repair_design -verbose

# log_cmd repair_timing -setup -verbose -skip_pin_swap -repair_tns 50 -max_iterations 500

log_cmd global_placement {*}$GPL2_ARGS

unset_dont_touch_objects

source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
estimate_parasitics -placement

write_views

report_design_area_metrics


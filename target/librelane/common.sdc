if {![info exists PRE_SYNTHESIS]} {set PRE_SYNTHESIS 0}

##################################################
# Helper function for constraints on latches
##################################################

if {$PRE_SYNTHESIS} {
  set latch_out_pin Q
} else {
  # If FF/latches output names change pre/post synthesis,
  # modify the termination pin name accordingly
  set latch_out_pin Q
}

################################
## Common Clocks Definitions  ##
################################
set REF_CLK_FREQ_HZ 1e6
set HOST_CLK_FREQ_HZ [expr 1e9/$::env(CLOCK_PERIOD)]

set RTC_CLK_FREQ_HZ 10e6 ;
set RTC_DIV_CLK_FREQ_HZ 0.5e6 ; 

set MAX_CLK_SKEW 0.1 ; 

set CLK_JITTER 0.05;

set CLK_TRANSITION_TIME 0.2;

#############
## Helpers ##
#############

# Converts frequency values in unit Hertz to tech library time units
proc freq_to_period {freq_hz} {
    return [expr 1e9/$freq_hz] ; # Time unit is 1 ns
}

# Apply default values for clock uncertainty. The command has an optional clock
# division arguments that will be used to scale down the impact of PLL clock
# jitter on divided clocks (if we divide the clock by N, jitter can also be
# modelled to be N-times smaller).
proc apply_default_uncertainty {clk_name {div_value 1}} {
    # A divided clock will approximately n times lower jitter than the source
    # clock since it integrates the period, thus reducing the noise. We thus
    # divide the jitter value by the dividers div_value (which by default is 1).
    global MAX_CLK_SKEW CLK_JITTER
    set_clock_uncertainty -setup [expr $MAX_CLK_SKEW + $CLK_JITTER/$div_value] $clk_name
    set_clock_uncertainty -hold $MAX_CLK_SKEW $clk_name
}

# Same as before, but post CTS, when the skew is known
proc apply_post_cts_uncertainty {clk_name {div_value 1}} {
    global CLK_JITTER
    set_clock_uncertainty -setup [expr $CLK_JITTER/$div_value] $clk_name
    set_clock_uncertainty -hold 0.01 $clk_name
}


proc set_max_bus_skew {max_skew dest_pins} {
    # Constraint each pin against each other pins
    foreach pin_a $dest_pins {
        foreach pin_b $dest_pins {
            if {[lsort $pin_a] != [lsort $pin_b]} {
                set_data_check -from $pin_a -to $pin_b -setup [expr -$max_skew]
            }
        }
    }
}


# Apply default value from clk transition
proc apply_default_clk_transition {clk_name} {
    global CLK_TRANSITION_TIME
    set_clock_transition $CLK_TRANSITION_TIME [get_clocks $clk_name]
}

# Removes elements matching a pattern from a list
proc remove_names_matching {obj_list exclude_pat} {
    set out {}
    foreach_in_collection obj $obj_list {
        set n [get_object_name $obj]
        if {![string match $exclude_pat $n]} {
            lappend out $n
        }
    }
    return $out
}

#########
# JTAG  #
#########
set JTAG_CLK_FREQ_HZ 20e6;

set JTAG_ID_MIN [expr [freq_to_period $JTAG_CLK_FREQ_HZ] * 0.25];
set JTAG_ID_MAX [expr [freq_to_period $JTAG_CLK_FREQ_HZ] * 0.25];
set JTAG_OD_MIN [expr [freq_to_period $JTAG_CLK_FREQ_HZ] * 0.25];
set JTAG_OD_MAX [expr [freq_to_period $JTAG_CLK_FREQ_HZ] * 0.25];



# set JTAG_ID_MIN 0.8 ; 
# set JTAG_ID_MAX 12; 
# set JTAG_OD_MIN -1 
#set JTAG_OD_MAX 12 ;

# serial link
set SERIAL_LINK_CLK_FREQ 20e6
set SERIAL_LINK_CLK_PERIOD [freq_to_period $SERIAL_LINK_CLK_FREQ]
set SERIAL_LINK_MAX_DATA_SKEW 0.1 ; # We allow at most +-100ps deviation from
                                    # the ideal transition time (1/4 period
                                    # before/after CK/CKN edge). Relax this
                                    # value if it is to tight.
########
# SPI  #
########
set SPI_CLOCK_FREQ 10e6 ;

set SPI_ID_MAX [expr 0.25*[freq_to_period $SPI_CLOCK_FREQ]]
set SPI_ID_MIN 1; 
set SPI_OD_MAX [expr 0.25*[freq_to_period $SPI_CLOCK_FREQ]]
set SPI_OD_MIN 0 ;

########
# I2C  #
########
set I2C_CLK_FREQ 1e6 ; 
set I2C_SYS_CLK_FREQ $HOST_CLK_FREQ_HZ
set I2C_ID_MIN 0 ;
set I2C_ID_MAX 480; 
set I2C_OD_MIN 0; 
set I2C_OD_MAX 100; 

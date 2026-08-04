# Cheshire func.sdc constraints
# in func.sdc we specify the clocks

#################
# CLOCK SIGNALS #
#################

# Main clock
create_clock -name host_clk -period [freq_to_period $HOST_CLK_FREQ_HZ] [get_ports clk_i]

# rtc clock
create_clock -name rtc_clk -period [freq_to_period $RTC_CLK_FREQ_HZ] [get_ports rtc_i]

# jtag clock
create_clock -name jtag_clk -period [freq_to_period $JTAG_CLK_FREQ_HZ] [ get_ports jtag_tck_i]
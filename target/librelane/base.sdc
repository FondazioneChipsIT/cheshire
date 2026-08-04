source common.sdc
source func.sdc

#########################################
# Driving cells and loads
#########################################
set driving_cell     sg13g2_buf_8
set driving_cell_clk sg13g2_buf_8
set load_cell        sg13g2_buf_8

# sg13g2_buf_8/A cap
set pin_load 0.0086 

set_load -pin_load $pin_load [all_outputs]
set_driving_cell [all_inputs]      -lib_cell $driving_cell     -pin X
set_driving_cell [get_ports clk_i] -lib_cell $driving_cell_clk -pin X
set_driving_cell [get_ports rtc_i] -lib_cell $driving_cell_clk -pin X
set_driving_cell [get_ports jtag_tck_i] -lib_cell $driving_cell_clk -pin X

# Clock transition
apply_default_clk_transition host_clk
apply_default_clk_transition rtc_clk
apply_default_clk_transition jtag_clk


##########################################
# Cheshire Defines                       #
##########################################

# spi
set SPI_SCK_PORT [get_ports spih_sck_o]
#set SPI_SCK_PIN [get_fanin -to [get_nets -hierarchical -regexp i_cheshire_soc/gen_spi_host*i_spi_host/u_spi_core/u_fsm/sck_o] -startpoints_only]
# puts "SPI Source pins: $SPI_SCK_PIN"

# i2c
set I2C_SCL_PORT [get_ports i2c_scl_o]
#set I2C_SCL_PIN  [get_fanin -to [get_nets -hierachical -regexp i_cheshire_soc/gen_i2c*i_i2c/i2c_core/u_i2c_fsm/scl_o] -startpoints_only]
# puts "I2C Source pins: $I2C_SCL_PIN"

###########################
# GENERATED CLOCK SIGNALS #
###########################

# create SPI generated clock
# Create interface output clock to which we relate the IO timing
# TODO Ensure the sub-block actually creates a generated clock! Otherwise
# the interface clock defined below will not have a combinational clock source.
# # create_generated_clock -name host_spi_sck_clk -source [get_ports clk_i] $SPI_SCK_PIN -divide_by [expr round($HOST_CLK_FREQ_HZ/$SPI_CLOCK_FREQ)]
# create_generated_clock -name host_spi_sck_clk_out -combinational -source $SPI_SCK_PIN $SPI_SCK_PORT

# create I2C generated clock
# # create_generated_clock -name host_i2c_clk -source [get_ports clk_i] $I2C_SCL_PIN -divide_by [expr round($HOST_CLK_FREQ_HZ/$I2C_CLK_FREQ)]
# create_generated_clock -name host_i2c_clk_out -combinational -source $I2C_SCL_PIN $I2C_SCL_PORT

###########################
# CLOCK UNCERTAINTY       # 
###########################
# - for main clock signals
apply_default_uncertainty  host_clk
apply_default_uncertainty  rtc_clk
apply_default_uncertainty  jtag_clk

# - for generated clock signals
# # apply_default_uncertainty  host_spi_sck_clk [expr round($HOST_CLK_FREQ_HZ/$SPI_CLOCK_FREQ)]
# # apply_default_uncertainty  host_i2c_clk [expr $HOST_CLK_FREQ_HZ/$I2C_CLK_FREQ]

##########################################
# Case Analys                            #
##########################################
# test mode 0 (disabled)
# # set_case_analysis 0 [get_ports test_mode_i]
# boot mode --> To check configuration for SPI boot
# # set_case_analysis 1 [get_ports boot_mode_i[0]]
# # set_case_analysis 0 [get_ports boot_mode_i[1]]

# i2c disable override mode
# set_case_analysis 0 [hier_find -pins i_cheshire_soc/gen_i2c_i_i2c/u_reg/u_ovrd_sclval/q*0* ]
# set_case_analysis 0 [hier_find -pins i_cheshire_soc/gen_i2c_i_i2c/u_reg/u_ovrd_txovrden/q*0* ]

##########################################
# Reset                                  #
##########################################
set_false_path -fall_through [get_ports rst_ni]
set_max_delay  -rise_through [get_ports rst_ni] [expr 0.8 * [freq_to_period $REF_CLK_FREQ_HZ]]
set_input_delay 0.3 [get_ports rst_ni] -rise -clock host_clk

##########################################
# IO Signals                             #
##########################################
#################
# REG EXT SYNCH #
#################
set REG_EXT_DEL_MARGIN 0.025
set_input_delay -add_delay -max [expr 0.4 * [freq_to_period  $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports reg_ext_slv_rsp_i*]
set_input_delay -add_delay -min [expr 0.4 * [freq_to_period  $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports reg_ext_slv_rsp_i*]
set_output_delay -add_delay -max [expr 0.25* [freq_to_period $HOST_CLK_FREQ_HZ] - $REG_EXT_DEL_MARGIN] -clock host_clk [get_ports reg_ext_slv_req_o*]
set_output_delay -add_delay -min [expr 0.25 * [freq_to_period $HOST_CLK_FREQ_HZ] - $REG_EXT_DEL_MARGIN] -clock host_clk [get_ports reg_ext_slv_req_o*]

###############
# DBG Signals #
###############
# Cross-check if dbg signals are synchronized outside
set_false_path -from [get_ports dbg_ext_unavail_i*]
set_false_path -to   [get_ports dbg_active_o]
set_false_path -to   [get_ports dbg_ext_req_o*]
set_false_path -to   [get_ports xeip_ext_o*]
set_false_path -to   [get_ports mtip_ext_o*]
set_false_path -to   [get_ports msip_ext_o*]

###############
# Interrupts  #
###############
set_input_delay  -add_delay -max [expr 0.4 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports intr_ext_i*]
set_input_delay  -add_delay -min [expr 0.4 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports intr_ext_i*]
set_output_delay -add_delay -max [expr 0.4 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports intr_ext_o*]
set_output_delay -add_delay -min [expr 0.4 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports intr_ext_o*]

###############
#     AXI     #
###############
set_input_delay  -add_delay -max [expr 0.25 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports axi_llc_mst_*_i]
set_input_delay  -add_delay -min [expr 0.25 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports axi_llc_mst_*_i]
set_output_delay -add_delay -max [expr 0.25 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports axi_llc_mst_*_o]
set_output_delay -add_delay -min [expr 0.25 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports axi_llc_mst_*_o]

set_input_delay  -add_delay -max [expr 0.25 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports axi_ext_*_i]
set_input_delay  -add_delay -min [expr 0.25 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports axi_ext_*_i]
set_output_delay -add_delay -max [expr 0.25 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports axi_ext_*_o]
set_output_delay -add_delay -min [expr 0.25 * [freq_to_period $HOST_CLK_FREQ_HZ]] -clock host_clk [get_ports axi_ext_*_o]


set_false_path -from [get_ports test_mode_i]

###############
# JTAG        # -- OK
###############
# clock set in func.sdc
set_false_path   -from [ get_ports jtag_trst_ni ]

set_input_delay  -min $JTAG_ID_MIN -clock jtag_clk -clock_fall [ get_ports jtag_tdi_i]
set_input_delay  -max $JTAG_ID_MAX -clock jtag_clk -clock_fall [ get_ports jtag_tdi_i ] -add_delay

set_output_delay -min $JTAG_OD_MIN -clock jtag_clk  [ get_ports jtag_tdo_o ]
set_output_delay -max $JTAG_OD_MAX -clock jtag_clk  [ get_ports jtag_tdo_o ] -add_delay

set_output_delay -min $JTAG_OD_MIN -clock jtag_clk  [ get_ports jtag_tdo_oe_o ]
set_output_delay -max $JTAG_OD_MAX -clock jtag_clk  [ get_ports jtag_tdo_oe_o ] -add_delay

set_input_delay  -min $JTAG_ID_MIN -clock jtag_clk -clock_fall [ get_ports jtag_tms_i]
set_input_delay  -max $JTAG_ID_MAX -clock jtag_clk -clock_fall [ get_ports jtag_tms_i] -add_delay

###############
# SPIM        #
###############

# clock set in func.sdc

# set ports
set spi_sck_o_pin      [get_ports spih_sck_o]
set spi_clk_en_o_pin   [get_ports spih_sck_en_o]
set spi_cs_o_pins      [get_ports spih_csb_o*]
set spi_cs_en_o_pins   [get_ports spih_csb_en_o*]
set spi_data_o_pins    [get_ports spih_sd_o*]
set spi_data_en_o_pins [get_ports spih_sd_en_o*]
set spi_data_i_pins    [get_ports spih_sd_i*]

# In SPI protocol, cs_en and sd_en signals are set before starting the communication
# therefore, they seem to not be critical for timing and excluded from inout delay
# set input output delays
# # set_input_delay -max  $SPI_ID_MAX -clock  host_spi_sck_clk -clock_fall  $spi_data_i_pins  -add_delay
# # set_input_delay -min  $SPI_ID_MIN -clock  host_spi_sck_clk -clock_fall  $spi_data_i_pins  -add_delay
# # set_output_delay -max $SPI_OD_MAX -clock  host_spi_sck_clk \
    [list $spi_data_o_pins $spi_cs_o_pins ]  -add_delay
# # set_output_delay -min $SPI_OD_MIN -clock  host_spi_sck_clk \
    [list $spi_data_o_pins $spi_cs_o_pins ]  -add_delay


# multi-cycle paths
# Since the SPI's output shift register is actually clocked with the spi's
# sys clock, we need a suitable multicycle path for launch and capture
# paths. Since we launch and sample in one half period, the multi-cycle
# factor is also only 1/2 of the full cycle one.
set SPI_MULTICYCLES [expr round($HOST_CLK_FREQ_HZ/$SPI_CLOCK_FREQ)/2]
# Input
# # set_multicycle_path -setup -from host_spi_sck_clk -to host_clk -end $SPI_MULTICYCLES
# # set_multicycle_path -hold  -from host_spi_sck_clk -to host_clk -end [expr $SPI_MULTICYCLES-1]
# Output
# # set_multicycle_path -setup -from host_clk -to host_spi_sck_clk -start $SPI_MULTICYCLES
# # set_multicycle_path -hold  -from host_clk -to host_spi_sck_clk -start [expr $SPI_MULTICYCLES-1]


###############
# I2C         #
###############

# set ports
set I2C_SCL_IN_PIN     [get_ports  i2c_scl_i]
set I2C_SCL_OUT_PIN    [get_ports i2c_scl_o]
set I2C_SCL_OUT_EN_PIN [get_ports i2c_scl_en_o]
set I2C_SDA_IN_PIN     [get_ports i2c_sda_i]
set I2C_SDA_OUT_PIN    [get_ports i2c_sda_o]
set I2C_SDA_OUT_EN_PIN [get_ports i2c_sda_en_o]

# Data is always sent with the falling edge and sampled with the rising edge.
# However, in our case the sampling clock is the much faster sys clock which
# always sends and samples at the rising edge.
# # set_input_delay -min $I2C_ID_MIN -clock host_i2c_clk -clock_fall $I2C_SDA_IN_PIN -add_delay
# # set_input_delay -max $I2C_ID_MAX -clock host_i2c_clk -clock_fall $I2C_SDA_IN_PIN -add_delay

# # set_output_delay -min $I2C_OD_MIN -clock host_i2c_clk [list $I2C_SDA_OUT_PIN $I2C_SDA_OUT_EN_PIN $I2C_SCL_OUT_EN_PIN] -add_delay
# # set_output_delay -max $I2C_OD_MAX -clock host_i2c_clk [list $I2C_SDA_OUT_PIN $I2C_SDA_OUT_EN_PIN $I2C_SCL_OUT_EN_PIN] -add_delay

# Since data is send on falling edge and sampled on the next rising edge, we
# always have only 1/2 clock period available. Therefore, our multicycle paths
# is only 1/2 of t_i2c_clk/t_sys_clk
set I2C_MULTICYCLES [expr round($HOST_CLK_FREQ_HZ/$I2C_CLK_FREQ/2)]
# # set_multicycle_path -setup -from host_clk -to host_i2c_clk -start $I2C_MULTICYCLES
# # set_multicycle_path -hold -from host_clk -to host_i2c_clk -start [expr $I2C_MULTICYCLES-1]
# # set_multicycle_path -setup -from host_i2c_clk -to host_clk -end $I2C_MULTICYCLES
# # set_multicycle_path -hold -from host_i2c_clk -to host_clk -end [expr $I2C_MULTICYCLES-1]


###############
# UART        #
###############
# UART is a fully asynchronous protocol. We don't need to constrain it. We
# explicitely false path the ports to document our design intention and to avoid
# any SDC linter to raise concerns about unconstrained ports
set_false_path  -from [get_ports uart_rx_i]
set_false_path  -to   [get_ports uart_tx_o]

###############
# GPIOS       #
###############
# We leave the GPIOs unconstrained. There are no requirements on max skew
# between GPIOs nor is there any expectations on the maximum delay from GPIO
# register to pad.
set_false_path -from [get_ports gpio_i*]
set_false_path -to   [get_ports gpio_o*]
set_false_path -to   [get_ports gpio_en_*]

##########################################
# Clock Groups                           #
##########################################
# set_clock_groups -asynchronous -group {host_clk host_spi_sck_clk host_i2c_clk}
set_clock_groups -asynchronous -name clk_groups_async \
     -group {host_clk} \
     -group {jtag_clk} \
     -group {rtc_clk}

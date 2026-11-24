#/*--------------------------------------------------------------*/
#/*--------------- 2. Set design constraints --------------------*/ 
#/*--------------------------------------------------------------*/
# Setting Design and I/O Environment
set_operating_conditions -library slow_vdd1v2 PVT_1P08V_125C

create_clock -period $TEST_CYCLE [get_ports clk]
set_dont_touch_network [get_clocks clk]
set_fix_hold clk
#set_dont_touch_network [get_ports rst_n]

# Assume outputs go to DFF and inputs also come from DFF
set_driving_cell -library slow_vdd1v2 -lib_cell DFFHQX1 -pin {Q} [all_inputs]  
set_load [load_of "slow_vdd1v2/DFFHQX1/D"] [all_outputs] 

set_drive 1 [all_inputs] 
set_load [load_of slow/CLKBUFX20/A] [all_outputs]

set_input_delay  [expr $TEST_CYCLE/2.0] -clock clk [remove_from_collection [all_inputs] [get_ports clk]] 
set_output_delay [expr $TEST_CYCLE/2.0] -clock clk [all_outputs] 

#/*--------------------------------------------------------------*/
#/*----------------- 3.Check and Link Design --------------------*/ 
#/*--------------------------------------------------------------*/
link 
check_design
uniquify
set_fix_multiple_port_nets -all -buffer_constants  
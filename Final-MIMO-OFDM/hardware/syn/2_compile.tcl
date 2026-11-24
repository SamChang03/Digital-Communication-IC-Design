#/*--------------------------------------------------------------*/
#/*------------------------ 4.Compile ---------------------------*/ 
#/*--------------------------------------------------------------*/

# Setting DRC Constraint
set_max_fanout 20.0 $TOPLEVEL

# Area Constraint
set_max_area   0

# before synthesis settings
set case_analysis_with_logic_constants true
set_fix_multiple_port_nets -all -buffer_constants

set_clock_gating_style -max_fanout 10

compile_ultra -exact_map -no_autoungroup -no_seq_output_inversion -incremental -gate_clock
no_boundary_optimization

# remove dummy ports
remove_unconnected_ports [get_cells -hierarchical *]
remove_unconnected_ports [get_cells -hierarchical *] -blast_buses

check_design 

set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true
change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\*cell\*" "cell"}}
define_name_rules name_rule -map {{"*-return", "myreturn"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule

set verilogout_show_unconnected_pins true  
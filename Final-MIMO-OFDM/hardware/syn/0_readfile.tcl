set TOP_DIR $TOPLEVEL
set RPT_DIR report
set NET_DIR netlist

sh rm -rf ./$TOP_DIR
sh rm -rf ./$RPT_DIR
sh rm -rf ./$NET_DIR
sh mkdir ./$TOP_DIR
sh mkdir ./$RPT_DIR
sh mkdir ./$NET_DIR

# define a lib path here
define_design_lib $TOPLEVEL -path ./$TOPLEVEL

# Read Design File (add your files here)
set HDL_DIR "../hdl" 

analyze -library $TOPLEVEL -format verilog "../hdl/top_FSM.v"
# --- Fundamental Math and Arithmetic Components ---
analyze -library $TOPLEVEL -format verilog "../hdl/complex_add.v"
analyze -library $TOPLEVEL -format verilog "../hdl/complex_sub.v"
analyze -library $TOPLEVEL -format verilog "../hdl/complex_mult.v"
analyze -library $TOPLEVEL -format verilog "../hdl/complex_to_mag.v"
analyze -library $TOPLEVEL -format verilog "../hdl/complex_to_mag_sq.v"
analyze -library $TOPLEVEL -format verilog "../hdl/mv_avg.v"
analyze -library $TOPLEVEL -format verilog "../hdl/mv_avg_dual_ch.v"
analyze -library $TOPLEVEL -format verilog "../hdl/FIFO_delay.v"
analyze -library $TOPLEVEL -format verilog "../hdl/FIFO_delay_complex.v"
analyze -library $TOPLEVEL -format verilog "../hdl/ping_pong_buffer.v"

# --- Signal Processing Rotators and FFT Modules ---
analyze -library $TOPLEVEL -format verilog "../hdl/Rotator.v"
analyze -library $TOPLEVEL -format verilog "../hdl/Rotator_W8.v"
analyze -library $TOPLEVEL -format verilog "../hdl/BF2.v"
analyze -library $TOPLEVEL -format verilog "../hdl/PE_radix23.v"
analyze -library $TOPLEVEL -format verilog "../hdl/FFT_64.v"

# --- Synchronization and Channel Processing Modules ---
analyze -library $TOPLEVEL -format verilog "../hdl/sync_short.v"
analyze -library $TOPLEVEL -format verilog "../hdl/sync_long.v"
analyze -library $TOPLEVEL -format verilog "../hdl/channel_mem.v"
analyze -library $TOPLEVEL -format verilog "../hdl/channel_est.v"
analyze -library $TOPLEVEL -format verilog "../hdl/channel_prepocessing.v"

# --- MIMO Detection and Demapping Modules ---
analyze -library $TOPLEVEL -format verilog "../hdl/MIMO_detection.v"
analyze -library $TOPLEVEL -format verilog "../hdl/QAM_demap.v"

# --- System Top Level ---
analyze -library $TOPLEVEL -format verilog "../hdl/MIMO_OFDM_top.v"


# elaborate your design
elaborate $TOPLEVEL -architecture verilog -library $TOPLEVEL

# Solve Multiple Instance
set uniquify_naming_style "%s_mydesign_%d" 
uniquify 

# link the design
current_design $TOPLEVEL 
link
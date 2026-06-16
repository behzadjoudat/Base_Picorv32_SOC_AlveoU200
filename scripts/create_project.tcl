# =============================================================================
# create_project.tcl  —  Pure RTL + Xilinx IP flow (no Block Design)
#
# Creates the Vivado project, generates the three Xilinx IPs, adds all RTL
# sources, and sets up constraints.  The top module is "top" (rtl/top.v).
#
# Usage (from the repo root):
#   vivado -mode batch -source scripts/create_project.tcl \
#          -tclargs [--part <part>] [--coe <abs-path-to-firmware.coe>]
#
# Default part : xcu200-fsgd2104-2-e  (Alveo U200)
# =============================================================================

# ---- argument parsing -------------------------------------------------------
set part_number "xcu200-fsgd2104-2-e"
set coe_file    [file normalize [file join [pwd] firmware/firmware.coe]]
set proj_name   "alveo_picorv32_soc"
set proj_dir    "vivado"

if {$::argc > 0} {
    for {set i 0} {$i < [llength $::argv]} {incr i} {
        switch -- [lindex $::argv $i] {
            "--part" { incr i; set part_number [lindex $::argv $i] }
            "--coe"  { incr i; set coe_file    [file normalize [lindex $::argv $i]] }
        }
    }
}

puts "================================================================"
puts " Part      : $part_number"
puts " COE file  : $coe_file"
puts " Project   : $proj_dir/$proj_name"
puts "================================================================"

if {![file exists $coe_file]} {
    error "COE file not found: $coe_file\nRun 'make firmware' first."
}
if {![file exists rtl/picorv32.v]} {
    error "rtl/picorv32.v not found.\nRun 'make deps' (bash scripts/fetch_picorv32.sh) first."
}

# ---- create Vivado project --------------------------------------------------
file mkdir $proj_dir
create_project $proj_name $proj_dir/$proj_name -part $part_number -force

set_property target_language  Verilog      [current_project]
set_property default_lib      xil_defaultlib [current_project]

# ---- add RTL sources --------------------------------------------------------
# Order matters for compile order; list all .v files explicitly.
add_files -norecurse [list \
    rtl/picorv32.v \
    rtl/picorv32_axi_wrap.v \
    rtl/soc.v \
    rtl/top.v \
]

# picorv32.v contains multiple module definitions; mark it as a regular source
# (not a header/include) so all modules within it are visible to the project.
set_property file_type {Verilog} [get_files rtl/picorv32.v]

# Set the top-level module
set_property top top [current_fileset]
update_compile_order -fileset sources_1

# ---- add constraints --------------------------------------------------------
add_files -fileset constrs_1 -norecurse constraints/alveo_u200.xdc
set_property target_constrs_file constraints/alveo_u200.xdc [current_fileset -constrset]

# ---- generate Xilinx IPs ----------------------------------------------------

# Helper: find the latest version of an IP if the pinned version is absent
proc best_ip_version {name vendor} {
    set defs [get_ipdefs -filter "NAME == $name && VENDOR == $vendor" -quiet]
    if {[llength $defs] == 0} {
        error "IP '$name' from '$vendor' not found in the IP catalog."
    }
    # sort by version string descending, return highest
    return [lindex [lsort -decreasing $defs] 0]
}

# --- 1. AXI UART Lite (115200 baud, 8N1, no parity) -------------------------
puts ">> Generating axi_uartlite_0 ..."
create_ip -name axi_uartlite -vendor xilinx.com -library ip \
          -version 2.0 -module_name axi_uartlite_0 -quiet
if {[llength [get_ips axi_uartlite_0]] == 0} {
    # Vivado 2024.x may have renamed the version; pick latest
    set vlnv [best_ip_version axi_uartlite xilinx.com]
    create_ip -vlnv $vlnv -module_name axi_uartlite_0
}
set_property -dict {
    CONFIG.C_BAUDRATE          115200
    CONFIG.C_DATA_BITS         8
    CONFIG.C_USE_PARITY        0
    CONFIG.C_ODD_PARITY        0
    CONFIG.C_S_AXI_ACLK_FREQ_HZ 100000000
} [get_ips axi_uartlite_0]
generate_target {synthesis simulation} [get_ips axi_uartlite_0]

# --- 2. AXI BRAM Controller --------------------------------------------------
# DATA_WIDTH=32, MEM_DEPTH=32768 words (128 KB), ID_WIDTH=0 (AXI4-Lite compat)
# Single port BRAM=0 → two native BRAM ports (port A writes, port B reads)
puts ">> Generating axi_bram_ctrl_0 ..."
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip \
          -version 4.1 -module_name axi_bram_ctrl_0 -quiet
if {[llength [get_ips axi_bram_ctrl_0]] == 0} {
    set vlnv [best_ip_version axi_bram_ctrl xilinx.com]
    create_ip -vlnv $vlnv -module_name axi_bram_ctrl_0
}
set_property -dict {
    CONFIG.DATA_WIDTH        32
    CONFIG.SINGLE_PORT_BRAM  0
    CONFIG.ECC_TYPE          None
    CONFIG.ID_WIDTH          0
    CONFIG.MEM_DEPTH         32768
} [get_ips axi_bram_ctrl_0]
generate_target {synthesis simulation} [get_ips axi_bram_ctrl_0]

# --- 3. Block Memory Generator (True Dual Port, 128 KB, init from COE) ------
# Port A  : write (driven by axi_bram_ctrl port A)
# Port B  : read  (driven by axi_bram_ctrl port B)
# soc.v connects: addra = bram_addr_a[16:2]  (17-bit byte → 15-bit word)
puts ">> Generating blk_mem_gen_0 (COE: $coe_file) ..."
create_ip -name blk_mem_gen -vendor xilinx.com -library ip \
          -version 8.4 -module_name blk_mem_gen_0 -quiet
if {[llength [get_ips blk_mem_gen_0]] == 0} {
    set vlnv [best_ip_version blk_mem_gen xilinx.com]
    create_ip -vlnv $vlnv -module_name blk_mem_gen_0
}
set_property -dict [list \
    CONFIG.Memory_Type                          {True_Dual_Port_RAM} \
    CONFIG.Use_Byte_Write_Enable                {true} \
    CONFIG.Byte_Size                            {8} \
    CONFIG.Write_Width_A                        {32} \
    CONFIG.Write_Depth_A                        {32768} \
    CONFIG.Read_Width_A                         {32} \
    CONFIG.Enable_A                             {Use_ENA_Pin} \
    CONFIG.Operating_Mode_A                     {READ_FIRST} \
    CONFIG.Write_Width_B                        {32} \
    CONFIG.Read_Width_B                         {32} \
    CONFIG.Enable_B                             {Use_ENB_Pin} \
    CONFIG.Operating_Mode_B                     {READ_FIRST} \
    CONFIG.Load_Init_File                       {true} \
    CONFIG.Coe_File                             $coe_file \
    CONFIG.Fill_Remaining_Memory_Locations      {false} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
] [get_ips blk_mem_gen_0]
generate_target {synthesis simulation} [get_ips blk_mem_gen_0]

# ---- finalize ---------------------------------------------------------------
update_compile_order -fileset sources_1

puts ""
puts "================================================================"
puts " Project created successfully."
puts " Top module : top"
puts " IPs        : axi_uartlite_0  axi_bram_ctrl_0  blk_mem_gen_0"
puts " Next step  : vivado -mode batch -source scripts/build.tcl"
puts "================================================================"

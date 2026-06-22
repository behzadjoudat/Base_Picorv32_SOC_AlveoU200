# =============================================================================
# program.tcl
# Programs an Alveo card via Vivado hw_server.
#
# Usage (from the repo root):
#   vivado -mode batch -source scripts/program.tcl \
#          -tclargs [--bit <file.bit>] [--server localhost:3121]
# =============================================================================

set bit_file "alveo_boom_soc.bit"
set hw_server "localhost:3121"

if { $::argc > 0 } {
    for {set i 0} {$i < [llength $::argv]} {incr i} {
        switch -- [lindex $::argv $i] {
            "--bit"    { incr i; set bit_file  [lindex $::argv $i] }
            "--server" { incr i; set hw_server [lindex $::argv $i] }
        }
    }
}

if { ![file exists $bit_file] } {
    error "Bitstream not found: $bit_file\nRun 'make bitstream' first."
}

puts "================================================================"
puts " Programming Alveo"
puts " Bitstream : $bit_file"
puts " hw_server : $hw_server"
puts "================================================================"

open_hw_manager
connect_hw_server -url $hw_server

# The Alveo shows up as an XSDB/JTAG target; open the first available target
open_hw_target

# Find the Ultrascale+ device (xcu200 / xcu250 etc.)
set dev [lindex [get_hw_devices] 0]
if { $dev eq "" } {
    error "No hardware devices found.  Is hw_server running and the Alveo connected?"
}

puts ">> Found device: [get_property PART $dev]"
current_hw_device $dev

set_property PROGRAM.FILE $bit_file $dev
program_hw_devices $dev
refresh_hw_device $dev

puts "================================================================"
puts " Programming complete."
puts "================================================================"

close_hw_target
disconnect_hw_server
close_hw_manager

# =============================================================================
# build.tcl — Synthesis → Implementation → Bitstream
#
# Usage (from the repo root):
#   vivado -mode batch -source scripts/build.tcl \
#          -tclargs [--jobs <n>]
# =============================================================================

set num_jobs  4
set proj_name "alveo_boom_soc"
set proj_dir  "vivado"

if {$::argc > 0} {
    for {set i 0} {$i < [llength $::argv]} {incr i} {
        switch -- [lindex $::argv $i] {
            "--jobs" { incr i; set num_jobs [lindex $::argv $i] }
        }
    }
}

set xpr "$proj_dir/$proj_name/$proj_name.xpr"
if {![file exists $xpr]} {
    error "Project not found: $xpr\nRun 'make project' first."
}

open_project $xpr

# ---- force BRAM IP re-synthesis so COE changes are always picked up ---------
# Vivado's IP timestamp check sometimes misses COE file updates; always reset.
if {[get_runs -quiet blk_mem_gen_0_synth_1] ne ""} {
    reset_run blk_mem_gen_0_synth_1
    launch_runs blk_mem_gen_0_synth_1 -jobs $num_jobs
    wait_on_run blk_mem_gen_0_synth_1
    puts ">> BRAM IP re-synthesis complete."
}

# ---- synthesis --------------------------------------------------------------
puts ">> Launching synthesis (synth_1) ..."
reset_run synth_1
launch_runs synth_1 -jobs $num_jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "Synthesis FAILED.  Check $proj_dir/$proj_name/$proj_name.runs/synth_1/*.log"
}
puts ">> Synthesis complete."

# ---- implementation + bitstream in one run ----------------------------------
puts ">> Launching implementation (impl_1) → write_bitstream ..."
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $num_jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementation FAILED.  Check $proj_dir/$proj_name/$proj_name.runs/impl_1/*.log"
}
puts ">> Implementation complete."

# ---- copy bitstream to repo root --------------------------------------------
set bit_candidates [glob -nocomplain \
    "$proj_dir/$proj_name/$proj_name.runs/impl_1/*.bit"]

if {[llength $bit_candidates] == 0} {
    puts "WARNING: No .bit file found in impl_1 run directory."
} else {
    set bit_src [lindex $bit_candidates 0]
    set bit_dst "alveo_boom_soc.bit"
    file copy -force $bit_src $bit_dst
    puts ">> Bitstream → $bit_dst"
}

puts ""
puts "================================================================"
puts " Build complete."
puts " Program with: vivado -mode batch -source scripts/program.tcl"
puts "================================================================"

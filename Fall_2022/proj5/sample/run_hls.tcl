# Set variable to select which steps to execute
set hls_exec 3

###############################################################################

# Create a project
open_project -reset project

# Add design files
add_files convolution.cpp 
add_files convolution.h

# Add test bench & files
add_files -tb testbench.cpp

# Set the top-level function
set_top convolve_hls

###############################################################################

# Create a solution

open_solution -reset solution1
# Define technology and clock rate
set_part {xc7z020-clg400-1}
create_clock -period 10

###############################################################################

csim_design

# Set any optimization directives
# End of directives

if {$hls_exec == 1} {
	# Run Synthesis and Exit
	csynth_design	
} elseif {$hls_exec == 2} {
	# Run Synthesis, RTL Simulation and Exit
	csynth_design	
	cosim_design
} elseif {$hls_exec == 3} { 
	# Run Synthesis, RTL Simulation, RTL implementation and Exit
	csynth_design	
	cosim_design
	export_design
} else {
	# Default is to exit after setup
	csynth_design
}

exit



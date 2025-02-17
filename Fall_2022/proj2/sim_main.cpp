// DESCRIPTION: Verilator: Verilog example module
//
// This file ONLY is placed into the Public Domain, for any use,
// without warranty, 2017 by Wilson Snyder.
//======================================================================
#include <iostream>

// Include common routines
#include <verilated.h>

// Include model header, generated from Verilating "pipeline.v"
#include "Vpipeline.h"
#include "Vpipeline__Syms.h"

#ifdef VCD_OUTPUT
#include <verilated_vcd_c.h>
#endif

// Current simulation time (64-bit unsigned)
uint64_t timestamp = 0;

double sc_time_stamp() { return timestamp; }

#define RUN_CYCLES 40000

#define CLOCK_PERIOD 10

#define RESET_TIME 100

int last_print_inst_count_WB = 0;

int main(int argc, char **argv, char **env) {
  // See a similar example walkthrough in the verilator manpage.

  // This is intended to be a minimal example.  Before copying this to start a
  // real project, it is better to start with a more complete example,
  // e.g. examples/c_tracing.

  // Prevent unused variable warnings
  if (0 && argc && argv && env) {
  }

  // Construct the Verilated model
  Vpipeline *dut = new Vpipeline();

#ifdef VCD_OUTPUT
  Verilated::traceEverOn(true);
  auto trace = new VerilatedVcdC();
  dut->trace(trace, 2999);
  trace->open("trace.vcd");
#endif

  // set some inputs
  // dut->clk = 0;
  // dut->reset = 0;
  // dut->KEY = 15;

  // Simulate until $finish
  // while (!Verilated::gotFinish()) {

  while (timestamp < RUN_CYCLES) {
    if ((timestamp % CLOCK_PERIOD))
      dut->clk = !dut->clk;

    if (timestamp > 1 && timestamp < RESET_TIME) {
      dut->reset = 1; // Assert reset
    } else {
      dut->reset = 0; // Deassert reset
    }

    // Evaluate model
    dut->eval();

#ifdef DPRINTF
    // verilator allows to access verilator public data structure

    /* writeback stage*/
    int inst_count_WB = (int)dut->pipeline->my_WB_stage->WB_counters[5];
    if (inst_count_WB > last_print_inst_count_WB) {
      std::cout << "[" << (int)(timestamp) << "] ";
      std::cout << " inst_count_WB: " << std::dec << inst_count_WB;
      std::cout << " PC_WB: 0x" << std::hex
                << (int)dut->pipeline->my_WB_stage->WB_counters[1];
      std::cout << " Inst_WB: 0x" << std::hex
                << (int)dut->pipeline->my_WB_stage->WB_counters[2];
      std::cout << " Op_I:" << std::dec
                << (int)dut->pipeline->my_WB_stage->WB_counters[6];
      int wr_reg_WB = (int)dut->pipeline->my_WB_stage->WB_counters[3];
      if (wr_reg_WB) {
        std::cout << " wr_reg_WB:" << std::dec << wr_reg_WB;
        std::cout << " regval_WB:" << std::dec
                  << (int)dut->pipeline->my_WB_stage->WB_counters[4];

        std::cout << " wregno_WB:" << std::dec
                  << (int)dut->pipeline->my_WB_stage->WB_counters[7];
      }
      std::cout << std::endl;
      last_print_inst_count_WB = inst_count_WB;
    }

#endif

#ifdef VCD_OUTPUT
    trace->dump(timestamp);
#endif
    ++timestamp;
  }

  int exitcode = (int)dut->pipeline->my_WB_stage->last_WB_value[10];

  // Final model cleanup
  dut->final();

#ifdef VCD_OUTPUT
  trace->close();
  delete trace;
#endif

  // Destroy DUT
  delete dut;

  // TinyRV1 test Pass/Fail status
  if (255 == exitcode)
    std::cout << "Passed! cycle_count:" << last_print_inst_count_WB
              << std::endl;
  else
    std::cout << "Failed. exitcode: " << exitcode << std::endl;

  // Fin
  exit(0);
}

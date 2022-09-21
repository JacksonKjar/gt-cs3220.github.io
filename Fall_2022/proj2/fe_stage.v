 `include "define.vh" 

module FE_STAGE(
        input wire                              clk,
        input wire                              reset,
        input wire  [`from_DE_to_FE_WIDTH-1:0]  from_DE_to_FE,
        input wire  [`from_AGEX_to_FE_WIDTH-1:0] from_AGEX_to_FE,
        input wire  [`from_MEM_to_FE_WIDTH-1:0] from_MEM_to_FE,
        input wire  [`from_WB_to_FE_WIDTH-1:0]  from_WB_to_FE,
        output wire [`FE_latch_WIDTH-1:0]       FE_latch_out
    );


    // I-MEM
    (* ram_init_file = `IDMEMINITFILE *)
    reg [`DBITS-1:0] imem [`IMEMWORDS-1:0];

    initial begin
        $readmemh(`IDMEMINITFILE , imem);
    end

    /*
    // Display memory contents with verilator 
    always @(posedge clk) begin
      for (integer i=0 ; i<`IMEMWORDS ; i=i+1) begin
          $display("%h", imem[i]);
      end
    end
    */

    /* pipeline latch */
    reg [`FE_latch_WIDTH-1:0] FE_latch;
    reg [`DBITS-1:0] PC_FE_latch; // PC latch in the FE stage

    wire [`FE_latch_WIDTH-1:0] FE_latch_contents;  // the signals used to update latch
    wire [`INSTBITS-1:0] inst_FE;  // instruction value in the FE stage
    wire [`DBITS-1:0] pcplus_FE;  // next instruction address
    wire stall_pipe_FE; // signal to indicate when a front-end needs to be stall


    // reading instruction from imem
    assign inst_FE = imem[PC_FE_latch[`IMEMADDRBITS-1:`IMEMWORDBITS]];  // this code works. imem is stored 4B together

    // wire to send the FE latch contents to the DE stage
    assign FE_latch_out = FE_latch;

    reg [`DBITS-1:0] inst_count_FE; /* for debugging purpose */

    wire [`DBITS-1:0] inst_count_AGEX; /* for debugging purpose. resent the instruction counter */

    // This is the value of "incremented PC", computed in the FE stage
    assign pcplus_FE = PC_FE_latch + `INSTSIZE;


    // the order of latch contents should be matched in the decode stage when we extract the contents.
    assign FE_latch_contents = {
               inst_FE,
               PC_FE_latch,
               pcplus_FE,
               inst_count_FE,
               br_cond_AGEX, // invalid
               `BUS_CANARY_VALUE // for an error checking of bus encoding/decoding
           };

    wire br_cond_AGEX; // do we need to follow branch (determined by AGEX)
    wire [`DBITS-1:0] br_PC_AGEX; // new pc to branch to (determined by AGEX)
    assign {br_cond_AGEX, br_PC_AGEX} = from_AGEX_to_FE;
    assign {stall_pipe_FE} = from_DE_to_FE;

    // update PC
    always @ (posedge clk) begin
        if (reset) begin
            PC_FE_latch <= `STARTPC;
            inst_count_FE <= 1;  /* inst_count starts from 1 for easy human reading. 1st fetch instructions can have 1 */
        end
        else if (stall_pipe_FE)
            PC_FE_latch <= PC_FE_latch;
        else if (br_cond_AGEX) begin
            PC_FE_latch <= br_PC_AGEX;
            inst_count_FE <= inst_count_FE - 1;
        end
        else begin
            PC_FE_latch <= pcplus_FE;
            inst_count_FE <= inst_count_FE + 1;
        end
    end


    // update latch
    always @ (posedge clk) begin
        if (reset)
        begin
            FE_latch <= {`FE_latch_WIDTH{1'b0}};
        end
        else
        begin
            if (stall_pipe_FE)
                FE_latch <= FE_latch;
            else
                FE_latch <= FE_latch_contents;
        end
    end

endmodule

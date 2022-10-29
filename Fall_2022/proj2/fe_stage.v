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

    initial
    begin
        $readmemh(`IDMEMINITFILE , imem);
        for (integer i = 0; i < 256; ++i)
            pht[i] = 0;
    end

    /*
    // Display memory contents with verilator 
    always @(posedge clk) begin
      for (integer i=0 ; i<`IMEMWORDS ; i=i+1) begin
          $display("%h", imem[i]);
      end
    end
    */

    // branch prediction

    reg [1:0] pht [255:0];

    reg [7:0] bhr;

    reg [58:0] btb [15:0];

    wire [58:0] btb_entry = btb[PC_FE_latch[5:2]];
    wire [`DBITS - 1 : 0] btb_target = btb_entry[31:0];
    wire btb_hit = btb_entry[58] && btb_entry[57:32] == PC_FE_latch[31:6];

    wire [7:0] pht_index = PC_FE_latch[9:2] ^ bhr;
    wire predict_taken = pht[pht_index] > 1 && btb_hit;

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
	       pht_index,
	       predict_taken,
               inst_count_FE,
               br_mispredicted_AGEX, // invalid
               `BUS_CANARY_VALUE // for an error checking of bus encoding/decoding
           };

    wire is_br_AGEX; // was this instruction a branch
    wire br_mispredicted_AGEX; // did we mispredict it
    wire br_taken_AGEX; // is the branch supposed to be taken
    wire [`DBITS-1:0] br_target_AGEX; // new pc if taken
    wire [`DBITS-1:0] pcplus_AGEX; // new pc if not taken
    wire [`DBITS-1:0] PC_AGEX; // used to index the btb to add target
    wire [7:0] pht_index_AGEX; // used to index the pht
    assign {
	is_br_AGEX,
	br_mispredicted_AGEX,
	br_taken_AGEX,
	br_target_AGEX,
	pcplus_AGEX,
	PC_AGEX,
	pht_index_AGEX
    } = from_AGEX_to_FE;
    assign {stall_pipe_FE} = from_DE_to_FE;

    // update PC
    always @ (posedge clk)
    begin
        if (reset)
        begin
            PC_FE_latch <= `STARTPC;
            inst_count_FE <= 1;  /* inst_count starts from 1 for easy human reading. 1st fetch instructions can have 1 */
        end
        else if (br_mispredicted_AGEX)
        begin
            PC_FE_latch <= br_taken_AGEX ? br_target_AGEX : pcplus_AGEX;
            inst_count_FE <= inst_count_FE - 1;
        end
        else if (stall_pipe_FE)
            PC_FE_latch <= PC_FE_latch;
        else
        begin
            PC_FE_latch <= predict_taken ? btb_target : pcplus_FE;
            inst_count_FE <= inst_count_FE + 1;
        end
    end

    // update latch
    always @ (posedge clk)
    begin
        if (reset)
        begin
            FE_latch <= {`FE_latch_WIDTH{1'b0}};
        end
        else
        begin
            if (!br_mispredicted_AGEX && stall_pipe_FE)
                FE_latch <= FE_latch;
            else
                FE_latch <= FE_latch_contents;
        end
    end

    always @(posedge clk)
    begin
        if (reset)
        begin
            for (integer i = 0; i < 16; ++i)
                btb[i] <= 59'b0;
            bhr <= 0;
        end
        else if (is_br_AGEX)
        begin
	    bhr <= {bhr[6:0], br_taken_AGEX};
	    btb[PC_AGEX[5:2]] <= {1'b1, PC_AGEX[31:6], br_target_AGEX};
	    if (br_taken_AGEX)
		pht[pht_index_AGEX] <= pht[pht_index_AGEX] == 3 ? 3 : pht[pht_index_AGEX] + 1;
	    else
		pht[pht_index_AGEX] <= pht[pht_index_AGEX] == 0 ? 0 : pht[pht_index_AGEX] - 1;
        end
    end
endmodule

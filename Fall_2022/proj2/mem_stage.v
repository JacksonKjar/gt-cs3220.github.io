`include "define.vh"

module MEM_STAGE(
        input wire                              clk,
        input wire                              reset,
        input wire  [`from_WB_to_MEM_WIDTH-1:0] from_WB_to_MEM,
        input wire  [`AGEX_latch_WIDTH-1:0]     from_AGEX_latch,
        output wire [`MEM_latch_WIDTH-1:0]      MEM_latch_out,
        output wire [`from_MEM_to_FE_WIDTH-1:0] from_MEM_to_FE,
        output wire [`from_MEM_to_DE_WIDTH-1:0] from_MEM_to_DE,
        output wire [`from_WB_to_AGEX_WIDTH-1:0] from_MEM_to_AGEX
    );
    // D-MEM
    (* ram_init_file = `IDMEMINITFILE *)
    reg [`DBITS-1:0] dmem[`DMEMWORDS-1:0];

    // DMEM and IMEM should contains the same contents
    initial
    begin
        $readmemh(`IDMEMINITFILE , dmem);
    end

    reg [`MEM_latch_WIDTH-1:0] MEM_latch;

    wire[`MEM_latch_WIDTH-1:0] MEM_latch_contents;

    wire [`IOPBITS-1:0] op_I_MEM;
    wire [`DBITS-1:0] inst_count_MEM;
    wire [`INSTBITS-1:0] inst_MEM;
    wire [`DBITS-1:0] PC_MEM;
    wire [`REGNOBITS-1:0] rd_MEM;


    wire [`BUS_CANARY_WIDTH-1:0] bus_canary_MEM;

    wire [`DBITS-1:0] memaddr_MEM;  // memory address. need to be computed in AGEX stage and pass through a latch
    wire [`DBITS-1:0] rd_val_MEM;  // memory read value
    wire [`DBITS-1:0] wr_val_MEM;  // memory write value
    wire wr_mem_MEM;
    assign wr_mem_MEM = op_I_MEM == `SW_I;

    // Read from D-MEM  (read code is completed if there is a correct memaddr_MEM )
    assign rd_val_MEM = op_I_MEM == `LW_I ? dmem[memaddr_MEM[`DMEMADDRBITS-1:`DMEMWORDBITS]] : wr_val_MEM;



    // Write to D-MEM
    always @ (posedge clk)
    begin
        if (wr_mem_MEM)
            dmem[memaddr_MEM[`DMEMADDRBITS-1:`DMEMWORDBITS]] <= wr_val_MEM;
    end

    assign from_MEM_to_DE = rd_MEM;

    assign MEM_latch_out = MEM_latch;

    assign {
            inst_MEM,
            PC_MEM,
            op_I_MEM,
            inst_count_MEM,
            wr_val_MEM,
            memaddr_MEM,
            rd_MEM,
            bus_canary_MEM
        } = from_AGEX_latch;



    assign MEM_latch_contents = {
               inst_MEM,
               PC_MEM,
               op_I_MEM,
               inst_count_MEM,
               rd_val_MEM,
               rd_MEM,
               bus_canary_MEM
           };

    always @ (posedge clk)
    begin
        if (reset)
            MEM_latch <= {`MEM_latch_WIDTH{1'b0}};
        else
            MEM_latch <= MEM_latch_contents;
    end

endmodule

`include "define.vh"

module AGEX_STAGE(
        input  wire                               clk,
        input  wire                               reset,
        input  wire [`from_MEM_to_AGEX_WIDTH-1:0] from_MEM_to_AGEX,
        input  wire [`from_WB_to_AGEX_WIDTH-1:0]  from_WB_to_AGEX,
        input  wire [`DE_latch_WIDTH-1:0]         from_DE_latch,
        output wire [`AGEX_latch_WIDTH-1:0]       AGEX_latch_out,
        output wire [`from_AGEX_to_FE_WIDTH-1:0]  from_AGEX_to_FE,
        output wire [`from_AGEX_to_DE_WIDTH-1:0]  from_AGEX_to_DE
    );

    reg [`AGEX_latch_WIDTH-1:0] AGEX_latch;
    assign AGEX_latch_out = AGEX_latch;

    wire[`AGEX_latch_WIDTH-1:0] AGEX_latch_contents;

    wire [`INSTBITS-1:0] inst_AGEX;
    wire [`DBITS-1:0] PC_AGEX;
    wire [`DBITS-1:0] inst_count_AGEX;
    wire [`DBITS-1:0] pcplus_AGEX;
    wire [`DBITS-1:0] rs1_val_AGEX;
    wire [`DBITS-1:0] rs2_val_AGEX;
    wire [`DBITS-1:0] sxt_imm_AGEX;
    wire [`REGNOBITS-1:0] rd_AGEX;
    wire [`IOPBITS-1:0] op_I_AGEX;
    reg [`DBITS-1:0] alu_out;
    reg br_cond_AGEX; // true (1) if should take branch

    wire[`BUS_CANARY_WIDTH-1:0] bus_canary_AGEX;


    // evaluate branch conditions
    always @ (*)
    begin
        case (op_I_AGEX)
            `BEQ_I :
                br_cond_AGEX = rs1_val_AGEX == rs2_val_AGEX;
            default :
                br_cond_AGEX = 1'b0;
        endcase
    end

    // compute ALU operations  (alu out or memory addresses)
    always @ (*)
    begin
        case (op_I_AGEX)
            `ADD_I:
                alu_out = rs1_val_AGEX + rs2_val_AGEX;
            `ADDI_I:
                alu_out = rs1_val_AGEX + sxt_imm_AGEX;
            `BEQ_I:
                alu_out = PC_AGEX + sxt_imm_AGEX;
            default:
                alu_out = 0;
        endcase
    end

    assign  {
            inst_AGEX,
            PC_AGEX,
            pcplus_AGEX,
            op_I_AGEX,
            inst_count_AGEX,
            rs1_val_AGEX,
            rs2_val_AGEX,
            sxt_imm_AGEX,
            rd_AGEX,
            bus_canary_AGEX
        } = from_DE_latch;

    assign AGEX_latch_contents = {
               inst_AGEX,
               PC_AGEX,
               op_I_AGEX,
               inst_count_AGEX,
               alu_out,
               rd_AGEX,
               bus_canary_AGEX
           };

    assign from_AGEX_to_DE = {br_cond_AGEX, rd_AGEX};
    assign from_AGEX_to_FE = {br_cond_AGEX, alu_out};

    always @ (posedge clk)
    begin
        if (reset)
            AGEX_latch <= {`AGEX_latch_WIDTH{1'b0}};
        else
            AGEX_latch <= AGEX_latch_contents;
    end

endmodule

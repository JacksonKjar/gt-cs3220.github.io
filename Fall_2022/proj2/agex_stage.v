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
    wire signed [`DBITS-1:0] srs1_val_AGEX;
    wire signed [`DBITS-1:0] srs2_val_AGEX;
    wire signed [`DBITS-1:0] ssxt_imm_AGEX;
    wire [`REGNOBITS-1:0] rd_AGEX;
    wire [`IOPBITS-1:0] op_I_AGEX;
    reg [`DBITS-1:0] alu_out;
    reg [`DBITS-1:0] address;
    reg br_cond_AGEX; // true (1) if should take branch

    wire[`BUS_CANARY_WIDTH-1:0] bus_canary_AGEX;

    assign srs1_val_AGEX = rs1_val_AGEX;
    assign srs2_val_AGEX = rs2_val_AGEX;
    assign ssxt_imm_AGEX = sxt_imm_AGEX;

    wire is_br = op_I_AGEX == `BEQ_I
        || op_I_AGEX == `BNE_I
        || op_I_AGEX == `BLTU_I
        || op_I_AGEX == `BGEU_I
        || op_I_AGEX == `BLT_I
        || op_I_AGEX == `BGE_I
        || op_I_AGEX == `JALR_I
        || op_I_AGEX == `JAL_I;

    // evaluate branch conditions
    always @ (*)
    begin
        case (op_I_AGEX)
            `BEQ_I :
                br_cond_AGEX = rs1_val_AGEX == rs2_val_AGEX;
            `BNE_I:
                br_cond_AGEX = rs1_val_AGEX != rs2_val_AGEX;
            `BLTU_I:
                br_cond_AGEX = rs1_val_AGEX < rs2_val_AGEX;
            `BGEU_I:
                br_cond_AGEX = rs1_val_AGEX >= rs2_val_AGEX;
            `BLT_I:
                br_cond_AGEX = srs1_val_AGEX < srs2_val_AGEX;
            `BGE_I:
                br_cond_AGEX = srs1_val_AGEX >= srs2_val_AGEX;
            `JAL_I:
                br_cond_AGEX = 1;
            `JALR_I:
                br_cond_AGEX = 1;
            default:
                br_cond_AGEX = 1'b0;
        endcase
    end

    // compute ALU operations  (alu out or memory addresses)
    always @ (*)
    begin
        alu_out = 0;
        address = 0;
        case (op_I_AGEX)
            `ADD_I:
                alu_out = rs1_val_AGEX + rs2_val_AGEX;
            `SUB_I:
                alu_out = rs1_val_AGEX - rs2_val_AGEX;
            `AND_I:
                alu_out = rs1_val_AGEX & rs2_val_AGEX;
            `OR_I:
                alu_out = rs1_val_AGEX | rs2_val_AGEX;
            `XOR_I:
                alu_out = rs1_val_AGEX ^ rs2_val_AGEX;
            `SLT_I:
                alu_out = {{31{1'b0}}, srs1_val_AGEX < srs2_val_AGEX};
            `SLTU_I:
                alu_out = {{31{1'b0}}, rs1_val_AGEX < rs2_val_AGEX};
            `SRA_I:
                alu_out = srs1_val_AGEX >>> rs2_val_AGEX[4:0];
            `SRL_I:
                alu_out = rs1_val_AGEX >> rs2_val_AGEX[4:0];
            `SLL_I:
                alu_out = rs1_val_AGEX << rs2_val_AGEX[4:0];
            `MUL_I:
                alu_out = srs1_val_AGEX * srs2_val_AGEX[4:0];

            `ADDI_I:
                alu_out = rs1_val_AGEX + sxt_imm_AGEX;
            `ANDI_I:
                alu_out = rs1_val_AGEX & sxt_imm_AGEX;
            `ORI_I:
                alu_out = rs1_val_AGEX | sxt_imm_AGEX;
            `XORI_I:
                alu_out = rs1_val_AGEX ^ sxt_imm_AGEX;
            `SLTI_I:
                alu_out = {{31{1'b0}}, srs1_val_AGEX < ssxt_imm_AGEX};
            `SLTIU_I:
                alu_out = {{31{1'b0}}, rs1_val_AGEX < sxt_imm_AGEX};
            `SRAI_I:
                alu_out = srs1_val_AGEX >>> sxt_imm_AGEX[4:0];
            `SRLI_I:
                alu_out = rs1_val_AGEX >> sxt_imm_AGEX[4:0];
            `SLLI_I:
                alu_out = rs1_val_AGEX << sxt_imm_AGEX[4:0];
            `LUI_I:
                alu_out = sxt_imm_AGEX;
            `AUIPC_I:
                alu_out = PC_AGEX + sxt_imm_AGEX;

            `LW_I:
                address = rs1_val_AGEX + sxt_imm_AGEX;
            `SW_I:
            begin
                alu_out = rs2_val_AGEX;
                address = rs1_val_AGEX + sxt_imm_AGEX;
            end

            `JAL_I:
            begin
                alu_out = pcplus_AGEX;
                address = PC_AGEX + sxt_imm_AGEX;
            end
            `JALR_I:
            begin
                alu_out = pcplus_AGEX;
                address = {rs1_val_AGEX + sxt_imm_AGEX} & -2;
            end

            `BEQ_I:
                address = PC_AGEX + sxt_imm_AGEX;
            `BNE_I:
                address = PC_AGEX + sxt_imm_AGEX;
            `BLT_I:
                address = PC_AGEX + sxt_imm_AGEX;
            `BGE_I:
                address = PC_AGEX + sxt_imm_AGEX;
            `BLTU_I:
                address = PC_AGEX + sxt_imm_AGEX;
            `BGEU_I:
                address = PC_AGEX + sxt_imm_AGEX;
        endcase
    end

    wire [7:0] pht_index;
    wire [`DBITS-1:0] predicted_pc;

    assign  {
            inst_AGEX,
            PC_AGEX,
            pcplus_AGEX,
            pht_index,
            predicted_pc,
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
               address,
               rd_AGEX,
               bus_canary_AGEX
           };

    wire [`DBITS-1:0] br_pc = br_cond_AGEX ? address : pcplus_AGEX;
    wire misprediction = predicted_pc != br_pc;
    assign from_AGEX_to_DE = {misprediction, rd_AGEX};
    assign from_AGEX_to_FE = {
        is_br,
        misprediction,
        br_cond_AGEX,
        address,
        pcplus_AGEX,
        PC_AGEX,
        pht_index
        };

    always @ (posedge clk)
    begin
        if (reset)
            AGEX_latch <= {`AGEX_latch_WIDTH{1'b0}};
        else
            AGEX_latch <= AGEX_latch_contents;
    end

endmodule

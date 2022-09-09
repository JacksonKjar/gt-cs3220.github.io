module bubblesort (
    input wire clk,
    input wire reset,     
    input wire rd_en, 
    output wire [15:0] dat_out0,
    output wire [15:0] dat_out1,
    output wire [15:0] dat_out2,
    output wire [15:0] dat_out3,
    output wire [15:0] dat_out4,
    output wire [15:0] dat_out5,
    output wire [15:0] dat_out6,
    output wire [15:0] dat_out7,
    output wire [15:0] dat_out8,
    output wire [15:0] dat_out9,
    output wire done
); 
 
  	reg [15:0] dmem [9:0];

    assign dat_out0 = dmem[0];
    assign dat_out1 = dmem[1];
    assign dat_out2 = dmem[2];
    assign dat_out3 = dmem[3];
    assign dat_out4 = dmem[4];
    assign dat_out5 = dmem[5];
    assign dat_out6 = dmem[6];
    assign dat_out7 = dmem[7];
    assign dat_out8 = dmem[8];
    assign dat_out9 = dmem[9];   
    
    /*
        please consider dmem as memory from wich you will read values.
    */
    initial begin
        $readmemh("ex1.mem", dmem);
    end
  
    parameter mem_size = 10;
  	parameter init = 0;
    parameter bubbling = 1;
    parameter restarting = 2;
    parameter complete = 3;

    reg [1:0] state;
    reg [15:0] prev;
    reg [9:0] addr;
    reg sorted;
  
    assign done = state == complete;

    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= init;
        else
            case (state)
                init: begin
                    prev <= dmem[0];
                    addr <= 1;
                    sorted <= 1;
                    state <= bubbling;
                end
                bubbling: begin
                    if (prev > dmem[addr]) begin
                        sorted <= 0;
                        dmem[addr - 1] <= dmem[addr];
                    end else begin
                        prev <= dmem[addr];
                        dmem[addr - 1] <= prev;
                    end

                    if (addr < mem_size - 1)
                        addr <= addr + 1;
                    else
                        state <= restarting;
                end
                restarting: begin
                    dmem[addr] <= prev;
                    prev <= dmem[0];
                    addr <= 1;
                    sorted <= 1;
                    state <= sorted ? complete : bubbling;
                end
            endcase
    end

endmodule

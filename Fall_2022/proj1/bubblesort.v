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
    
    // Initialize the memory
    initial begin
        $readmemh("ex1.mem", dmem);
    end
    
    reg         m_we;   // write enable
    reg [3:0]   m_wa;   // write address
    reg [3:0]   m_ra;   // read address
    reg [15:0]  m_din;  // input data
    wire [15:0] m_dout; // output data
    
    // Dual-port RAM with asynchronous read
    always @(posedge clk) begin
        if (m_we) begin
            dmem[m_wa] <= m_din;    
        end       
    end
    assign m_dout = dmem[m_ra];
  
    // Sorting circuit implementation

    // uncomment the following line for debugging
    // initial $monitor($time, ": clk=%b, reset=%b, rd_en=%b, done=%b, m_ra=%0h, m_wa=%0h, m_we=%b, m_din=%0h, m_dout=%0h", clk, reset, rd_en, done, m_ra, m_wa, m_we, m_din, m_dout);

    parameter mem_size = 10;

  	parameter init0 = 0;
  	parameter init1 = 1;
    parameter bubbling = 2;
    parameter restarting = 3;
    parameter completing = 4;
    parameter complete = 5;

    reg [2:0] state;
    reg [15:0] prev;
    reg sorted;
  
    assign done = state == complete;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            m_we <= 0;
            state <= init0;
        end else
            case (state)
                init0: begin
                    // init takes 2 cycles b/c need to set ra before reading dout
                    m_we <= 0;
                    m_ra <= 0;
                    state <= init1;
                end
                init1: begin
                    prev <= m_dout;
                    sorted <= 1;
                    m_ra <= 1;
                    state <= bubbling;
                end
                bubbling: begin
                    m_we <= 1;
                    m_wa <= m_ra - 1;
                    if (prev > m_dout) begin
                        sorted <= 0;
                        m_din <= m_dout;
                    end else begin
                        prev <= m_dout;
                        m_din <= prev;
                    end

                    if (m_ra < mem_size - 1)
                        m_ra <= m_ra + 1;
                    else begin
                        m_ra <= 0;
                        state <= restarting;
                    end
                end
                restarting: begin
                    m_we <= 1;
                    m_wa <= mem_size - 1;
                    m_din <= prev;

                    prev <= m_dout;
                    sorted <= 1;
                    m_ra <= 1;
                    state <= sorted ? completing : bubbling;
                end
                completing: begin
                    // need an extra clock cycle for mem write to finish
                    m_we <= 0;
                    state <= complete;
                end
            endcase
    end

endmodule

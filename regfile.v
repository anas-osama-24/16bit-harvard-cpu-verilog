module regfile(
    input clk,
    input we,
    input [2:0] waddr, // DR
    input [15:0] wdata, 
    input [2:0] raddr_a, // SA
    input [2:0] raddr_b, // SB
    output [15:0] rdata_a,
    output [15:0] rdata_b
);
    reg [15:0] regs [0:7];
    integer i;
    initial for (i = 0; i < 8; i = i + 1) regs[i] = 16'd0;

    always @(posedge clk)
        if (we) regs[waddr] <= wdata;

    assign rdata_a = regs[raddr_a];
    assign rdata_b = regs[raddr_b];
endmodule
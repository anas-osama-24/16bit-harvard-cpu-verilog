module dmem(
    input clk,
    input we,
    input [7:0] addr,
    input [15:0] wdata,
    output [15:0] rdata
);
    reg [15:0] mem [0:255];
    integer i;
    initial for (i = 0; i < 256; i = i + 1) mem[i] = 16'd0;

    always @(posedge clk)
        if (we) mem[addr] <= wdata;

    assign rdata = mem[addr];
endmodule
module pc(
    input clk,
    input rst,
    input halt,
    input load,
    input [7:0] load_val,
    output reg [7:0] pc_out
);
    always @(posedge clk) begin
        if (rst)
            pc_out <= 8'd0;
        else if (!halt)
            pc_out <= load ? load_val : pc_out + 8'd1;
    end
endmodule
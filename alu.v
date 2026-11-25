module alu(
    input [3:0] fs,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] result,
    output reg carry,
    output reg overflow
);
    reg [16:0] t;

    always @(*) begin
        carry    = 1'b0;
        overflow = 1'b0;
        t        = 17'd0;
        case (fs)
            4'b0000: result = a;
            4'b0001: begin                          // INC
                t        = {1'b0, a} + 17'd1;
                result   = t[15:0];
                carry    = t[16];
                overflow = ~a[15] & result[15];
            end
            4'b0010: begin                          // ADD, ADI
                t        = {1'b0, a} + {1'b0, b};
                result   = t[15:0];
                carry    = t[16];
                overflow = (a[15] == b[15]) & (result[15] != a[15]);
            end
            4'b0101: begin                          // SUB
                t        = {1'b0, a} - {1'b0, b};
                result   = t[15:0];
                carry    = t[16];                   // 1 = borrow (a < b unsigned)
                overflow = (a[15] != b[15]) & (result[15] != a[15]);
            end
            4'b0110: begin                          // DEC
                t        = {1'b0, a} - 17'd1;
                result   = t[15:0];
                carry    = t[16];
                overflow = a[15] & ~result[15];
            end
            4'b1000: result = a & b;
            4'b1001: result = a | b;
            4'b1010: result = a ^ b;
            4'b1011: result = ~a;
            4'b1100: result = b;
            4'b1101: result = b >> 1;
            4'b1110: result = b << 1;
            default: result = 16'd0;
        endcase
    end
endmodule
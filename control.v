module control(
    input [6:0] op,
    output reg reg_write,
    output reg mem_write,
    output reg mem_to_reg,
    output reg use_imm,
    output reg update_flags,
    output reg branch_z,
    output reg branch_n,
    output reg jump,
    output reg halt
);
    always @(*) begin
        reg_write    = 0;
        mem_write    = 0;
        mem_to_reg   = 0;
        use_imm      = 0;
        update_flags = 0;
        branch_z     = 0;
        branch_n     = 0;
        jump         = 0;
        halt         = 0;

        case (op)
            // MOVA INC ADD SUB DEC AND OR XOR NOT MOVB SHR SHL
            7'b0000000, 7'b0000001, 7'b0000010, 7'b0000101,
            7'b0000110, 7'b0001000, 7'b0001001, 7'b0001010,
            7'b0001011,7'b0001100, 7'b0001101, 7'b0001110: begin
                reg_write    = 1;
                update_flags = 1;
            end
            // LDI: R[DR] = zf(OP)
            7'b1001100: begin reg_write = 1; use_imm = 1; end
            // ADI: R[DR] = R[SA] + zf(OP)
            7'b1000010: begin
                reg_write    = 1;
                use_imm      = 1;
                update_flags = 1;
            end
            // LD
            7'b0010000: begin reg_write = 1; mem_to_reg = 1; end
            // ST
            7'b0100000: mem_write = 1;
            // BRZ, BRN, JMP
            7'b1100000: branch_z = 1;
            7'b1100001: branch_n = 1;
            7'b1110000: jump = 1;
            // HALT and unknown opcodes
            7'b1111111: halt = 1;
            default:    halt = 1;
        endcase
    end
endmodule
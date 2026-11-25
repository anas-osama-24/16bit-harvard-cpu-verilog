module tb_trace;
    reg clk = 0, rst = 1;
    wire halt;

    cpu #(
        .PROGRAM_FILE("test_program.hex"),
        .PROG_WORDS(72)
    ) dut(.clk(clk), .rst(rst), .halt(halt));

    always #5 clk = ~clk;

    reg [7:0]  last_pc;
    reg [15:0] last_instr;

    function [39:0] mnem;
        input [6:0] op;
        begin
            case (op)
                7'h00: mnem = "MOVA ";
                7'h01: mnem = "INC  ";
                7'h02: mnem = "ADD  ";
                7'h05: mnem = "SUB  ";
                7'h06: mnem = "DEC  ";
                7'h08: mnem = "AND  ";
                7'h09: mnem = "OR   ";
                7'h0A: mnem = "XOR  ";
                7'h0B: mnem = "NOT  ";
                7'h0C: mnem = "MOVB ";
                7'h0D: mnem = "SHR  ";
                7'h0E: mnem = "SHL  ";
                7'h4C: mnem = "LDI  ";
                7'h42: mnem = "ADI  ";
                7'h10: mnem = "LD   ";
                7'h20: mnem = "ST   ";
                7'h60: mnem = "BRZ  ";
                7'h61: mnem = "BRN  ";
                7'h70: mnem = "JMP  ";
                7'h7F: mnem = "HALT ";
                default: mnem = "???  ";
            endcase
        end
    endfunction

    // remember the instruction that is executing at this clock edge
    always @(posedge clk) begin
        last_pc    <= dut.pc_val;
        last_instr <= dut.instr;
    end

    // print the state after it finished
    always @(negedge clk) if (!rst && last_instr !== 16'bx) begin
        $display("| %0d | %h | %0s | %0d | %0d | %0d | %0d | %0d | %0d | %0d | %0d | %b%b%b%b |",
                 last_pc, last_instr, mnem(last_instr[15:9]),
                 dut.u_rf.regs[0], dut.u_rf.regs[1], dut.u_rf.regs[2], dut.u_rf.regs[3],
                 dut.u_rf.regs[4], dut.u_rf.regs[5], dut.u_rf.regs[6], dut.u_rf.regs[7],
                 dut.c_flag, dut.v_flag, dut.n_flag, dut.z_flag);
        if (last_instr[15:9] == 7'h7F) $finish;
    end

    initial begin
        $display("| PC | Instr | Op | R0 | R1 | R2 | R3 | R4 | R5 | R6 | R7 | CVNZ |");
        $display("|---|---|---|---|---|---|---|---|---|---|---|---|");
        #12 rst = 0;
    end

    initial begin
        #10000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
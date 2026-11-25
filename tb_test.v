module tb_test;
    reg clk = 0, rst = 1;
    wire halt;
    integer errors = 0;
    reg [255:0] seen = 0;

    cpu #(
        .PROGRAM_FILE("test_program.hex"),
        .PROG_WORDS(72)
    ) dut(.clk(clk), .rst(rst), .halt(halt));

    always #5 clk = ~clk;

    task check;
        input [15:0] got;
        input [15:0] exp;
        input [80:0] name;
        begin
            if (got !== exp) begin
                $display("FAIL %0s: got %0d, expected %0d", name, got, exp);
                errors = errors + 1;
            end
        end
    endtask

    // Flags are {C, V, N, Z}. At pc = k, instruction k-1 has finished.
    task chk_flags;
        input [7:0] pc;
        input [3:0] exp;
        begin
            if (dut.u_pc.pc_out == pc && !seen[pc]) begin
                seen[pc] = 1;
                if ({dut.c_flag, dut.v_flag, dut.n_flag, dut.z_flag} !== exp) begin
                    $display("FAIL flags at pc=%0d: CVNZ=%b%b%b%b expected %b",
                             pc, dut.c_flag, dut.v_flag, dut.n_flag, dut.z_flag, exp);
                    errors = errors + 1;
                end
            end
        end
    endtask

    always @(negedge clk) if (!rst) begin
        chk_flags(8'd2,  4'b1010);  // DEC 0             : borrow, negative
        chk_flags(8'd4,  4'b1001);  // ADD 65535 + 1     : carry, zero
        chk_flags(8'd5,  4'b1000);  // SUB 1 - 65535     : borrow
        chk_flags(8'd6,  4'b0010);  // SUB 65535 - 1     : negative only
        chk_flags(8'd7,  4'b0000);  // SHR 32767         : flags updated
        chk_flags(8'd8,  4'b0110);  // INC 32767         : signed overflow
        chk_flags(8'd9,  4'b0110);  // ADD 32767 + 1     : signed overflow
        chk_flags(8'd10, 4'b1110);  // SUB 32767 - 65535 : borrow and overflow
        chk_flags(8'd11, 4'b0100);  // DEC 32768         : signed overflow
        chk_flags(8'd12, 4'b1001);  // INC 65535         : carry, zero

        // Shifts and MOVB update the flags (C and V always 0 for them)
        chk_flags(8'd63, 4'b0000);  // SHL 5 -> 10       : Z cleared
        chk_flags(8'd64, 4'b0001);  // SUB 10 - 10       : zero
        chk_flags(8'd65, 4'b0000);  // MOVB 5            : Z cleared
        chk_flags(8'd66, 4'b0001);  // MOVB 0            : Z set
        chk_flags(8'd68, 4'b1010);  // DEC 0             : borrow, negative
        chk_flags(8'd69, 4'b0010);  // SHL 65535         : C cleared, negative
        chk_flags(8'd70, 4'b0001);  // SUB 10 - 10       : zero
        chk_flags(8'd71, 4'b0010);  // MOVB 65535        : negative

        // State of the main program, sampled before the shift/MOVB tail
        if (dut.u_pc.pc_out == 8'd61 && !seen[61]) begin
            seen[61] = 1;
            check(dut.u_rf.regs[0], 16'd7,  "R0 canary");
            check(dut.u_rf.regs[1], 16'd0,  "R1");
            check(dut.u_rf.regs[2], 16'd6,  "R2");
            check(dut.u_rf.regs[3], 16'd14, "R3");
            check(dut.u_rf.regs[4], 16'd1,  "R4");
            check(dut.u_rf.regs[5], 16'd0,  "R5");
            check(dut.u_rf.regs[6], 16'd59, "R6");
            check(dut.u_rf.regs[7], 16'd14, "R7");
            check(dut.u_dmem.mem[5], 16'd14, "M5");
            check(dut.u_dmem.mem[6], 16'd19, "M6");
            check(dut.z_flag,        16'd1,  "Z flag at pc 61");
        end
    end

    initial begin
        $dumpfile("wave_test.vcd");
        $dumpvars(0, tb_test);

        #12 rst = 0;
        wait (halt);
        #10;

        $display("--- test_program.hex results ---");
        $display("R0=%0d R1=%0d R2=%0d R3=%0d R4=%0d R5=%0d R6=%0d R7=%0d",
                 dut.u_rf.regs[0], dut.u_rf.regs[1], dut.u_rf.regs[2],
                 dut.u_rf.regs[3], dut.u_rf.regs[4], dut.u_rf.regs[5],
                 dut.u_rf.regs[6], dut.u_rf.regs[7]);
        $display("M5=%0d M6=%0d PC=%0d C=%0d V=%0d N=%0d Z=%0d",
                 dut.u_dmem.mem[5], dut.u_dmem.mem[6], dut.u_pc.pc_out,
                 dut.c_flag, dut.v_flag, dut.n_flag, dut.z_flag);

        check(dut.u_rf.regs[0], 16'd7,     "R0 canary");
        check(dut.u_rf.regs[1], 16'd10,    "R1 final");
        check(dut.u_rf.regs[2], 16'd5,     "R2 final");
        check(dut.u_rf.regs[3], 16'd0,     "R3 final");
        check(dut.u_rf.regs[4], 16'd5,     "R4 final");
        check(dut.u_rf.regs[5], 16'd65535, "R5 final");
        check(dut.u_rf.regs[6], 16'd65535, "R6 final");
        check(dut.u_rf.regs[7], 16'd65534, "R7 final");

        check(dut.u_dmem.mem[5], 16'd14, "M5");
        check(dut.u_dmem.mem[6], 16'd19, "M6");
        check(dut.u_pc.pc_out,   8'd71,  "PC at HALT");
        check(dut.c_flag,        16'd0,  "C flag");
        check(dut.v_flag,        16'd0,  "V flag");
        check(dut.n_flag,        16'd1,  "N flag");
        check(dut.z_flag,        16'd0,  "Z flag");

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

    initial begin
        #10000;
        $display("TIMEOUT at PC=%0d", dut.u_pc.pc_out);
        $finish;
    end
endmodule
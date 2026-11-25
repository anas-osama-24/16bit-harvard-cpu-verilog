module cpu #(
    parameter PROGRAM_FILE = "program.hex",
    parameter PROG_WORDS   = 8
)(
    input clk,
    input rst,
    output halt
);
    wire [7:0]  pc_val;
    wire [15:0] instr;

    // Register format: opcode | DR | SA | SB
    wire [6:0] op = instr[15:9];
    wire [2:0] dr = instr[8:6];
    wire [2:0] sa = instr[5:3];
    wire [2:0] sb = instr[2:0];

    wire reg_write, mem_write, mem_to_reg, use_imm, update_flags;
    wire branch_z, branch_n, jump;

    wire [15:0] a_val, b_val, alu_b, alu_out, mem_out, wr_data;
    wire alu_c, alu_v;

    reg n_flag, z_flag, c_flag, v_flag;

    // Immediate format: OP = instr[2:0], zero-extended
    wire [15:0] imm_val = {13'd0, sb};

    assign alu_b   = use_imm ? imm_val : b_val;
    assign wr_data = mem_to_reg ? mem_out : alu_out;

    // Jump and branch format: AD = {instr[8:6], instr[2:0]}, signed 6 bit
    wire [5:0] ad            = {instr[8:6], instr[2:0]};
    wire [7:0] branch_target = pc_val + {{2{ad[5]}}, ad};
    wire [7:0] target        = jump ? a_val[7:0] : branch_target;

    // BRZ and BRN test R[SA] directly
    wire take = jump
              | (branch_z & (a_val == 16'd0))
              | (branch_n & a_val[15]);

    always @(posedge clk) begin
        if (rst) begin
            n_flag <= 0;
            z_flag <= 0;
            c_flag <= 0;
            v_flag <= 0;
        end else if (update_flags) begin
            n_flag <= alu_out[15];
            z_flag <= (alu_out == 16'd0);
            c_flag <= alu_c;
            v_flag <= alu_v;
        end
    end

    pc u_pc(
        .clk(clk), .rst(rst), .halt(halt),
        .load(take), .load_val(target),
        .pc_out(pc_val)
    );

    imem #(
        .PROGRAM_FILE(PROGRAM_FILE),
        .PROG_WORDS(PROG_WORDS)
    ) u_imem(.addr(pc_val), .instr(instr));

    control u_ctrl(
        .op(op),
        .reg_write(reg_write), .mem_write(mem_write),
        .mem_to_reg(mem_to_reg), .use_imm(use_imm),
        .update_flags(update_flags),
        .branch_z(branch_z), .branch_n(branch_n),
        .jump(jump), .halt(halt)
    );

    regfile u_rf(
        .clk(clk), .we(reg_write),
        .waddr(dr), .wdata(wr_data),
        .raddr_a(sa), .raddr_b(sb),
        .rdata_a(a_val), .rdata_b(b_val)
    );

    alu u_alu(
        .fs(op[3:0]), .a(a_val), .b(alu_b),
        .result(alu_out), .carry(alu_c), .overflow(alu_v)
    );

    dmem u_dmem(
        .clk(clk), .we(mem_write),
        .addr(a_val[7:0]), .wdata(b_val),
        .rdata(mem_out)
    );
endmodule
module imem #(
    parameter PROGRAM_FILE = "program.hex",
    parameter PROG_WORDS   = 8
)(
    input [7:0] addr,
    output [15:0] instr
);
    reg [15:0] mem [0:255];
    integer i;

    initial begin
        // Fill unused ROM with HALT so a runaway PC stops immediately.
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 16'hFE00;

        // Load only the words that exist; avoids the under-fill warning.
        $readmemh(PROGRAM_FILE, mem, 0, PROG_WORDS - 1);
    end

    assign instr = mem[addr];
endmodule
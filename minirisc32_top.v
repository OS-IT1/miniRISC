// Assignment 6 autonomous processor interface.
// Execution starts at word address zero after reset is released.
module minirisc32_top (
    input  wire        clk,
    input  wire        reset,
    output wire        done,
    output wire [31:0] result_out
);
    wire [31:0] unused_pc;
    wire [31:0] unused_instruction;
    wire halted;
    wire [31:0] core_result;

    minirisc_basic_top core (
        .clk        (clk),
        .rst        (reset),
        .pc         (unused_pc),
        .instruction(unused_instruction),
        .halted     (halted),
        .result_out (core_result)
    );

    assign done = halted;
    assign result_out = core_result;
endmodule

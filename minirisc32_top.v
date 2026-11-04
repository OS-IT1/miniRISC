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

    // Internal reset. It powers up asserted (INIT = 1) and is held for four
    // clock edges after the reset input is low AND the global set/reset (GSR)
    // of the implemented netlist has finished.
    //  - GSR holds every flip-flop at INIT for the first 100 ns of a timing
    //    simulation, so a shorter reset pulse on the port would otherwise be
    //    lost and the core would never be reset.
    //  - The clock edges inside reset let the synchronous instruction BRAM
    //    read word 0, so the first instruction is not skipped.
    //  - The core reset is driven by a flip-flop, so its large fanout is
    //    covered by the clock constraint and releases on a clock edge.
    reg [3:0] reset_pipe = 4'b1111;
    always @(posedge clk) begin
        if (reset)
            reset_pipe <= 4'b1111;
        else
            reset_pipe <= {reset_pipe[2:0], 1'b0};
    end
    wire core_reset = reset_pipe[3];

    minirisc_basic_top core (
        .clk        (clk),
        .rst        (core_reset),
        .pc         (unused_pc),
        .instruction(unused_instruction),
        .halted     (halted),
        .result_out (core_result)
    );

    assign done = halted;
    assign result_out = core_result;
endmodule

`timescale 1ns/1ps

// Same testbench for behavioral and post-implementation timing simulation.
module tb_minirisc_autonomous;
    // Must match the period in minirisc_assignment6.xdc.
    parameter real CLK_PERIOD = 20.0;  // ns

    reg clk;
    reg reset;
    wire done;
    wire [31:0] result_out;
`ifdef RTL_DEBUG_PROBES
    // Enable only for behavioral simulation. Synthesis can flatten or rename
    // these internal signals, so they are excluded by default for netlist runs.
    wire [31:0] pc;
    wire [31:0] instruction;
    wire [31:0] r3;

    // Waveform probes: PC is a byte address; display instruction in hex.
    assign pc = dut.core.pc;
    assign instruction = dut.core.instruction;
    assign r3 = dut.core.rf.registers[3];
`endif

    minirisc32_top dut (
        .clk (clk),
        .reset (reset),
        .done (done),
        .result_out (result_out)
    );

    initial
        clk = 1'b0;
    always #(CLK_PERIOD/2.0) clk = ~clk;

    initial begin
        reset = 1'b1;
        // Hold reset beyond the 100 ns GSR pulse of the implemented netlist
        // and release it on a falling edge, away from the active clock edge.
        repeat (10) @(negedge clk);
        reset = 1'b0;

        wait(done == 1'b1);

        if (result_out == 32'h00000064)
            $display("PASS: result = %h", result_out);
        else
            $display("FAIL: result = %h", result_out);

        // Keep running briefly to verify stable HALT behavior
        #(10*CLK_PERIOD);
        if (done === 1'b1 && result_out === 32'h00000064)
            $display("PASS: done and result_out stable after HALT");
        else
            $display("FAIL: after HALT done = %b, result = %h", done, result_out);
        $finish;
    end

    // Stops the run with a clear message if done never rises.
    initial begin
        #(500*CLK_PERIOD);
        $display("FAIL: done did not rise, done = %b, result = %h", done, result_out);
        $finish;
    end
endmodule

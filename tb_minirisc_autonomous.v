`timescale 1ns/1ps

module tb_minirisc_autonomous;
    reg clk;
    reg reset;
    wire done;
    wire [31:0] result_out;
`ifdef RTL_DEBUG_PROBES
    // Enable only for behavioral simulation. Synthesis can flatten or rename
    // these internal signals, so they are excluded by default for netlist runs.
    wire [31:0] pc;
    wire [31:0] instruction;

    // Waveform probes: PC is a byte address; display instruction in hex.
    assign pc = dut.core.pc;
    assign instruction = dut.core.instruction;
`endif

    minirisc32_top dut (
        .clk (clk),
        .reset (reset),
        .done (done),
        .result_out (result_out)
    );

    initial
        clk = 1'b0;
    always #5 clk = ~clk; // Example: 100 MHz

    initial begin
        reset = 1'b1;
        #50;
        reset = 1'b0;
        wait(done == 1'b1);
        if (result_out == 32'h00000064)
            $display("PASS: result = %h", result_out);
        else
            $display("FAIL: result = %h", result_out);

        // Keep running briefly to verify stable HALT behavior
        #100;
        $finish;
    end
endmodule

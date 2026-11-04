`timescale 1ns/1ps

// Use with the Vivado post-implementation timing netlist and glbl module.
module tb_minirisc_autonomous_timing;
    parameter real CLK_PERIOD = 20.0; // Match minirisc_assignment6.xdc.
    reg clk = 1'b0;
    reg reset = 1'b1;
    wire done;
    wire [127:0] result_matrix;
    integer cycles = 0;

    minirisc32_top dut (
        .clk(clk), .reset(reset), .done(done), .result_matrix(result_matrix)
    );
    always #(CLK_PERIOD/2.0) clk = ~clk;

    initial begin
        $dumpfile("minirisc_matrix_timing.vcd");
        $dumpvars(0, tb_minirisc_autonomous_timing);
        // Keep reset active beyond the 100 ns global set/reset interval.
        repeat (10) @(negedge clk);
        reset = 1'b0;

        while (done !== 1'b1 && cycles < 500) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (done !== 1'b1)
            $fatal(1, "Timing simulation did not reach HALT");
        if (result_matrix !== {32'd50,32'd43,32'd22,32'd19})
            $fatal(1, "Timing simulation matrix mismatch: %032h", result_matrix);
        repeat (10) begin
            @(negedge clk);
            if (done !== 1'b1 || result_matrix !== {32'd50,32'd43,32'd22,32'd19})
                $fatal(1, "Timing simulation outputs changed after HALT");
        end
        $display("PASS: timing simulation matrix = [[19,22],[43,50]]");
        $finish;
    end
endmodule

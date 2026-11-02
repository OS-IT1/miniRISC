`timescale 1ns/1ps

// Use this same top-level testbench against the post-implementation timing
// simulation model. Keep the 10 ns clock period used by the XDC constraint.
module tb_minirisc_autonomous_timing;
    reg clk = 1'b0;
    reg reset = 1'b1;
    wire done;
    wire [31:0] result_out;
    integer cycles = 0;

    minirisc32_top dut (
        .clk(clk), .reset(reset), .done(done), .result_out(result_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("minirisc_autonomous_timing.vcd");
        $dumpvars(0, tb_minirisc_autonomous_timing);
        repeat (5) @(negedge clk);
        reset = 1'b0;
        while (done !== 1'b1 && cycles < 200) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
        end
        if (done !== 1'b1)
            $fatal(1, "Timing simulation did not reach HALT within 200 cycles");
        if (result_out !== 32'h00000064)
            $fatal(1, "Timing simulation expected result 00000064, got %08h", result_out);

        repeat (5) begin
            @(posedge clk);
            #1;
            if (done !== 1'b1 || result_out !== 32'h00000064)
                $fatal(1, "done/result_out changed after HALT");
        end
        $display("PASS: timing model done=%b result_out=%08h", done, result_out);
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Timing simulation watchdog timeout");
    end
endmodule

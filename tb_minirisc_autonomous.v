`timescale 1ns/1ps

// Behavioral Assignment 7 check: transactions, multiplier stalls, matrix, HALT.
module tb_minirisc_autonomous;
    parameter real CLK_PERIOD = 20.0;
    reg clk = 1'b0;
    reg reset = 1'b1;
    wire done;
    wire [127:0] result_matrix;
    integer loads = 0;
    integer multiplies = 0;
    integer stores = 0;
    integer cycles = 0;
    reg [31:0] halted_pc;

    minirisc32_top dut (
        .clk(clk), .reset(reset), .done(done), .result_matrix(result_matrix)
    );

    always #(CLK_PERIOD/2.0) clk = ~clk;

    always @(posedge clk) begin
        if (!reset && !dut.core_reset) begin
            if (dut.core.load_issue) begin
                if (dut.core.dmem.addra > 8'd7)
                    $fatal(1, "Unexpected load address %0d", dut.core.dmem.addra);
                loads = loads + 1;
            end
            if (dut.core.mul_start) begin
                if (dut.core.pc_write)
                    $fatal(1, "MUL did not stall PC");
                multiplies = multiplies + 1;
            end
            if (dut.core.mul_wait && !dut.core.multiplier_done && dut.core.pc_write)
                $fatal(1, "PC advanced before Booth result was ready");
            if (dut.core.dmem.wea) begin
                if (dut.core.dmem.addra !== 8 + stores)
                    $fatal(1, "Store %0d addressed %0d", stores, dut.core.dmem.addra);
                case (stores)
                    0: if (dut.core.dmem.dina !== 32'd19) $fatal(1, "C00 store incorrect");
                    1: if (dut.core.dmem.dina !== 32'd22) $fatal(1, "C01 store incorrect");
                    2: if (dut.core.dmem.dina !== 32'd43) $fatal(1, "C10 store incorrect");
                    3: if (dut.core.dmem.dina !== 32'd50) $fatal(1, "C11 store incorrect");
                    default: $fatal(1, "Extra matrix store");
                endcase
                stores = stores + 1;
            end
        end
    end

    initial begin
        $dumpfile("minirisc_matrix.vcd");
        $dumpvars(0, tb_minirisc_autonomous);
        repeat (10) @(negedge clk);
        reset = 1'b0;

        while (done !== 1'b1 && cycles < 500) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (done !== 1'b1)
            $fatal(1, "Processor did not reach HALT");
        if (loads !== 16 || multiplies !== 8 || stores !== 4)
            $fatal(1, "Expected 16 LD, 8 MUL, 4 ST; got %0d, %0d, %0d",
                   loads, multiplies, stores);
        if (result_matrix !== {32'd50,32'd43,32'd22,32'd19})
            $fatal(1, "Incorrect matrix %032h", result_matrix);
        if (dut.core.dmem.ram_ip.memory[8] !== 32'd19 ||
            dut.core.dmem.ram_ip.memory[9] !== 32'd22 ||
            dut.core.dmem.ram_ip.memory[10] !== 32'd43 ||
            dut.core.dmem.ram_ip.memory[11] !== 32'd50)
            $fatal(1, "Incorrect stored BRAM matrix");

        halted_pc = dut.core.pc;
        repeat (10) begin
            @(negedge clk);
            if (done !== 1'b1 || dut.core.pc !== halted_pc ||
                dut.core.rf.write_enable || dut.core.dmem.wea ||
                result_matrix !== {32'd50,32'd43,32'd22,32'd19})
                $fatal(1, "HALT did not hold processor state");
        end
        $display("PASS: Assignment 7 matrix = [[19,22],[43,50]]; LD=%0d MUL=%0d ST=%0d", loads, multiplies, stores);
        $finish;
    end
endmodule

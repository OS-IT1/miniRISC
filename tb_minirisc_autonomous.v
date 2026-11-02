`timescale 1ns/1ps

module tb_minirisc_autonomous;
    reg clk = 1'b0;
    reg reset = 1'b1;
    wire done;
    wire [31:0] result_out;
    integer cycles = 0;
    integer load_count = 0;
    integer add_count = 0;
    reg [31:0] previous_accumulator = 32'd0;
    reg [31:0] previous_loaded_value = 32'd0;

    minirisc32_top dut (
        .clk(clk), .reset(reset), .done(done), .result_out(result_out)
    );

    always #5 clk = ~clk; // 100 MHz, matching the assignment example.

    always @(posedge clk) begin
        if (!reset && dut.core.load_issue)
            load_count = load_count + 1;

    end

    // Sample architectural register updates between active clock edges.
    always @(negedge clk) begin
        if (!reset && dut.core.rf.registers[4] !== previous_loaded_value) begin
            case (load_count)
                1: if (dut.core.rf.registers[4] !== 32'd10)
                       $fatal(1, "First loaded word expected 10");
                2: if (dut.core.rf.registers[4] !== 32'd20)
                       $fatal(1, "Second loaded word expected 20");
                3: if (dut.core.rf.registers[4] !== 32'd30)
                       $fatal(1, "Third loaded word expected 30");
                4: if (dut.core.rf.registers[4] !== 32'd40)
                       $fatal(1, "Fourth loaded word expected 40");
                default: $fatal(1, "Unexpected loaded value change");
            endcase
            previous_loaded_value = dut.core.rf.registers[4];
        end

        if (!reset && dut.core.rf.registers[3] !== previous_accumulator) begin
            case (add_count)
                0: if (dut.core.rf.registers[3] !== 32'd10)
                       $fatal(1, "Accumulator step 1 expected 10");
                1: if (dut.core.rf.registers[3] !== 32'd30)
                       $fatal(1, "Accumulator step 2 expected 30");
                2: if (dut.core.rf.registers[3] !== 32'd60)
                       $fatal(1, "Accumulator step 3 expected 60");
                3: if (dut.core.rf.registers[3] !== 32'd100)
                       $fatal(1, "Accumulator step 4 expected 100");
                default: $fatal(1, "Unexpected accumulator update");
            endcase
            previous_accumulator = dut.core.rf.registers[3];
            add_count = add_count + 1;
        end
    end

    initial begin
        $dumpfile("minirisc_autonomous.vcd");
        $dumpvars(0, tb_minirisc_autonomous);

        repeat (5) @(negedge clk);
        reset = 1'b0;

        while (done !== 1'b1 && cycles < 200) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
        end

        if (done !== 1'b1)
            $fatal(1, "Processor did not reach HALT within 200 cycles");
        if (result_out !== 32'h00000064)
            $fatal(1, "Expected result_out=00000064, got %08h", result_out);
        if (load_count != 4)
            $fatal(1, "Expected four data loads, got %0d", load_count);
        if (add_count != 4)
            $fatal(1, "Expected four accumulator additions, got %0d", add_count);
        if (dut.core.pc !== 32'd40 || dut.core.instruction !== 32'hc8000000)
            $fatal(1, "Expected HALT at byte PC 40, got PC=%0d instruction=%08h",
                dut.core.pc, dut.core.instruction);
        if (dut.core.rf.registers[3] !== 32'd100)
            $fatal(1, "Expected accumulator R3=100, got %08h", dut.core.rf.registers[3]);
        if (dut.core.dmem.ram_ip.memory[8] !== 32'd100)
            $fatal(1, "Expected data memory word 8=100, got %08h",
                dut.core.dmem.ram_ip.memory[8]);

        repeat (5) begin
            @(posedge clk);
            #1;
            if (done !== 1'b1 || result_out !== 32'h00000064 ||
                dut.core.pc !== 32'd40 || dut.core.rf.write_enable || dut.core.dmem.wea)
                $fatal(1, "HALT did not hold state, result, and write controls stable");
        end

        $display("PASS: autonomous sum program halted with Mem[8]=result_out=100");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Assignment 6 watchdog timeout");
    end
endmodule

`timescale 1ns/1ps
module tb_minirisc_basic;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire halted;
    integer cycles = 0;
    integer load_count = 0;
    integer store_count = 0;

    minirisc_basic_top dut (
        .clk(clk), .rst(rst), .pc(pc), .instruction(instruction), .halted(halted)
    );

    always #5 clk = ~clk;

    task expect_register;
        input [3:0] address;
        input [31:0] expected;
        begin
            if (dut.rf.registers[address] !== expected)
                $fatal(1, "R%0d: expected %h, got %h", address, expected,
                    dut.rf.registers[address]);
        end
    endtask

    // Observe the CPU-to-BRAM interface only. The testbench deliberately does
    // not inspect or modify the storage array inside either memory IP/model.
    always @(posedge clk) begin
        if (!rst && !halted) begin
            if (dut.load_issue) begin
                if (dut.dmem.ena !== 1'b1 || dut.dmem.wea !== 1'b0)
                    $fatal(1, "LD must enable BRAM read without write enable");
                if (load_count == 0 && dut.dmem.addra !== 8'd5)
                    $fatal(1, "Case 1 LD address: expected word 5, got %0d", dut.dmem.addra);
                if (load_count == 1 && dut.dmem.addra !== 8'd5)
                    $fatal(1, "Case 3 LD address: expected word 5, got %0d", dut.dmem.addra);
                #1;
                if (dut.load_wait !== 1'b1)
                    $fatal(1, "LD must wait for synchronous BRAM data");
                if (load_count == 0 && dut.data_memory_read !== 32'd60)
                    $fatal(1, "Case 1 BRAM data: expected 60, got %h", dut.data_memory_read);
                if (load_count == 1 && dut.data_memory_read !== 32'd99)
                    $fatal(1, "Case 3 BRAM data: expected 99, got %h", dut.data_memory_read);
                load_count = load_count + 1;
            end

            if (dut.mem_write) begin
                if (dut.dmem.ena !== 1'b1 || dut.dmem.wea !== 1'b1 ||
                    dut.dmem.addra !== 8'd5 || dut.dmem.dina !== 32'd99)
                    $fatal(1, "Case 2 ST expected BRAM write addr=5 data=99; got en=%b we=%b addr=%0d data=%h",
                        dut.dmem.ena, dut.dmem.wea, dut.dmem.addra, dut.dmem.dina);
                if (dut.rf.write_enable !== 1'b0)
                    $fatal(1, "ST must not write the register file");
                store_count = store_count + 1;
            end
        end
    end

    initial begin
        // Includes clock/reset, PC/instruction, decoded fields, register
        // operands, immediate, effective address, BRAM interface and WB path.
        $dumpfile("minirisc_basic.vcd");
        $dumpvars(0, tb_minirisc_basic);

        repeat (2) @(negedge clk);
        rst = 1'b0;

        while (halted !== 1'b1 && cycles < 100) begin
            @(posedge clk); #1;
            cycles = cycles + 1;
        end
        if (halted !== 1'b1) $fatal(1, "HALT timeout after 100 cycles");

        // Case 1: R2=2, LD R4,3(R2) -> R4=M[5]=60.
        expect_register(2, 2);
        expect_register(4, 60);

        // Case 2: R5=1, R6=99, ST R6,4(R5) -> M[5]=99.
        expect_register(5, 1);
        expect_register(6, 99);

        // Case 3: LD R7,4(R5) -> R7=M[5]=99 verifies the store by read-back.
        expect_register(7, 99);
        if (load_count != 2 || store_count != 1)
            $fatal(1, "Expected 2 loads/1 store, observed %0d/%0d", load_count, store_count);
        if (instruction !== 32'hC8000000)
            $fatal(1, "Expected HALT instruction, got %h", instruction);

        $display("PASS: Assignment 2A load, store and read-back cases");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Testbench watchdog timeout");
    end
endmodule

`timescale 1ns/1ps
module tb_minirisc_basic;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire halted;
    integer cycles;
    reg [31:0] halt_pc;
    reg [31:0] halt_instruction;

    minirisc_basic_top dut (
        .clk(clk), .rst(rst), .pc(pc), .instruction(instruction), .halted(halted)
    );

    always #5 clk = ~clk;

    // Architectural register checks are independent of the Vivado BRAM IP.
    task expect_register;
        input [3:0] address;
        input [31:0] expected;
        begin
            if (dut.rf.registers[address] !== expected)
                $fatal(1, "R%0d: expected %h, got %h", address, expected,
                    dut.rf.registers[address]);
        end
    endtask

    task await_halt;
        begin
            cycles = 0;
            while (halted !== 1'b1 && cycles < 100) begin
                @(posedge clk); #1;
                cycles = cycles + 1;
            end
            if (halted !== 1'b1) $fatal(1, "HALT timeout after 100 cycles");
        end
    endtask

    initial begin
        $dumpfile("minirisc_basic.vcd");
        $dumpvars(0, tb_minirisc_basic);

        // The ROM image is supplied through the Vivado IP initialization
        // file (program.coe), or program.hex in the simulation ROM model.
        repeat (2) @(negedge clk);
        rst = 1'b0;
        await_halt;

        expect_register(1, 5);             // ADDI
        expect_register(2, 7);             // ADDI
        expect_register(3, 12);            // ADD
        expect_register(4, 2);             // SUB
        expect_register(5, 5);             // AND
        expect_register(6, 40);            // SLL
        expect_register(7, 20);            // SRL
        expect_register(8, 32'hFFFFFFFF);  // signed immediate
        expect_register(10, 1);            // signed SLT
        expect_register(0, 0);             // R0 protection

        if (instruction !== 32'hC8000000)
            $fatal(1, "ROM did not remain on HALT");
        // The ROM image may be generated or padded differently by Vivado.
        // Check that HALT holds the address it was fetched from rather than
        // assuming a particular instruction index in the initialized image.
        halt_pc = pc;
        halt_instruction = instruction;
        repeat (4) begin
            @(posedge clk); #1;
            if (halted !== 1'b1 || pc !== halt_pc ||
                instruction !== halt_instruction || dut.imem.ena !== 1'b0 ||
                dut.rf.write_enable !== 1'b0 || dut.dmem.wea !== 1'b0)
                $fatal(1, "HALT hold failed: pc=%h expected=%h instruction=%h halted=%b imem.ena=%b rf.we=%b dmem.wea=%b",
                    pc, halt_pc, instruction, halted, dut.imem.ena,
                    dut.rf.write_enable, dut.dmem.wea);
        end

        $display("PASS: baseline ALU program and HALT hold");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Testbench watchdog timeout");
    end
endmodule

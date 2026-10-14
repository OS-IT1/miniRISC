`timescale 1ns/1ps
module tb_minirisc_basic;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire halted;
    integer cycles = 0;
    integer beq_count = 0;
    integer bne_count = 0;
    integer taken_branch_count = 0;
    integer jump_count = 0;
    integer jr_count = 0;
    integer nop_count = 0;
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
                $fatal(1, "R%0d: expected %0d (0x%08h), got %0d (0x%08h)",
                    address, expected, expected,
                    dut.rf.registers[address], dut.rf.registers[address]);
        end
    endtask

    // Count instructions at their execution edge and check the visible data
    // memory interface without reaching into the RAM model's storage array.
    always @(posedge clk) begin
        if (!rst && dut.execute_instruction && !halted) begin
            case (instruction[31:27])
                5'b10100: begin
                    beq_count = beq_count + 1;
                    if (dut.branch_taken)
                        taken_branch_count = taken_branch_count + 1;
                end
                5'b10101: begin
                    bne_count = bne_count + 1;
                    if (dut.branch_taken)
                        taken_branch_count = taken_branch_count + 1;
                end
                5'b10110: jump_count = jump_count + 1;
                5'b10111: jr_count = jr_count + 1;
                5'b11000: nop_count = nop_count + 1;
                default: ;
            endcase

            if (dut.load_issue) begin
                if (dut.dmem.ena !== 1'b1 || dut.dmem.wea !== 1'b0)
                    $fatal(1, "LD must enable BRAM read without write enable");
                if (dut.dmem.addra !== 8'd5)
                    $fatal(1, "LD address expected word 5, got %0d", dut.dmem.addra);
                load_count = load_count + 1;
            end

            if (dut.mem_write) begin
                if (dut.dmem.ena !== 1'b1 || dut.dmem.wea !== 1'b1 ||
                    dut.dmem.addra !== 8'd5 || dut.dmem.dina !== 32'd99)
                    $fatal(1, "ST expected BRAM write addr=5 data=99; got en=%b we=%b addr=%0d data=%0d",
                        dut.dmem.ena, dut.dmem.wea, dut.dmem.addra, dut.dmem.dina);
                if (dut.rf.write_enable !== 1'b0)
                    $fatal(1, "ST must not write the register file");
                store_count = store_count + 1;
            end
        end
    end

    initial begin
        $dumpfile("minirisc_basic.vcd");
        $dumpvars(0, tb_minirisc_basic);

        repeat (2) @(negedge clk);
        rst = 1'b0;

        while (halted !== 1'b1 && cycles < 100) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
        end
        if (halted !== 1'b1)
            $fatal(1, "HALT timeout after 100 cycles");

        // Branch and jump targets skip all marker writes.
        expect_register(1, 5);
        expect_register(2, 5);
        expect_register(3, 7);
        expect_register(4, 60);
        expect_register(5, 1);
        expect_register(7, 99);
        expect_register(8, 99);
        expect_register(9, 76); // JR target is instruction 19, byte address 76.
        expect_register(10, 0);
        expect_register(11, 0);
        expect_register(12, 0);
        expect_register(13, 0);
        expect_register(14, 0);
        expect_register(15, 0);

        if (beq_count != 2 || bne_count != 2 || taken_branch_count != 3)
            $fatal(1, "Expected BEQ/BNE/taken counts 2/2/3, got %0d/%0d/%0d",
                beq_count, bne_count, taken_branch_count);
        if (jump_count != 2 || jr_count != 1 || nop_count != 2)
            $fatal(1, "Expected J/JR/NOP counts 2/1/2, got %0d/%0d/%0d",
                jump_count, jr_count, nop_count);
        if (load_count != 2 || store_count != 1)
            $fatal(1, "Expected 2 loads/1 store, observed %0d/%0d", load_count, store_count);
        if (instruction !== 32'hC8000000 || pc !== 32'd100)
            $fatal(1, "HALT should park instruction/PC at 0xC8000000/100; got %h/%0d",
                instruction, pc);

        repeat (3) begin
            @(posedge clk);
            #1;
            if (!halted || instruction !== 32'hC8000000 || pc !== 32'd100)
                $fatal(1, "HALT failed to hold PC/instruction");
        end

        $display("PASS: baseline CPU branch, jump, NOP, HALT, load/store checks");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Testbench watchdog timeout");
    end
endmodule

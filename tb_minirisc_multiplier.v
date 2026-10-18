`timescale 1ns/1ps

// CPU-level test for the Booth MUL/MAC path. It uses the simulation ROM's
// memory array so it can run independently of the baseline program image.
module tb_minirisc_multiplier;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire halted;

    integer cycles = 0;
    integer multiply_launches = 0;
    integer multiply_commits = 0;
    reg [31:0] stalled_pc;
    reg [31:0] stalled_instruction;
    reg [3:0] stalled_destination;
    reg [31:0] expected_result;

    minirisc_basic_top dut (
        .clk(clk), .rst(rst), .pc(pc), .instruction(instruction), .halted(halted)
    );

    always #5 clk = ~clk;

    task check_register;
        input [3:0] address;
        input [31:0] expected;
        begin
            if (dut.rf.registers[address] !== expected)
                $fatal(1, "R%0d expected 0x%08h, got 0x%08h",
                    address, expected, dut.rf.registers[address]);
        end
    endtask

    // Save the issuing instruction and verify that the CPU keeps it in place
    // until the multiplier completes, then commits to the latched destination.
    always @(posedge clk) begin
        if (!rst) begin
            if (dut.mul_start) begin
                multiply_launches = multiply_launches + 1;
                stalled_pc = pc;
                stalled_instruction = instruction;
                stalled_destination = dut.rd;
            end

            if (dut.mul_wait) begin
                if (pc !== stalled_pc || instruction !== stalled_instruction)
                    $fatal(1, "PC/instruction changed before multiply completion");
                if (!dut.multiplier_done && dut.rom_enable !== 1'b0)
                    $fatal(1, "Instruction ROM must be held during multiply wait");
                if (!dut.multiplier_done && dut.multiplier_busy !== 1'b1)
                    $fatal(1, "Multiplier must report busy until its result is ready");
                if (dut.mul_commit !== dut.multiplier_done)
                    $fatal(1, "Multiply commit must coincide with multiplier done");
            end

            if (dut.mul_commit) begin
                case (multiply_commits)
                    0: expected_result = -32'sd42; // MUL: -7 * 6
                    1: expected_result = -32'sd42; // MAC: 0 + (-7 * 6)
                    2: expected_result = 32'd3;    // MAC: -42 + (5 * 9)
                    default: $fatal(1, "Unexpected extra multiply commit");
                endcase
                if (dut.rf.write_enable !== 1'b1 ||
                    dut.rf.write_addr !== stalled_destination ||
                    dut.rf.write_data !== expected_result)
                    $fatal(1, "Bad multiply write-back: en=%b rd=%0d data=0x%08h expected rd=%0d data=0x%08h",
                        dut.rf.write_enable, dut.rf.write_addr, dut.rf.write_data,
                        stalled_destination, expected_result);
                if (pc !== stalled_pc)
                    $fatal(1, "PC must remain at the multiply instruction through its commit edge");
                #1;
                if (pc !== stalled_pc + 32'd4)
                    $fatal(1, "PC did not advance after multiply commit");
                check_register(stalled_destination, expected_result);
                multiply_commits = multiply_commits + 1;
            end
        end
    end

    initial begin
        // Program:
        //   r1=-7; r2=6; r3=r1*r2;
        //   r6=0; MAC r6,r1,r2; r4=5; r5=9; MAC r6,r4,r5; HALT
        // The two MAC instructions form the dot product (-7*6) + (5*9) = 3.
        #1;
        dut.imem.rom_ip.memory[0] = 32'h700ffff9; // addi r1,r0,-7
        dut.imem.rom_ip.memory[1] = 32'h70100006; // addi r2,r0,6
        dut.imem.rom_ip.memory[2] = 32'h68918000; // mul  r3,r1,r2
        dut.imem.rom_ip.memory[3] = 32'h00030000; // add  r6,r0,r0
        dut.imem.rom_ip.memory[4] = 32'hd0930000; // mac  r6,r1,r2
        dut.imem.rom_ip.memory[5] = 32'h70200005; // addi r4,r0,5
        dut.imem.rom_ip.memory[6] = 32'h70280009; // addi r5,r0,9
        dut.imem.rom_ip.memory[7] = 32'hd22b0000; // mac  r6,r4,r5
        dut.imem.rom_ip.memory[8] = 32'hc8000000; // halt

        repeat (2) @(negedge clk);
        rst = 1'b0;

        while (halted !== 1'b1 && cycles < 100) begin
            @(posedge clk);
            #2;
            cycles = cycles + 1;
        end

        if (halted !== 1'b1)
            $fatal(1, "CPU did not reach HALT within 100 cycles");
        if (multiply_launches != 3 || multiply_commits != 3)
            $fatal(1, "Expected 3 multiplier launches/commits, got %0d/%0d",
                multiply_launches, multiply_commits);
        check_register(3, -32'sd42);
        check_register(6, 32'd3);
        if (pc !== 32'd32)
            $fatal(1, "Expected HALT at byte PC 32, got %0d", pc);

        $display("PASS: Booth MUL/MAC stall and dot-product write-back");
        $finish;
    end
endmodule

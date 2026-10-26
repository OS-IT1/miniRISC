`timescale 1ns/1ps

// Assignment 5 demonstration: three signed MUL examples and the required
// BRAM-backed A dot B = 21 program from program.hex.
module tb_minirisc_assignment5;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire halted;

    integer cycles = 0;
    integer mul_starts = 0;
    integer mul_commits = 0;
    integer loads = 0;
    integer stores = 0;
    reg [31:0] issued_pc;
    reg [31:0] issued_instruction;
    reg [3:0] issued_destination;
    reg [3:0] expected_destination;
    reg [31:0] expected_product;

    // Named waveform probes for the assignment demonstration.
    reg [2:0] probe_fsm_state;
    reg [4:0] probe_opcode;
    reg [3:0] probe_rs1_address, probe_rs2_address, probe_rd_address;
    reg [31:0] probe_source_a, probe_source_b;
    reg probe_mul_start, probe_mul_busy, probe_mul_done, probe_mul_commit;
    reg signed [63:0] probe_mul_product;
    reg [3:0] probe_mul_destination;
    reg probe_register_write_enable;
    reg [3:0] probe_register_write_address;
    reg [31:0] probe_register_write_data;
    reg [31:0] probe_alu_result;
    reg [7:0] probe_data_address;
    reg probe_data_enable, probe_data_write_enable;
    reg [31:0] probe_data_write_data, probe_data_read_data;
    reg [31:0] probe_accumulator, probe_result_readback;
    reg probe_halted;

    minirisc_basic_top dut (
        .clk(clk), .rst(rst), .pc(pc), .instruction(instruction), .halted(halted)
    );

    always #5 clk = ~clk;

    always @(*) begin
        probe_fsm_state = dut.control.state;
        probe_opcode = instruction[31:27];
        probe_rs1_address = dut.rs1;
        probe_rs2_address = dut.rs2;
        probe_rd_address = dut.rd;
        probe_source_a = dut.read_data1;
        probe_source_b = dut.read_data2;
        probe_mul_start = dut.mul_start;
        probe_mul_busy = dut.multiplier_busy;
        probe_mul_done = dut.multiplier_done;
        probe_mul_commit = dut.mul_commit;
        probe_mul_product = dut.multiplier_product;
        probe_mul_destination = dut.mul_destination;
        probe_register_write_enable = dut.rf.write_enable;
        probe_register_write_address = dut.rf.write_addr;
        probe_register_write_data = dut.rf.write_data;
        probe_alu_result = dut.alu_result;
        probe_data_address = dut.dmem.addra;
        probe_data_enable = dut.dmem.ena;
        probe_data_write_enable = dut.dmem.wea;
        probe_data_write_data = dut.dmem.dina;
        probe_data_read_data = dut.data_memory_read;
        probe_accumulator = dut.rf.registers[10];
        probe_result_readback = dut.rf.registers[14];
        probe_halted = halted;
    end

    task check_register;
        input [3:0] address;
        input [31:0] expected;
        begin
            if (dut.rf.registers[address] !== expected)
                $fatal(1, "R%0d expected 0x%08h, got 0x%08h",
                    address, expected, dut.rf.registers[address]);
        end
    endtask

    always @(posedge clk) begin
        if (!rst) begin
            if (dut.mul_start) begin
                mul_starts = mul_starts + 1;
                issued_pc = pc;
                issued_instruction = instruction;
                issued_destination = dut.rd;
            end

            if (dut.mul_wait) begin
                if (pc !== issued_pc || instruction !== issued_instruction)
                    $fatal(1, "MUL changed PC/instruction before completion");
                if (!dut.multiplier_done && dut.rom_enable !== 1'b0)
                    $fatal(1, "ROM must remain disabled while MUL is busy");
                if (!dut.multiplier_done && dut.multiplier_busy !== 1'b1)
                    $fatal(1, "Multiplier must remain busy until done");
                if (dut.mul_commit !== dut.multiplier_done)
                    $fatal(1, "MUL write-back must coincide with done");
            end

            if (dut.load_issue) loads = loads + 1;

            if (dut.mem_write) begin
                if (dut.dmem.ena !== 1'b1 || dut.dmem.wea !== 1'b1 ||
                    dut.dmem.addra !== 8'd8 || dut.dmem.dina !== 32'd21)
                    $fatal(1, "Expected ST Mem[8]=21, got addr=%0d data=0x%08h",
                        dut.dmem.addra, dut.dmem.dina);
                stores = stores + 1;
            end

            if (dut.mul_commit) begin
                case (mul_commits)
                    0: begin expected_destination = 4'd11; expected_product = 32'd63; end
                    1: begin expected_destination = 4'd12; expected_product = 32'hffff_ffd6; end
                    2: begin expected_destination = 4'd13; expected_product = 32'd20; end
                    3: begin expected_destination = 4'd3;  expected_product = 32'd8; end
                    4: begin expected_destination = 4'd3;  expected_product = 32'hffff_fffb; end
                    5: begin expected_destination = 4'd3;  expected_product = 32'd18; end
                    default: $fatal(1, "Unexpected multiply commit %0d", mul_commits);
                endcase
                if (issued_destination !== expected_destination ||
                    dut.rf.write_enable !== 1'b1 ||
                    dut.rf.write_addr !== expected_destination ||
                    dut.rf.write_data !== expected_product)
                    $fatal(1, "MUL %0d write-back mismatch: rd=%0d data=0x%08h expected rd=%0d data=0x%08h",
                        mul_commits, dut.rf.write_addr, dut.rf.write_data,
                        expected_destination, expected_product);
                #1;
                check_register(expected_destination, expected_product);
                if (pc !== issued_pc + 32'd4)
                    $fatal(1, "PC did not advance after MUL write-back");
                mul_commits = mul_commits + 1;
            end
        end
    end

    initial begin
        $dumpfile("minirisc_assignment5.vcd");
        // Dump testbench-level signals and probes only; do not recurse into
        // the DUT or implementation-specific Vivado memory IP internals.
        $dumpvars(1, tb_minirisc_assignment5);

        repeat (2) @(negedge clk);
        rst = 1'b0;

        while (halted !== 1'b1 && cycles < 200) begin
            @(posedge clk);
            #2;
            cycles = cycles + 1;
        end

        if (halted !== 1'b1)
            $fatal(1, "Program did not reach HALT within 200 cycles");
        if (mul_starts != 6 || mul_commits != 6)
            $fatal(1, "Expected six MUL starts/commits, got %0d/%0d",
                mul_starts, mul_commits);
        if (loads != 7 || stores != 1)
            $fatal(1, "Expected seven LD and one ST, got %0d/%0d", loads, stores);

        check_register(11, 32'd63);
        check_register(12, 32'hffff_ffd6);
        check_register(13, 32'd20);
        check_register(10, 32'd21);
        check_register(14, 32'd21);
        if (instruction !== 32'hc8000000 || pc !== 32'd96)
            $fatal(1, "Expected HALT at byte PC 96, got instruction=0x%08h PC=%0d",
                instruction, pc);

        repeat (3) begin
            @(posedge clk);
            #1;
            if (!halted || instruction !== 32'hc8000000 || pc !== 32'd96 ||
                dut.rf.write_enable || dut.dmem.wea)
                $fatal(1, "HALT failed to hold the processor without writes");
        end

        $display("PASS: signed MUL cases, stalled write-back, and BRAM dot product Mem[8]=21");
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Assignment 5 testbench watchdog timeout");
    end
endmodule

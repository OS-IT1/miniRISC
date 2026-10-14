`timescale 1ns/1ps
module tb_minirisc_basic;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire halted;

    // Section 12: temporary waveform variables mirror the live DUT signals.
    // FSM: 00=EXECUTE, 01=LOAD_WAIT, 10=HALTED.
    // Branch condition: 00=none, 01=equal, 10=not equal.
    reg [1:0] fsm_state;
    reg [4:0] opcode;
    reg [31:0] fetched_instruction;
    reg [31:0] source_register_1;
    reg [31:0] source_register_2;
    reg [31:0] immediate_offset;
    reg [31:0] alu_result;
    reg [1:0] branch_condition;
    reg [31:0] branch_target;
    reg  branch_taken;
    reg [7:0] data_bram_address;
    reg [31:0] data_bram_read_data;
    reg  data_bram_write_enable;
    reg  register_write_enable;
    reg [31:0] write_back_data;
    reg [31:0] selected_next_pc;
    reg  temp_clock;
    reg  temp_reset;
    reg [31:0] temp_pc;
    reg  temp_halt;
    reg [3:0] source_register_address_1;
    reg [3:0] source_register_address_2;
    reg [3:0] destination_register_address;
    reg [3:0] decoded_alu_control;
    reg [18:0] branch_offset;
    reg [31:0] data_bram_write_data;
    reg  data_bram_enable;
    reg [1:0] pc_selection;

    always @(*) begin
        fsm_state = dut.control.state;
        opcode = instruction[31:27];
        fetched_instruction = instruction;
        source_register_1 = dut.read_data1;
        source_register_2 = dut.read_data2;
        immediate_offset = dut.immediate;
        alu_result = dut.alu_result;
        branch_condition = dut.branch_kind;
        branch_target = dut.branch_pc;
        branch_taken = dut.branch_taken;
        data_bram_address = dut.dmem.addra;
        data_bram_read_data = dut.data_memory_read;
        data_bram_write_enable = dut.dmem.wea;
        register_write_enable = dut.rf.write_enable;
        write_back_data = dut.register_write_data;
        selected_next_pc = dut.next_pc;
        temp_clock = clk;
        temp_reset = rst;
        temp_pc = pc;
        temp_halt = halted;
        source_register_address_1 = dut.rs1;
        source_register_address_2 = dut.rs2;
        destination_register_address = dut.rd;
        decoded_alu_control = dut.alu_control;
        branch_offset = instruction[18:0];
        data_bram_write_data = dut.dmem.dina;
        data_bram_enable = dut.dmem.ena;
        pc_selection = dut.pc_select;
    end

    integer cycles = 0;
    integer beq_count = 0;
    integer bne_count = 0;
    integer taken_branch_count = 0;
    integer not_taken_branch_count = 0;
    integer nop_count = 0;
    integer load_count = 0;
    integer store_count = 0;
    integer add_count = 0;
    integer addi_count = 0;
    integer subi_count = 0;
    integer move_count = 0;
    reg [31:0] halt_register_snapshot [1:15];
    integer halt_snapshot_index;

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
                5'b00000: add_count = add_count + 1;
                5'b01110: addi_count = addi_count + 1;
                5'b01111: subi_count = subi_count + 1;
                5'b10100: begin
                    beq_count = beq_count + 1;
                    if (dut.branch_taken)
                        taken_branch_count = taken_branch_count + 1;
                    else
                        not_taken_branch_count = not_taken_branch_count + 1;
                end
                5'b10101: begin
                    bne_count = bne_count + 1;
                    if (dut.branch_taken)
                        taken_branch_count = taken_branch_count + 1;
                    else
                        not_taken_branch_count = not_taken_branch_count + 1;
                end
                5'b11000: nop_count = nop_count + 1;
                5'b10000: move_count = move_count + 1;
                default: ;
            endcase

            if (dut.branch_kind != 2'b00) begin
                if (dut.rf.write_enable !== 1'b0 || dut.dmem.wea !== 1'b0)
                    $fatal(1, "Branch must not write registers or memory");
                if ((dut.branch_kind == 2'b01 &&
                     dut.branch_taken !== (dut.read_data1 == dut.read_data2)) ||
                    (dut.branch_kind == 2'b10 &&
                     dut.branch_taken !== (dut.read_data1 != dut.read_data2)))
                    $fatal(1, "Branch decision disagrees with source registers");
                if (dut.branch_taken && dut.next_pc !== dut.branch_pc)
                    $fatal(1, "Taken branch did not select branch target");
                if (!dut.branch_taken && dut.next_pc !== (pc + 32'd4))
                    $fatal(1, "Untaken branch did not select sequential PC");
            end

            if (dut.load_issue) begin
                if (dut.dmem.ena !== 1'b1 || dut.dmem.wea !== 1'b0)
                    $fatal(1, "LD must enable BRAM read without write enable");
                if (dut.dmem.addra !== 8'd5)
                    $fatal(1, "LD address expected word 5, got %0d", dut.dmem.addra);
                load_count = load_count + 1;
            end

            if (dut.mem_write) begin
                if (dut.dmem.ena !== 1'b1 || dut.dmem.wea !== 1'b1 ||
                    dut.dmem.addra !== 8'd5 || dut.dmem.dina !== (store_count + 1))
                    $fatal(1, "ST expected BRAM write addr=5 data=%0d; got en=%b we=%b addr=%0d data=%0d",
                        store_count + 1,
                        dut.dmem.ena, dut.dmem.wea, dut.dmem.addra, dut.dmem.dina);
                if (dut.rf.write_enable !== 1'b0)
                    $fatal(1, "ST must not write the register file");
                store_count = store_count + 1;
            end
        end
    end

    // Check the state and architectural result across each real clock edge.
    // Sample before the edge's nonblocking updates, then inspect after settling.
    reg [31:0] edge_pc, edge_instruction, expected_pc;
    reg [3:0] load_destination;
    reg [31:0] expected_load_data;
    reg [31:0] nop_snapshot [0:15];
    integer check_index;
    integer load_commit_count = 0;
    always @(posedge clk) begin
        if (!rst && !halted) begin
            edge_pc = pc;
            edge_instruction = instruction;
            if (dut.load_issue) begin
                load_destination = dut.rd;
                expected_load_data = store_count;
                if (dut.pc_write !== 1'b0 || dut.rom_enable !== 1'b0 ||
                    dut.rf.write_enable !== 1'b0)
                    $fatal(1, "LD issue must hold fetch and defer register write");
                #1;
                if (pc !== edge_pc || instruction !== edge_instruction ||
                    dut.load_commit !== 1'b1 ||
                    dut.data_memory_read !== expected_load_data)
                    $fatal(1, "LD issue timing/data mismatch");
            end else if (dut.load_commit) begin
                if (dut.rf.write_enable !== 1'b1 || dut.rd !== load_destination ||
                    dut.register_write_data !== expected_load_data ||
                    dut.dmem.ena !== 1'b0 || dut.dmem.wea !== 1'b0)
                    $fatal(1, "LD commit must write the pending BRAM result once");
                #1;
                expect_register(load_destination, expected_load_data);
                if (pc !== edge_pc + 32'd4 || dut.control.state !== 2'b00)
                    $fatal(1, "LD commit must advance PC and return to EXECUTE");
                load_commit_count = load_commit_count + 1;
            end else if (dut.execute_instruction && !dut.halt_instruction) begin
                expected_pc = edge_pc + 32'd4;
                if (dut.branch_kind != 2'b00 && dut.branch_taken)
                    expected_pc = edge_pc + 32'd4 +
                        ({{13{edge_instruction[18]}}, edge_instruction[18:0]} << 2);
                else if (dut.jump)
                    expected_pc = {3'b000, edge_instruction[26:0], 2'b00};
                else if (dut.jump_register)
                    expected_pc = dut.read_data1;
                if (dut.nop) begin
                    if (dut.rf.write_enable !== 1'b0 || dut.dmem.wea !== 1'b0 ||
                        dut.mem_read !== 1'b0 || dut.mem_write !== 1'b0 ||
                        dut.branch_taken !== 1'b0 || dut.jump !== 1'b0 ||
                        dut.jump_register !== 1'b0)
                        $fatal(1, "NOP has unintended side effects");
                    for (check_index = 0; check_index < 16; check_index = check_index + 1)
                        nop_snapshot[check_index] = dut.rf.registers[check_index];
                end
                #1;
                if (pc !== expected_pc)
                    $fatal(1, "PC update at %0d: expected %0d, got %0d",
                        edge_pc, expected_pc, pc);
                if (edge_instruction[31:27] == 5'b11000)
                    for (check_index = 0; check_index < 16; check_index = check_index + 1)
                        if (dut.rf.registers[check_index] !== nop_snapshot[check_index])
                            $fatal(1, "NOP changed R%0d", check_index);
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

        // Three loop iterations accumulate 3 and store/load it at word 5.
        expect_register(1, 0);
        expect_register(2, 1);
        expect_register(3, 3);
        expect_register(4, 3);
        if (dut.rf.registers[0] !== 32'd0)
            $fatal(1, "R0 must remain zero");

        if (beq_count != 1 || bne_count != 3 || taken_branch_count != 2 ||
            not_taken_branch_count != 2)
            $fatal(1, "Expected BEQ/BNE/taken/not-taken counts 1/3/2/2, got %0d/%0d/%0d/%0d",
                beq_count, bne_count, taken_branch_count, not_taken_branch_count);
        if (nop_count != 1 || load_count != 3 || store_count != 3 || load_commit_count != 3)
            $fatal(1, "Expected NOP/LD/ST counts 1/3/3, got %0d/%0d/%0d",
                nop_count, load_count, store_count);
        if (add_count != 3 || addi_count != 2 || subi_count != 3 || move_count != 1)
            $fatal(1, "Expected ADD/ADDI/SUBI/MOVE counts 3/2/3/1, got %0d/%0d/%0d/%0d",
                add_count, addi_count, subi_count, move_count);
        if (instruction !== 32'hC8000000 || pc !== 32'd40)
            $fatal(1, "HALT should park instruction/PC at 0xC8000000/40; got %h/%0d",
                instruction, pc);

        for (halt_snapshot_index = 1; halt_snapshot_index < 16;
             halt_snapshot_index = halt_snapshot_index + 1)
            halt_register_snapshot[halt_snapshot_index] =
                dut.rf.registers[halt_snapshot_index];

        repeat (3) begin
            @(posedge clk);
            #1;
            if (!halted || instruction !== 32'hC8000000 || pc !== 32'd40)
                $fatal(1, "HALT failed to hold PC/instruction");
            if (register_write_enable !== 1'b0 ||
                data_bram_write_enable !== 1'b0)
                $fatal(1, "HALT must disable register and data-memory writes");
            for (halt_snapshot_index = 1; halt_snapshot_index < 16;
                 halt_snapshot_index = halt_snapshot_index + 1)
                if (dut.rf.registers[halt_snapshot_index] !==
                    halt_register_snapshot[halt_snapshot_index])
                    $fatal(1, "Register R%0d changed after HALT",
                        halt_snapshot_index);
        end

        $display("PASS: looped ADD/ADDI/SUBI/MOVE, taken/untaken branch, LD/ST, NOP, HALT checks");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Testbench watchdog timeout");
    end
endmodule

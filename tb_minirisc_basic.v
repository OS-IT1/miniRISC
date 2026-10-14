`timescale 1ns/1ps
module tb_minirisc_basic;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] pc;
    wire [31:0] instruction;
    wire halted;

    // Named waveform probes. These aliases keep the requested processor
    // signals together at the testbench scope in minirisc_basic.vcd.
    // FSM encoding: 00=EXECUTE, 01=LOAD_WAIT, 10=HALTED.
    wire [1:0]  fsm_state          = dut.control.state;
    wire [4:0]  opcode             = instruction[31:27];
    wire [31:0] fetched_instruction = instruction;
    wire [31:0] source_register_1  = dut.read_data1;
    wire [31:0] source_register_2  = dut.read_data2;
    wire [31:0] immediate_offset   = dut.immediate;
    wire [31:0] alu_result         = dut.alu_result;
    // Branch condition encoding: 00=none, 01=equal, 10=not equal.
    wire [1:0]  branch_condition   = dut.branch_kind;
    wire [31:0] branch_target      = dut.branch_pc;
    wire        branch_taken       = dut.branch_taken;
    wire [7:0]  data_bram_address  = dut.dmem.addra;
    wire [31:0] data_bram_read_data = dut.data_memory_read;
    wire        data_bram_write_enable = dut.dmem.wea;
    wire        register_write_enable = dut.rf.write_enable;
    wire [31:0] write_back_data    = dut.register_write_data;
    wire [31:0] selected_next_pc   = dut.next_pc;

    integer cycles = 0;
    integer beq_count = 0;
    integer bne_count = 0;
    integer taken_branch_count = 0;
    integer not_taken_branch_count = 0;
    integer jump_count = 0;
    integer jr_count = 0;
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
                5'b10110: jump_count = jump_count + 1;
                5'b10111: jr_count = jr_count + 1;
                5'b11000: nop_count = nop_count + 1;
                5'b10000: move_count = move_count + 1;
                default: ;
            endcase

            if (dut.branch_kind != 2'b00) begin
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
        if (nop_count != 1 || load_count != 3 || store_count != 3)
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

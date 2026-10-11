`timescale 1ns/1ps
module tb_minirisc_basic;
    reg clk=1'b0, rst=1'b1;
    wire [31:0] pc,instruction;
    wire halted;
    integer i, load_count=0, store_count=0;
    reg check_memory=0;
    reg [31:0] saved_pc, saved_instruction, saved_register;
    reg [31:0] expected_load;
    reg [3:0] saved_rd;
    reg [31:0] store_pc, store_data, store_output;
    reg [7:0] store_address;
    reg [31:0] store_registers [0:15];
    integer register_index;
    minirisc_basic_top dut
      (.clk(clk),.rst(rst),.pc(pc),.instruction(instruction),.halted(halted));
    always #5 clk=~clk;

    // Encode the base register, load destination/store source and signed offset.
    function [31:0] imm_instruction;
        input [4:0] opcode;
        input [3:0] base, target;
        input integer offset;
        begin imm_instruction={opcode,base,target,offset[18:0]}; end
    endfunction

    task expect_register;
        input [3:0] address;
        input [31:0] expected;
        begin
            if (dut.rf.registers[address] !== expected)
                $fatal(1,"R%0d: expected %h, got %h",address,expected,
                       dut.rf.registers[address]);
        end
    endtask

    task await_halt;
        integer cycles;
        begin
            cycles=0;
            while (halted !== 1'b1 && cycles < 100) begin
                @(posedge clk); #1;
                cycles=cycles+1;
            end
            if (halted !== 1'b1) $fatal(1,"HALT timeout after 100 cycles");
        end
    endtask

    task check_halt_hold;
        reg [31:0] halt_pc, halt_instruction;
        begin
            halt_pc=pc;
            halt_instruction=instruction;
            if (instruction !== 32'hC8000000)
                $fatal(1,"ROM did not remain on HALT");
            repeat (4) begin
                @(posedge clk); #1;
                if (halted !== 1'b1 || pc !== halt_pc ||
                    instruction !== halt_instruction || dut.imem.ena !== 1'b0 ||
                    dut.rf.write_enable !== 1'b0 || dut.dmem.wea !== 1'b0)
                    $fatal(1,"HALT did not hold PC, instruction and ROM enable");
            end
        end
    endtask

    // Observe both sides of each clock edge, including synchronous RAM latency.
    always @(posedge clk) begin
        if (!rst && check_memory && !halted) begin
            if (dut.mem_read || dut.mem_write) begin
                if (dut.immediate !== {{13{instruction[18]}},instruction[18:0]} ||
                    dut.alu_result !== dut.read_data1+dut.immediate)
                    $fatal(1,"LD/ST must use base plus sign-extended 19-bit offset");
            end
            if (dut.load_issue) begin
                saved_pc=pc;
                saved_instruction=instruction;
                saved_rd=dut.rd;
                saved_register=dut.rf.registers[dut.rd];
                expected_load=dut.dmem.ram_ip.memory[dut.alu_result[9:2]];
                if (dut.rf.write_enable !== 1'b0 || dut.imem.ena !== 1'b0 ||
                    dut.dmem.ena !== 1'b1 || dut.dmem.wea !== 1'b0)
                    $fatal(1,"Invalid controls on LD issue");
                #1;
                if (pc !== saved_pc || instruction !== saved_instruction ||
                    dut.rf.registers[saved_rd] !== saved_register ||
                    dut.load_wait !== 1'b1 || dut.data_memory_read !== expected_load)
                    $fatal(1,"LD issue must hold fetch/destination and capture RAM data");
            end else if (dut.load_wait) begin
                if (dut.rf.write_enable !== 1'b1 || dut.imem.ena !== 1'b1 ||
                    dut.dmem.ena !== 1'b0)
                    $fatal(1,"Invalid controls on LD write-back");
                #1;
                if (pc !== saved_pc+32'd4 || dut.load_wait !== 1'b0)
                    $fatal(1,"LD write-back must resume fetch");
                if (saved_rd != 0 && dut.rf.registers[saved_rd] !== expected_load)
                    $fatal(1,"LD wrote an address/stale value instead of RAM data");
                if (dut.rf.registers[0] !== 32'b0) $fatal(1,"LD modified R0");
                load_count=load_count+1;
            end else if (dut.mem_write) begin
                store_pc=pc;
                store_address=dut.alu_result[9:2];
                store_data=dut.read_data2;
                store_output=dut.data_memory_read;
                for (register_index=0; register_index<16; register_index=register_index+1)
                    store_registers[register_index]=dut.rf.registers[register_index];
                if (dut.rf.write_enable !== 1'b0 || dut.dmem.wea !== 1'b1 ||
                    dut.dmem.ena !== 1'b1 || dut.imem.ena !== 1'b1)
                    $fatal(1,"ST must write RAM without register write-back");
                #1;
                if (pc !== store_pc+32'd4 || dut.load_wait !== 1'b0 ||
                    dut.dmem.ram_ip.memory[store_address] !== store_data ||
                    dut.data_memory_read !== store_output)
                    $fatal(1,"ST must advance fetch and write RAM in No Change mode");
                for (register_index=0; register_index<16; register_index=register_index+1)
                    if (dut.rf.registers[register_index] !== store_registers[register_index])
                        $fatal(1,"ST changed R%0d",register_index);
                store_count=store_count+1;
            end
        end
    end

    // Check the recognition edge too: a check starting after halted rises
    // would miss an incorrect PC increment on that first HALT edge.
    reg [31:0] halt_edge_pc, halt_edge_instruction;
    always @(posedge clk) begin
        if (!rst && !halted && dut.halt_instruction) begin
            halt_edge_pc=pc;
            halt_edge_instruction=instruction;
            if (dut.imem.ena !== 1'b0 || dut.rf.write_enable !== 1'b0 ||
                dut.dmem.wea !== 1'b0)
                $fatal(1,"HALT recognition must suppress fetch and writes");
            #1;
            if (halted !== 1'b1 || pc !== halt_edge_pc ||
                instruction !== halt_edge_instruction)
                $fatal(1,"HALT recognition must assert halted and hold PC/ROM");
        end
    end

    initial begin
        $dumpfile("minirisc_basic.vcd"); $dumpvars(0,tb_minirisc_basic);
        // Release reset off the active edge to avoid a race with the DUT.
        repeat(2) @(negedge clk); rst=0;
        await_halt;
        expect_register(1,5); expect_register(2,7); expect_register(3,12);
        expect_register(4,2); expect_register(5,5); expect_register(6,40);
        expect_register(7,20); expect_register(8,32'hFFFFFFFF);
        expect_register(10,1); expect_register(0,0);
        check_halt_hold;
        $display("PASS: baseline ALU program and HALT hold");

        // Load a separate directed program into the simulation ROM only.
        @(negedge clk); rst=1;
        for (i=0; i<256; i=i+1)
            dut.imem.rom_ip.memory[i]=32'hC0000000; // NOP
        dut.imem.rom_ip.memory[0]=imm_instruction(14,0,1,16);
        dut.imem.rom_ip.memory[1]=imm_instruction(14,0,2,-37);
        dut.imem.rom_ip.memory[2]=imm_instruction(19,1,2,4);  // mem[5] = -37
        dut.imem.rom_ip.memory[3]=imm_instruction(14,0,3,123);
        dut.imem.rom_ip.memory[4]=imm_instruction(19,1,3,-4); // mem[3] = 123
        dut.imem.rom_ip.memory[5]=imm_instruction(18,1,4,4);
        dut.imem.rom_ip.memory[6]=imm_instruction(18,1,5,-4); // consecutive LD
        dut.imem.rom_ip.memory[7]=imm_instruction(14,5,6,1);  // dependent ADDI
        dut.imem.rom_ip.memory[8]=imm_instruction(18,1,0,4);  // discard LD to R0
        dut.imem.rom_ip.memory[9]=imm_instruction(19,1,0,8);  // store R0
        dut.imem.rom_ip.memory[10]=imm_instruction(18,1,7,8);
        dut.imem.rom_ip.memory[11]=imm_instruction(18,1,1,-4); // base = destination
        dut.imem.rom_ip.memory[12]=imm_instruction(19,0,1,28); // store just-loaded R1
        dut.imem.rom_ip.memory[13]=imm_instruction(18,0,8,29); // low bits ignored
        dut.imem.rom_ip.memory[14]=32'hC8000000;
        dut.imem.rom_ip.memory[15]=imm_instruction(19,0,3,32); // must not execute
        dut.imem.rom_ip.memory[16]=imm_instruction(14,0,9,99);
        dut.dmem.ram_ip.memory[6]=32'hDEADBEEF;
        dut.dmem.ram_ip.memory[8]=32'hA5A5A5A5;
        repeat(2) @(negedge clk);
        if (halted !== 1'b0 || dut.load_wait !== 1'b0 || pc !== 0)
            $fatal(1,"Reset did not clear HALT/load state and PC");
        check_memory=1; rst=0;
        await_halt;
        check_halt_hold;
        expect_register(0,0); expect_register(1,123);
        expect_register(2,32'hFFFFFFDB); expect_register(3,123);
        expect_register(4,32'hFFFFFFDB); expect_register(5,123);
        expect_register(6,124); expect_register(7,0);
        expect_register(8,123); expect_register(9,0);
        if (load_count != 6 || store_count != 4)
            $fatal(1,"Expected 6 loads/4 stores, got %0d/%0d",load_count,store_count);
        if (dut.dmem.ram_ip.memory[3] !== 123 ||
            dut.dmem.ram_ip.memory[5] !== 32'hFFFFFFDB ||
            dut.dmem.ram_ip.memory[6] !== 0 ||
            dut.dmem.ram_ip.memory[7] !== 123 ||
            dut.dmem.ram_ip.memory[8] !== 32'hA5A5A5A5)
            $fatal(1,"Store addressing/data or post-HALT memory protection failed");
        $display("PASS: LD/ST data, offsets, dependencies, two-phase timing, R0 and HALT");
        $finish;
    end
    initial begin
        #10000; $fatal(1,"Testbench watchdog timeout");
    end
endmodule

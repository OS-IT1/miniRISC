// Baseline single-cycle MiniRISC datapath with synchronous BRAM load control.
module minirisc_basic_top (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc,
    output wire [31:0] instruction,
    output wire        halted
);
    localparam [1:0] PC_SEQUENTIAL = 2'b00;
    localparam [1:0] PC_BRANCH     = 2'b01;
    localparam [1:0] PC_JUMP       = 2'b10;
    localparam [1:0] PC_REGISTER   = 2'b11;

    wire [3:0] rs1, rs2, rd, alu_control;
    wire reg_write, alu_src_immediate, halt_instruction;
    wire mem_read, mem_write, mem_to_reg, nop;
    wire [1:0] imm_select, branch_kind;
    wire jump, jump_register;
    wire [31:0] read_data1, read_data2, immediate, alu_operand_b;
    wire [31:0] alu_result, data_memory_read, register_write_data;
    wire [31:0] branch_pc, jump_pc, next_pc, rom_pc;
    wire [1:0] pc_select;
    wire branch_taken;
    wire execute_instruction, load_issue, load_commit;
    wire pc_write, rom_enable;
    wire load_wait;

    // Keep the original waveform/testbench probe name for the load wait state.
    assign load_wait = load_commit;

    // PC is the address of the instruction being executed. The PC mux feeds
    // the next fetch address to the synchronous ROM on the same clock edge.
    assign branch_pc = pc + 32'd4 + ({{13{instruction[18]}}, instruction[18:0]} << 2);
    assign jump_pc = {{3{1'b0}}, instruction[26:0], 2'b00};
    assign rom_pc = rst ? pc : (pc_write ? next_pc : pc);
    assign pc_select = jump_register ? PC_REGISTER :
                       jump ? PC_JUMP :
                       (branch_taken ? PC_BRANCH : PC_SEQUENTIAL);

    pc_select_mux pc_mux (
        .select       (pc_select),
        .sequential_pc(pc + 32'd4),
        .branch_pc    (branch_pc),
        .jump_pc      (jump_pc),
        .register_pc  (read_data1),
        .next_pc      (next_pc)
    );

    pc_unit pc0 (
        .clk    (clk),
        .rst    (rst),
        .enable (pc_write),
        .next_pc(next_pc),
        .pc     (pc)
    );

    instruction_bram_rom imem (
        .clka  (clk),
        .ena   (rom_enable),
        .addra (rom_pc[9:2]),
        .douta (instruction)
    );

    instruction_decoder decode (
        .instruction       (instruction),
        .read_addr1        (rs1),
        .read_addr2        (rs2),
        .write_addr        (rd),
        .reg_write         (reg_write),
        .alu_src_immediate (alu_src_immediate),
        .imm_select        (imm_select),
        .alu_control       (alu_control),
        .halt              (halt_instruction),
        .mem_read          (mem_read),
        .mem_write         (mem_write),
        .mem_to_reg        (mem_to_reg),
        .branch_kind       (branch_kind),
        .jump              (jump),
        .jump_register     (jump_register),
        .nop               (nop)
    );

    register_file_16x32 rf (
        .clk          (clk),
        .rst          (rst),
        .read_addr1   (rs1),
        .read_addr2   (rs2),
        .read_data1   (read_data1),
        .read_data2   (read_data2),
        .write_enable ((execute_instruction & reg_write & ~mem_read & ~halt_instruction) |
                       (load_commit & mem_to_reg)),
        .write_addr   (rd),
        .write_data   (register_write_data)
    );

    data_bram_ram dmem (
        .clka  (clk),
        .ena   (load_issue | (execute_instruction & mem_write)),
        .wea   (execute_instruction & mem_write & ~rst),
        .addra (alu_result[7:0]),
        .dina  (read_data2),
        .douta (data_memory_read)
    );

    assign register_write_data = mem_to_reg ? data_memory_read : alu_result;

    immediate_extension_logic immgen (
        .imm19      (instruction[18:0]),
        .imm_select (imm_select),
        .immediate  (immediate)
    );

    alu_input_mux b_mux (
        .register_data    (read_data2),
        .immediate        (immediate),
        .select_immediate (alu_src_immediate),
        .alu_operand_b    (alu_operand_b)
    );

    alu32 alu (
        .A           (read_data1),
        .B           (alu_operand_b),
        .alu_control (alu_control),
        .Y            (alu_result)
    );

    branch_unit branch (
        .branch_kind   (branch_kind),
        .register_value1(read_data1),
        .register_value2(read_data2),
        .branch_taken  (branch_taken)
    );

    baseline_control_unit control (
        .clk                 (clk),
        .rst                 (rst),
        .mem_read            (mem_read),
        .halt_instruction    (halt_instruction),
        .execute_instruction (execute_instruction),
        .load_issue          (load_issue),
        .load_commit         (load_commit),
        .pc_write            (pc_write),
        .rom_enable          (rom_enable),
        .halted              (halted)
    );
endmodule

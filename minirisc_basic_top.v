// Assignment 1B baseline: fetch -> decode -> register file -> ALU -> write-back.
module minirisc_basic_top (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc,
    output wire [31:0] instruction,
    output wire        halted
);

    wire [3:0]  rs1;
    wire [3:0]  rs2;
    wire [3:0]  rd;
    wire [3:0]  alu_control;
    wire        reg_write;
    wire        alu_src_immediate;
    wire        halt_instruction;
    wire [1:0]  imm_select;
    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] immediate;
    wire [31:0] alu_operand_b;
    wire [31:0] alu_result;
    reg         halted_reg;

    // HALT suppresses the increment on the HALT cycle itself, holding its PC.
    pc_unit pc0 (
        .clk    (clk),
        .rst    (rst),
        .enable (~halted_reg & ~halt_instruction),
        .pc     (pc)
    );

    // Byte-addressed PC: a 256-word ROM receives the word address PC[9:2].
    instruction_bram_rom imem (
        .clka  (clk),
        .ena   (~halted_reg),
        .addra (pc[9:2]),
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
        .halt              (halt_instruction)
    );

    register_file_16x32 rf (
        .clk          (clk),
        .rst          (rst),
        .read_addr1   (rs1),
        .read_addr2   (rs2),
        .read_data1   (read_data1),
        .read_data2   (read_data2),
        .write_enable (reg_write & ~halted_reg & ~halt_instruction),
        .write_addr   (rd),
        .write_data   (alu_result)
    );

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
        .Y           (alu_result)
    );

    always @(posedge clk) begin
        if (rst)
            halted_reg <= 1'b0;
        else if (halt_instruction)
            halted_reg <= 1'b1;
    end

    assign halted = halted_reg;

endmodule

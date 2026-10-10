// Datapath: single-cycle instructions plus a two-phase BRAM load.
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
    wire        mem_read;
    wire        mem_write;
    wire        mem_to_reg;
    wire [1:0]  imm_select;
    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] immediate;
    wire [31:0] alu_operand_b;
    wire [31:0] alu_result;
    wire [31:0] data_memory_read;
    wire [31:0] register_write_data;
    wire        load_issue;
    wire        advance_fetch;
    reg         halted_reg;
    reg         load_wait;

    // A BRAM load takes two execute phases: issue the address/read, then
    // write the registered BRAM output while fetching the following word.
    assign load_issue = mem_read & ~load_wait;
    // Hold both PC and synchronous instruction ROM while a load is in flight.
    // Also hold the ROM output on HALT so it remains parked on the HALT word.
    assign advance_fetch = ~halted_reg & ~halt_instruction & ~load_issue;

    // HALT suppresses the increment on the HALT cycle itself, holding its PC.
    pc_unit pc0 (
        .clk    (clk),
        .rst    (rst),
        .enable (advance_fetch),
        .pc     (pc)
    );

    // Byte-addressed PC: a 256-word ROM receives the word address PC[9:2].
    instruction_bram_rom imem (
        .clka  (clk),
        .ena   (advance_fetch),
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
        .halt              (halt_instruction),
        .mem_read          (mem_read),
        .mem_write         (mem_write),
        .mem_to_reg        (mem_to_reg)
    );

    register_file_16x32 rf (
        .clk          (clk),
        .rst          (rst),
        .read_addr1   (rs1),
        .read_addr2   (rs2),
        .read_data1   (read_data1),
        .read_data2   (read_data2),
        .write_enable (reg_write & ~halted_reg & ~halt_instruction & ~load_issue),
        .write_addr   (rd),
        .write_data   (register_write_data)
    );

    // The ALU result is a byte effective address. The BRAM output register
    // captures the word on the LD issue edge and holds it for write-back.
    data_bram_ram dmem (
        .clka  (clk),
        .ena   ((mem_read & ~load_wait) | mem_write),
        .wea   (mem_write & ~rst & ~halted_reg & ~halt_instruction),
        .addra (alu_result[9:2]),
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
        .Y           (alu_result)
    );

    always @(posedge clk) begin
        if (rst) begin
            halted_reg <= 1'b0;
            load_wait <= 1'b0;
        end else begin
            if (halt_instruction)
                halted_reg <= 1'b1;

            if (load_issue)
                load_wait <= 1'b1;
            else if (load_wait)
                load_wait <= 1'b0;
        end
    end

    assign halted = halted_reg;

endmodule

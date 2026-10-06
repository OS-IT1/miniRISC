// Decoder for the opcode map documented in the supplied Assignment 1A report.
module instruction_decoder (
    input wire [31:0] instruction, output reg [3:0] read_addr1, output reg [3:0] read_addr2,
    output reg [3:0] write_addr, output reg reg_write, output reg alu_src_immediate,
    output reg [1:0] imm_select, output reg [3:0] alu_control, output reg halt
);
    wire [4:0] opcode=instruction[31:27];
    localparam [3:0] ALU_ADD=4'h0, ALU_SUB=4'h1, ALU_AND=4'h2, ALU_OR=4'h3,
                     ALU_XOR=4'h4, ALU_NOR=4'h5, ALU_NOT=4'h6, ALU_SLL=4'h7,
                     ALU_SRL=4'h8, ALU_SRA=4'h9, ALU_SLT=4'hA, ALU_LUI=4'hC;
    localparam [1:0] IMM_SIGNED=2'd0, IMM_SHIFT=2'd1, IMM_LUI=2'd2;
    always @(*) begin
        read_addr1=instruction[26:23]; read_addr2=instruction[22:19]; write_addr=4'd0;
        reg_write=1'b0; alu_src_immediate=1'b0; imm_select=IMM_SIGNED;
        alu_control=ALU_ADD; halt=1'b0;
        case (opcode)
            5'b00000: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_ADD; end // ADD
            5'b00001: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_SUB; end // SUB
            5'b00010: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_AND; end // AND
            5'b00011: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_OR; end // OR
            5'b00100: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_XOR; end // XOR
            5'b00101: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_NOR; end // NOR
            5'b00110: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_NOT; end // NOT
            5'b00111: begin write_addr=instruction[22:19]; reg_write=1; alu_control=ALU_SLL; alu_src_immediate=1; imm_select=IMM_SHIFT; end // SLL
            5'b01000: begin write_addr=instruction[22:19]; reg_write=1; alu_control=ALU_SRL; alu_src_immediate=1; imm_select=IMM_SHIFT; end // SRL
            5'b01001: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_SRA; end // SRA
            5'b01010: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_SLL; end // SLA
            5'b01011: begin write_addr=instruction[18:15]; reg_write=1; alu_control=ALU_SLT; end // SLT
            // 01100 is MUL: intentionally deferred to the later assignment.
            5'b01101: begin write_addr=instruction[22:19]; reg_write=1; alu_control=ALU_ADD; alu_src_immediate=1; end // ADDI
            5'b01110: begin write_addr=instruction[22:19]; reg_write=1; alu_control=ALU_SUB; alu_src_immediate=1; end // SUBI
            5'b01111: begin write_addr=instruction[22:19]; reg_write=1; alu_control=ALU_ADD; alu_src_immediate=1; end // MOV
            5'b10000: begin write_addr=instruction[22:19]; reg_write=1; alu_control=ALU_LUI; alu_src_immediate=1; imm_select=IMM_LUI; end // LUI
            5'b11000: halt=1'b1; // HALT
            default: ; // memory/control instructions and reserved opcodes have no side effect in Assignment 1B.
        endcase
    end
endmodule

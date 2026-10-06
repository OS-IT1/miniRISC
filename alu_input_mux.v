module alu_input_mux (
    input wire [31:0] register_data, input wire [31:0] immediate,
    input wire select_immediate, output wire [31:0] alu_operand_b
);
    assign alu_operand_b=select_immediate ? immediate : register_data;
endmodule

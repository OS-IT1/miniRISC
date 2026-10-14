// Select the next byte address for sequential, PC-relative, absolute, or JR flow.
module pc_select_mux (
    input wire [1:0] select,
    input wire [31:0] sequential_pc,
    input wire [31:0] branch_pc,
    input wire [31:0] jump_pc,
    input wire [31:0] register_pc,
    output reg [31:0] next_pc
);
    localparam [1:0] PC_SEQUENTIAL = 2'b00;
    localparam [1:0] PC_BRANCH     = 2'b01;
    localparam [1:0] PC_JUMP       = 2'b10;
    localparam [1:0] PC_REGISTER   = 2'b11;

    always @(*) begin
        case (select)
            PC_BRANCH:   next_pc = branch_pc;
            PC_JUMP:     next_pc = jump_pc;
            PC_REGISTER: next_pc = register_pc;
            default:     next_pc = sequential_pc;
        endcase
    end
endmodule

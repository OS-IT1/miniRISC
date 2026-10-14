// Equality branch decision for BEQ and BNE.
module branch_unit (
    input wire [1:0] branch_kind,
    input wire [31:0] register_value1,
    input wire [31:0] register_value2,
    output reg branch_taken
);
    localparam [1:0] BRANCH_NONE = 2'b00;
    localparam [1:0] BRANCH_EQ   = 2'b01;
    localparam [1:0] BRANCH_NE   = 2'b10;

    always @(*) begin
        case (branch_kind)
            BRANCH_EQ: branch_taken = (register_value1 == register_value2);
            BRANCH_NE: branch_taken = (register_value1 != register_value2);
            default:   branch_taken = 1'b0;
        endcase
    end
endmodule

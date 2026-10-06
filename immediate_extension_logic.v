module immediate_extension_logic (
    input wire [18:0] imm19, input wire [1:0] imm_select, output reg [31:0] immediate
);
    localparam [1:0] IMM_SIGNED=2'd0, IMM_SHIFT=2'd1, IMM_LUI=2'd2;
    always @(*) begin
        case (imm_select)
            IMM_SIGNED: immediate={{13{imm19[18]}},imm19};
            IMM_SHIFT: immediate={27'b0,imm19[4:0]};
            IMM_LUI: immediate={16'b0,imm19[15:0]};
            default: immediate=32'b0;
        endcase
    end
endmodule

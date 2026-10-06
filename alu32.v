// 32-bit combinational ALU for the MiniRISC baseline datapath.
module alu32 (
    input wire [31:0] A, input wire [31:0] B, input wire [3:0] alu_control,
    output reg [31:0] Y
);
    localparam [3:0] ALU_ADD=4'h0, ALU_SUB=4'h1, ALU_AND=4'h2, ALU_OR=4'h3,
                     ALU_XOR=4'h4, ALU_NOR=4'h5, ALU_NOT=4'h6, ALU_SLL=4'h7,
                     ALU_SRL=4'h8, ALU_SRA=4'h9, ALU_SLT=4'hA, ALU_SGT=4'hB,
                     ALU_LUI=4'hC;
    always @(*) begin
        case (alu_control)
            ALU_ADD: Y=A+B; ALU_SUB: Y=A-B; ALU_AND: Y=A&B; ALU_OR: Y=A|B;
            ALU_XOR: Y=A^B; ALU_NOR: Y=~(A|B); ALU_NOT: Y=~A;
            ALU_SLL: Y=A<<B[4:0]; // SLL and register-controlled SLA have identical bits.
            ALU_SRL: Y=A>>B[4:0]; ALU_SRA: Y=$signed(A)>>>B[4:0];
            ALU_SLT: Y=($signed(A)<$signed(B)) ? 32'd1 : 32'd0;
            ALU_SGT: Y=($signed(A)>$signed(B)) ? 32'd1 : 32'd0;
            ALU_LUI: Y={B[15:0],16'b0};
            default: Y=32'b0;
        endcase
    end
endmodule

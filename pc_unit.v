module pc_unit (input wire clk, input wire rst, input wire enable, output reg [31:0] pc);
    always @(posedge clk) begin
        if (rst) pc<=32'b0;
        else if (enable) pc<=pc+32'd4;
    end
endmodule

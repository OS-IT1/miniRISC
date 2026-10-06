// Synchronous ROM, expressed to infer FPGA Block RAM. Address is byte-addressed.
module instruction_bram_rom #(
    parameter ADDR_WIDTH=8, parameter INIT_FILE="program.hex"
) (input wire clk, input wire [31:0] byte_address, output reg [31:0] instruction);
    (* ram_style = "block" *) reg [31:0] rom [0:(1<<ADDR_WIDTH)-1];
    initial begin instruction=32'b0; $readmemh(INIT_FILE,rom); end
    always @(posedge clk) instruction <= rom[byte_address[ADDR_WIDTH+1:2]];
endmodule

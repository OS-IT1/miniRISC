// Simulation-only replacement for the generated Vivado instruction_rom IP.
// Do not synthesize it or add it alongside the generated instruction_rom IP.
module instruction_rom (
    input wire clka, input wire ena, input wire [7:0] addra,
    output reg [31:0] douta
);
    reg [31:0] memory [0:255];
    initial begin
        douta=32'b0;
        $readmemh("program.hex",memory);
    end
    // One-cycle synchronous read, matching the configured BRAM IP.
    always @(posedge clka)
        if (ena) douta <= memory[addra];
endmodule

// Simulation-only replacement for the generated Vivado data_ram_ip.
// Do not synthesize it or add it alongside the generated IP.
module data_ram_ip (
    input wire clka,
    input wire ena,
    input wire wea,
    input wire [7:0] addra,
    input wire [31:0] dina,
    output reg [31:0] douta
);
    reg [31:0] memory [0:255];
    integer i;

    initial begin
        douta = 32'b0;
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 32'b0;
    end

    // Synchronous read and write, matching the recommended Block RAM setup.
    // No Change mode holds douta when writing.
    always @(posedge clka) begin
        if (ena) begin
            if (wea)
                memory[addra] <= dina;
            else
                douta <= memory[addra];
        end
    end
endmodule

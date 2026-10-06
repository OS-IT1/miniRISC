// Adapter for the Vivado Block Memory Generator instruction ROM.
// Generate an IP named instruction_rom with visible ports:
// clka, ena, addra[7:0], douta[31:0].
module instruction_bram_rom (
    input wire clka, input wire ena, input wire [7:0] addra,
    output wire [31:0] douta
);
    instruction_rom rom_ip (
        .clka(clka), .ena(ena), .addra(addra), .douta(douta)
    );
endmodule

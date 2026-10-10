// Adapter for the Vivado data_ram_ip memory.
// Configure a 256 x 32 single-port Block RAM with synchronous read and write,
// optional output register disabled, and visible ports clka, ena, wea,
// addra[7:0], dina[31:0], and douta[31:0]. BRAM read data is still clocked
// with the optional output register disabled; LD needs a later write-back
// cycle unless the memory is changed to a zero-latency distributed RAM.
module data_bram_ram (
    input wire clka,
    input wire ena,
    input wire wea,
    input wire [7:0] addra,
    input wire [31:0] dina,
    output wire [31:0] douta
);
    data_ram_ip ram_ip (
        .clka(clka),
        .ena(ena),
        .wea(wea),
        .addra(addra),
        .dina(dina),
        .douta(douta)
    );
endmodule

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
    reg [255:0] data_set;
    integer i;

    initial begin
        douta = 32'b0;
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 32'b0;
        if (!$value$plusargs("DATA=%s", data_set))
            data_set = "assignment7";
        if (data_set == "assignment5") begin
            // Assignment 5 dot-product vectors, addressed by 32-bit words.
            memory[0] = 32'd2;
            memory[1] = -32'd1;
            memory[2] = 32'd3;
            memory[4] = 32'd4;
            memory[5] = 32'd5;
            memory[6] = 32'd6;
        end else if (data_set == "assignment6") begin
            memory[0] = 32'd10;
            memory[1] = 32'd20;
            memory[2] = 32'd30;
            memory[3] = 32'd40;
        end else begin
            // Assignment 7 matrix inputs, matching data.coe.
            memory[0] = 32'd1;
            memory[1] = 32'd2;
            memory[2] = 32'd3;
            memory[3] = 32'd4;
            memory[4] = 32'd5;
            memory[5] = 32'd6;
            memory[6] = 32'd7;
            memory[7] = 32'd8;
        end
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

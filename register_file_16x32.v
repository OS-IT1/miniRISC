module register_file_16x32 (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  read_addr1,
    input  wire [3:0]  read_addr2,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    input  wire        write_enable,
    input  wire [3:0]  write_addr,
    input  wire [31:0] write_data
);

    reg [31:0] registers [0:15];

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1)
                registers[i] <= 32'b0;
        end
        else begin
            if (write_enable && (write_addr != 4'd0))
                registers[write_addr] <= write_data;
        end
    end

    assign read_data1 = (read_addr1 == 4'd0) ? 32'b0 : registers[read_addr1];

    assign read_data2 = (read_addr2 == 4'd0) ? 32'b0 : registers[read_addr2];

endmodule
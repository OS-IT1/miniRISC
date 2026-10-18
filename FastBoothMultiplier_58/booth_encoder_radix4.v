`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Group Number: 58
// Group Members (Name and Roll Number):
// 1. Rishi Songirkar(24CS10071)
// 2. Tirth Patel (24CS10046)
// Course: Computer Organization and Architecture Laboratory
// Assignment: Verilog Assignment 6
// Problem: Fast Boot Multiplier
// Date: 07/09/2026
//////////////////////////////////////////////////////////////////////////////////

module booth_encoder_radix4 (
    input wire [2:0] booth_bits,
    output reg [2:0] d
);
    always @(*) begin
        case (booth_bits)
            3'b000: d = 3'b010; // 0
            3'b001: d = 3'b011; // +1
            3'b010: d = 3'b011; // +1
            3'b011: d = 3'b100; // +2
            3'b100: d = 3'b000; // -2
            3'b101: d = 3'b001; // -1
            3'b110: d = 3'b001; // -1
            3'b111: d = 3'b010; // 0
            default: d = 3'b010; // 0
        endcase
    end
endmodule

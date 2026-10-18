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

module carry_save_adder_64 (
    input wire [63:0] X,
    input wire [63:0] Y,
    input wire [63:0] Z,
    output wire [63:0] S,
    output wire [63:0] C
);

    assign S = X ^ Y ^ Z;
    assign C = (X & Y) | (Y & Z) | (X & Z);
endmodule
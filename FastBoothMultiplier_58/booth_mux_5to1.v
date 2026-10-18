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

module booth_mux_5to1 (
    input wire [2:0] d,
    input wire signed [63:0] val_zero,
    input wire signed [63:0] val_pos_m,
    input wire signed [63:0] val_pos_2m,
    input wire signed [63:0] val_neg_m,
    input wire signed [63:0] val_neg_2m,
    output reg signed [63:0] selected_val
);
    always @(*) begin
        case (d)
            3'b000: selected_val = val_neg_2m; // -2M
            3'b001: selected_val = val_neg_m;  // -M
            3'b010: selected_val = val_zero;   // 0
            3'b011: selected_val = val_pos_m;  // +M
            3'b100: selected_val = val_pos_2m; // +2M
            default: selected_val = val_zero;  // Default to 0
        endcase
    end
endmodule

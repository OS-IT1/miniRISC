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

module csa_reduction_tree_16to2 (
    input wire signed [63:0] pp0,  input wire signed [63:0] pp1,
    input wire signed [63:0] pp2,  input wire signed [63:0] pp3,
    input wire signed [63:0] pp4,  input wire signed [63:0] pp5,
    input wire signed [63:0] pp6,  input wire signed [63:0] pp7,
    input wire signed [63:0] pp8,  input wire signed [63:0] pp9,
    input wire signed [63:0] pp10, input wire signed [63:0] pp11,
    input wire signed [63:0] pp12, input wire signed [63:0] pp13,
    input wire signed [63:0] pp14, input wire signed [63:0] pp15,

    output wire signed [63:0] row0,
    output wire signed [63:0] row1
);

    wire [63:0] l1_s [4:0];
    wire [63:0] l1_c [4:0];
    
    carry_save_adder_64 csa_l1_0 (.X(pp0),  .Y(pp1),  .Z(pp2),  .S(l1_s[0]), .C(l1_c[0]));
    carry_save_adder_64 csa_l1_1 (.X(pp3),  .Y(pp4),  .Z(pp5),  .S(l1_s[1]), .C(l1_c[1]));
    carry_save_adder_64 csa_l1_2 (.X(pp6),  .Y(pp7),  .Z(pp8),  .S(l1_s[2]), .C(l1_c[2]));
    carry_save_adder_64 csa_l1_3 (.X(pp9),  .Y(pp10), .Z(pp11), .S(l1_s[3]), .C(l1_c[3]));
    carry_save_adder_64 csa_l1_4 (.X(pp12), .Y(pp13), .Z(pp14), .S(l1_s[4]), .C(l1_c[4]));

    wire [63:0] l2_s [2:0];
    wire [63:0] l2_c [2:0];
    
    carry_save_adder_64 csa_l2_0 (.X(l1_s[0]), .Y(l1_s[1]), .Z(l1_s[2]), .S(l2_s[0]), .C(l2_c[0]));
    carry_save_adder_64 csa_l2_1 (.X(l1_s[3]), .Y(l1_s[4]), .Z(l1_c[0]<<1), .S(l2_s[1]), .C(l2_c[1]));
    carry_save_adder_64 csa_l2_2 (.X(l1_c[1]<<1), .Y(l1_c[2]<<1), .Z(l1_c[3]<<1), .S(l2_s[2]), .C(l2_c[2]));

    wire [63:0] l3_s [1:0];
    wire [63:0] l3_c [1:0];
    
    carry_save_adder_64 csa_l3_0 (.X(l2_s[0]), .Y(l2_s[1]), .Z(l2_s[2]), .S(l3_s[0]), .C(l3_c[0]));
    carry_save_adder_64 csa_l3_1 (.X(l2_c[0]<<1), .Y(l2_c[1]<<1), .Z(l2_c[2]<<1), .S(l3_s[1]), .C(l3_c[1]));

    wire [63:0] l4_s [1:0];
    wire [63:0] l4_c [1:0];
    
    carry_save_adder_64 csa_l4_0 (.X(l3_s[0]), .Y(l3_s[1]), .Z(l1_c[4]<<1), .S(l4_s[0]), .C(l4_c[0]));
    carry_save_adder_64 csa_l4_1 (.X(pp15),  .Y(l3_c[0]<<1), .Z(l3_c[1]<<1), .S(l4_s[1]), .C(l4_c[1]));

    wire [63:0] l5_s;
    wire [63:0] l5_c;
    
    carry_save_adder_64 csa_l5_0 (.X(l4_s[0]), .Y(l4_s[1]), .Z(l4_c[0]<<1), .S(l5_s), .C(l5_c));

    wire [63:0] final_c;
    carry_save_adder_64 csa_l6_0 (.X(l5_s), .Y(l5_c<<1), .Z(l4_c[1]<<1), .S(row0), .C(final_c));
    assign row1 = final_c << 1;
endmodule

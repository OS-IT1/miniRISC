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


module fast_booth_multiplier_32 (
    input wire clk,
    input wire reset,
    input wire start,
    input wire signed [31:0] multiplicand,
    input wire signed [31:0] multiplier,
    output wire signed [63:0] product,
    output wire busy,
    output wire done
);
   
    wire load_inputs;
    wire load_product;

    
    multiplier_control ctrl (
        .clk(clk),
        .reset(reset),
        .start(start),
        .load_inputs(load_inputs),
        .load_product(load_product),
        .busy(busy),
        .done(done)
    );

    booth_multiplier_datapath dp (
        .clk(clk),
        .reset(reset),
        .load_inputs(load_inputs),
        .load_product(load_product),
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .product(product)
    );

endmodule

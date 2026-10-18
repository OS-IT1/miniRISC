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
module booth_multiplier_datapath (
    input wire clk,
    input wire reset,
    input wire load_inputs,
    input wire load_product,
    input wire signed [31:0] multiplicand,
    input wire [31:0] multiplier,
    output wire signed [63:0] product
);

    reg signed [31:0] mc_reg;
    reg [31:0] mp_reg;

    always @(posedge clk) begin
        if (reset) begin
            mc_reg <= 32'sd0;
            mp_reg <= 32'd0;
        end else if (load_inputs) begin
            mc_reg <= multiplicand;
            mp_reg <= multiplier;
        end
    end

    wire signed [1023:0] pp_flat;
    partial_product_array pp_gen (
        .multiplicand(mc_reg),
        .multiplier(mp_reg),
        .pp(pp_flat)
    );

    wire signed [63:0] row0;
    wire signed [63:0] row1;
    csa_reduction_tree_16to2 csa_tree (
        .pp0(pp_flat[63:0]),     .pp1(pp_flat[127:64]),   .pp2(pp_flat[191:128]),  .pp3(pp_flat[255:192]),
        .pp4(pp_flat[319:256]),  .pp5(pp_flat[383:320]),  .pp6(pp_flat[447:384]),  .pp7(pp_flat[511:448]),
        .pp8(pp_flat[575:512]),  .pp9(pp_flat[639:576]),  .pp10(pp_flat[703:640]), .pp11(pp_flat[767:704]),
        .pp12(pp_flat[831:768]), .pp13(pp_flat[895:832]), .pp14(pp_flat[959:896]), .pp15(pp_flat[1023:960]),
        .row0(row0),
        .row1(row1)
    );

    wire signed [63:0] final_sum;
    final_adder_64 f_adder (
        .a(row0),
        .b(row1),
        .sum(final_sum)
    );

    reg signed [63:0] prod_reg;
    always @(posedge clk) begin
        if (reset) begin
            prod_reg <= 64'sd0;
        end else if (load_product) begin
            prod_reg <= final_sum;
        end
    end

    assign product = prod_reg;
endmodule

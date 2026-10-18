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


module partial_product_array (
    input wire signed [31:0] multiplicand,
    input wire [31:0] multiplier,
    output wire signed [1023:0] pp
);
    wire signed [63:0] m_64 = {{32{multiplicand[31]}}, multiplicand};
    
    wire signed [63:0] val_zero   = 64'b0;
    wire signed [63:0] val_pos_m  = m_64;
    wire signed [63:0] val_pos_2m = m_64 <<< 1;
    wire signed [63:0] val_neg_m  = -m_64;
    wire signed [63:0] val_neg_2m = - (m_64 <<< 1);
    
    wire [32:0] q_ext = {multiplier, 1'b0};

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_pp
            wire [2:0] booth_bits = q_ext[2*i + 2 : 2*i];
            wire [2:0] d;
            wire signed [63:0] selected_val;

            booth_encoder_radix4 encoder (
                .booth_bits(booth_bits),
                .d(d)
            );

            booth_mux_5to1 mux (
                .d(d),
                .val_zero(val_zero),
                .val_pos_m(val_pos_m),
                .val_pos_2m(val_pos_2m),
                .val_neg_m(val_neg_m),
                .val_neg_2m(val_neg_2m),
                .selected_val(selected_val)
            );

            assign pp[i*64 +: 64] = selected_val <<< (2 * i);
        end
    endgenerate
endmodule

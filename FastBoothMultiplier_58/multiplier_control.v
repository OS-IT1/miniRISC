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


module multiplier_control (
    input wire clk,
    input wire reset,
    input wire start,
    output reg load_inputs,
    output reg load_product,
    output reg busy,
    output reg done
);
    localparam  IDLE     = 2'b00;
    localparam  COMPUTE  = 2'b01;
    localparam  DONE_ST  = 2'b10;

    reg [1:0] state, next_state;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        load_inputs  = 1'b0;
        load_product = 1'b0;
        busy         = 1'b0;
        done         = 1'b0;
        next_state   = state;

        case (state)
            IDLE: begin
                if (start) begin
                    load_inputs  = 1'b1;
                    busy         = 1'b1;
                    next_state   = COMPUTE;
                end
            end

            COMPUTE: begin
                busy         = 1'b1;
                load_product = 1'b1;
                next_state   = DONE_ST;
            end

            DONE_ST: begin
                done         = 1'b1;
                if (start) begin
                    load_inputs  = 1'b1;
                    busy         = 1'b1;
                    next_state   = COMPUTE;
                end else begin
                    next_state   = DONE_ST;
                end
            end

            default: next_state = IDLE;
        endcase
    end
endmodule

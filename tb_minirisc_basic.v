`timescale 1ns/1ps
module tb_minirisc_basic;
    reg clk=1'b0, rst=1'b1;
    wire [31:0] pc,instruction; wire halted;
    minirisc_basic_top dut
      (.clk(clk),.rst(rst),.pc(pc),.instruction(instruction),.halted(halted));
    always #5 clk=~clk;
    initial begin
        $dumpfile("minirisc_basic.vcd"); $dumpvars(0,tb_minirisc_basic);
        repeat(2) @(posedge clk); rst=0; wait(halted); @(posedge clk);
        if(dut.rf.registers[1]!==32'd5) $fatal(1,"ADDI write-back failed");
        if(dut.rf.registers[2]!==32'd7) $fatal(1,"second ADDI failed");
        if(dut.rf.registers[3]!==32'd12) $fatal(1,"ADD/two reads failed");
        if(dut.rf.registers[4]!==32'd2) $fatal(1,"SUB failed");
        if(dut.rf.registers[5]!==32'd5) $fatal(1,"AND failed");
        if(dut.rf.registers[6]!==32'd40) $fatal(1,"SLL failed");
        if(dut.rf.registers[7]!==32'd20) $fatal(1,"SRL failed");
        if(dut.rf.registers[8]!==32'hFFFFFFFF) $fatal(1,"negative immediate extension failed");
        if(dut.rf.registers[10]!==32'd1) $fatal(1,"signed SLT failed");
        if(dut.rf.registers[0]!==32'd0) $fatal(1,"R0 was modified");
        $display("PASS: Assignment 1B baseline datapath checks completed."); $finish;
    end
endmodule

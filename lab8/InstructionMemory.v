`timescale 1ns / 1ps
//============================================================================
//  InstructionMemory.v  ——  Lab 8 指令存储器 (ROM, 64 x 32bit)
//============================================================================
//  来源  : ETH DDCA Lab 8 官方 (逻辑未改)
//  改动  : 新增 MEMFILE 参数, 默认 "insmem_h.txt"。这样 testbench 可以
//          用不同文件名注入自己的测试程序, 而不必改动模块本身。
//          上板综合/默认仿真时路径回退到默认值, 行为与官方完全一致。
//============================================================================
module InstructionMemory(
     input   [5:0] A,   // Address of the Instruction, max 64 instructions (PC[7:2])
     output [31:0] RD   // Value at Address
    );

   parameter MEMFILE = "insmem_h.txt";

   reg [31:0] InsArr [63:0];  // Array holding the memory, 64 entries each 32 bits

   initial
     begin
       $readmemh(MEMFILE, InsArr);  // Initialize the array with this content
     end

   assign RD = InsArr[A];   // Read Data (RD) corresponds to Address (A)

endmodule
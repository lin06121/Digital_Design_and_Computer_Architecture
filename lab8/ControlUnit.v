`timescale 1ns / 1ps
//============================================================================
//  ControlUnit.v  ——  Lab 8 控制单元 (ETH DDCA 官方原版, 逻辑未改)
//============================================================================
//  来源  : Lab 8 官方骨架, 无 TODO, 属"已给好、不用改"的文件
//  功能  : 依据 Op[5:0](Instr[31:26]) 与 Funct[5:0] 生成全部主控制信号 + ALUControl
//
//  主控制信号 (与教材表 7.5 基本一致, don't-care 大多映射成 0):
//      RegWrite = RTYPE | LW | ADDI
//      ALUSrc   = LW | SW | ADDI            (选 立即数/寄存器)
//      RegDst   = RTYPE                      (选 rd/rt)
//      Branch   = BEQ
//      MemWrite = SW
//      MemtoReg = LW
//      Jump     = J
//
//  ALUControl[5:0] (注意官方这里给 6 位, 处理器里只用低 4 位 [3:0]):
//      LW/SW/ADDI -> 6'b100000 (ADD, 低4位=0000)
//      BEQ        -> 6'b100010 (SUB, 低4位=0010)
//      R-type     -> Funct      (直接透传, 低4位即 aluop)
//============================================================================
module ControlUnit(
      input  [5:0] Op,
      input  [5:0] Funct,
      output       Jump,
      output       MemtoReg,
      output       MemWrite,
      output       Branch,
      output [5:0] ALUControl,
      output       ALUSrc,
      output       RegDst,
      output       RegWrite
    );

// DEFINE SOME CONSTANTS
localparam [5:0] OP_RTYPE = 6'b000000;  // R-Type
localparam [5:0] OP_LW    = 6'b100011;  // Load Word
localparam [5:0] OP_SW    = 6'b101011;  // Store Word
localparam [5:0] OP_BEQ   = 6'b000100;  // Branch on Equal
localparam [5:0] OP_ADDI  = 6'b001000;  // ADD immediate
localparam [5:0] OP_J     = 6'b000010;  // Jump

// Write back to registers when Op is RTYPE or LW or ADDI
assign RegWrite = (Op == OP_RTYPE) | (Op == OP_LW) | (Op == OP_ADDI);
// Select the ALU's B input (immediate for LW/SW/ADDI)
assign ALUSrc   = (Op == OP_LW) | (Op == OP_SW) | (Op == OP_ADDI);

// Simple assignments
assign RegDst   = (Op == OP_RTYPE);
assign Branch   = (Op == OP_BEQ);
assign MemWrite = (Op == OP_SW);
assign MemtoReg = (Op == OP_LW);
assign Jump     = (Op == OP_J);

// ALU controls
assign ALUControl = ALUSrc ? 6'b100000 :   // LW/SW/ADDI -> ADD
                    Branch ? 6'b100010 :   // BEQ        -> SUB
                             Funct;        // R-Type     -> do what Funct says

endmodule
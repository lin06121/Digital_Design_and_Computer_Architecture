`timescale 1ns / 1ps
//============================================================================
//  ALU.v  ——  Lab 8 的 32 位 ALU (ETH DDCA 官方原版, 逻辑未改)
//============================================================================
//  来源  : Lab 5 官方参考答案 (Frank K. Gurkaynak), 这版是 Lab 8 处理器里的那一个
//  接口  : a, b(32bit 操作数), aluop[3:0](4bit 操作码), result, zero
//
//  aluop 编码 = R 型指令的 Funct 字段低 4 位 [3:0], 与本仓库 Lab 5 的 alu.sv 完全一致:
//      ADD=0000  SUB=0010  AND=0100  OR=0101  XOR=0110  NOR=0111  SLT=1010
//  结构 : logicsel=aluop[1:0] 选逻辑门;  aluop[1] 选加减;  aluop[1:0]=10 时做减法;
//         减法的进位位作为 slt 结果;  aluop[3] 选 slt;  aluop[2] 选逻辑 vs 算术。
//============================================================================
module ALU(
   input  [31:0] a,
   input  [31:0] b,
   input  [3:0] aluop,
   output [31:0] result,
   output zero
    );

  wire [31:0] logicout;   // output of the logic block
  wire [31:0] addout;     // adder subtractor out
  wire [31:0] arithout;   // output after slt mux
  wire [31:0] n_b;        // inverted b
  wire [31:0] sel_b;      // select b or n_b
  wire [31:0] slt;        // output of the slt extension

  wire [1:0] logicsel;    // lower two bits of aluop

  // logic select
  assign logicsel = aluop[1:0];
  assign logicout = (logicsel == 2'b00) ? a & b :
                    (logicsel == 2'b01) ? a | b :
                    (logicsel == 2'b10) ? a ^ b :
                                          ~(a | b) ;

  // adder subtractor
  assign n_b   = ~b ;
  assign sel_b = (aluop[1]) ? n_b : b ;
  assign addout = a + sel_b + aluop[1];

  // set less than operator
  assign slt = {31'b0, addout[31]};

  // arith out
  assign arithout = (aluop[3]) ? slt : addout;

  // final out
  assign result = (aluop[2]) ? logicout : arithout;
  // the zero
  assign zero = (result == 32'b0) ? 1 : 0;

endmodule
`timescale 1ns / 1ps
//============================================================================
//  RegisterFile.v  ——  Lab 8 寄存器堆 (重写为可移植版本)
//============================================================================
//  为什么重写:
//    官方原版内部用两个 Xilinx 原语 reg_half (.ngc 网表 / DIST_MEM_GEN 原语),
//    只能在 Vivado 里用, Questa/Quartus 都编译不了 —— 这里改成一个
//    reg [31:0] rf [31:0] (32x32bit), 端口保持不变 (A1/A2/A3/RD1/RD2/WD3/WE3/CLK),
//    处理器 MIPS.v 里的实例化完全不用改。
//
//  顺手修掉官方一个 bug:
//    官方写的是  assign RD1 = (A1 != 4'b0000) ? Read1 : 0;
//    A1 是 5 位, 却跟 4 位常量比, 宽度先被截断 —— $16(10000) 会被误判成 $0。
//    这里统一用 5'd0 比较。
//
//  语义:
//    * 读是组合逻辑; $0 恒读 0。
//    * 写在时钟上升沿; 写 $0 被忽略 (保证 $0 永远为 0, 不会因 MARS 的 nop
//      被控制单元解码成 R 型并写回 rd=0 而污染)。
//    * 无需复位: 复位期间控制器不使能写 (处理器首拍取 nop, RegWrite 不落新值)。
//============================================================================
module RegisterFile(
          input   [4:0] A1,   // selects one of 32 registers (rs)
          output [31:0] RD1,  // register corresponding to A1
          input   [4:0] A2,   // selects one of 32 registers (rt)
          output [31:0] RD2,  // register corresponding to A2
          input   [4:0] A3,   // selects the address for writeback
          input  [31:0] WD3,  // Write-back data, written to address A3
          input         WE3,  // Write-enable WE3=1 writes WD3 to A3
          input         CLK   // System clock
    );

    reg [31:0] rf [31:0];   // 32 个 32 位寄存器

    // 组合读: $0 恒为 0
    assign RD1 = (A1 == 5'd0) ? 32'h0 : rf[A1];
    assign RD2 = (A2 == 5'd0) ? 32'h0 : rf[A2];

    // 同步写: 写 $0 忽略
    always @ (posedge CLK)
        if (WE3 && (A3 != 5'd0))
            rf[A3] <= WD3;

endmodule
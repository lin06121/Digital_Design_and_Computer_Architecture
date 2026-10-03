`timescale 1ns / 1ps
//============================================================================
//  tb_lab8_sw.sv  ——  顶层开关多路器 (MMIO 输入) 自检 (Questa)
//============================================================================
//  Lab 8 Part 2 的硬件要点: 处理器能把板上的 2 位开关 SW[1:0] 读进来。
//  路径: SW -> top.IOReadData 多路器(IOAddr==4 -> {30'b0,SW}) -> MIPS 内部
//        -> sw $t0, 0x7ff0 写回 -> DispReg -> HEX0 低两位。
//
//  用 sw_readback.asm 汇编成的内存 dump 注入 top, 程序只做两件事:
//        lw  $t0, 0x7ff4($0)   // 读开关
//        sw  $t0, 0x7ff0($0)   // 写回显示
//  设置 SW = 2'b10 (值 2), 期望显示寄存器 = 0x00000002, 于是
//  DispReg[1:0] = 2'b10 -> HEX0[1] = 0(亮 b 段), HEX0[0] = 1(灭 a 段),
//  其余段全灭:  HEX0 = ~7'b0000010 = 7'b1111101。
//
//  这一步把 Part2 的开关读入链路 (SW -> IOReadData -> 处理器 -> 显示) 完整覆盖。
//============================================================================
module tb_lab8_sw;

  logic       clk50 = 0;
  logic [1:0] sw    = 2'b10;     // 开关值 = 2
  logic       key   = 1;         // KEY[0] 低有效; 初始 1 = 未按下
  wire [6:0]  hex0, hex1, hex2, hex3, hex4, hex5;

  // 注入开关回读程序 (用参数指定内存文件)
  top #(
    .IMEM_FILE("sw_readback_insmem_h.txt"),
    .DMEM_FILE("sw_readback_datamem_h.txt")
  ) dut (
    .CLOCK_50(clk50),
    .SW(sw),
    .KEY(key),
    .HEX0(hex0), .HEX1(hex1), .HEX2(hex2),
    .HEX3(hex3), .HEX4(hex4), .HEX5(hex5)
  );

  // 50 MHz 系统时钟 (周期 20ns)
  always #10 clk50 = ~clk50;

  integer errors = 0;
  logic   seen   = 0;

  initial begin
    key = 1'b0;                      // 按下复位
    repeat (20) @(posedge clk50);
    key = 1'b1;                      // 松开复位

    // 轮询等程序把开关值写回显示: HEX0 != 全灭(7'h7F)
    for (integer i = 0; i < 200000; i++) begin
      @(posedge clk50);
      if (hex0 !== 7'h7F) begin
        seen = 1;
        break;
      end
    end

    if (!seen) begin
      $fatal(1, "tb_lab8_sw: 超时, 显示寄存器没出现开关回读值");
    end

    // SW=2'b10 -> 期望 HEX0 = ~7'b0000010 = 7'b1111101
    if (hex0 !== 7'b1111101) begin
      $display("ERROR: HEX0 = %b, 期望 1111101 (SW=2 -> 只亮段 b)", hex0);
      errors = errors + 1;
    end else begin
      $display("  OK : HEX0 = %b, 开关回读值 SW=2 正确", hex0);
    end

    // 其余数码管不应点亮
    if (hex1 !== 7'h7F || hex2 !== 7'h7F || hex3 !== 7'h7F ||
        hex4 !== 7'h7F || hex5 !== 7'h7F) begin
      $display("ERROR: 其余数码管不应点亮 (实际 %b %b %b %b %b)",
               hex1, hex2, hex3, hex4, hex5);
      errors = errors + 1;
    end

    if (errors != 0) $fatal(1, "tb_lab8_sw: %0d 个错误", errors);

    $display("=== PASS tb_lab8_sw: 开关读入链路 (SW=2 -> HEX0 b段) 正确 ===");
    $finish;
  end

endmodule
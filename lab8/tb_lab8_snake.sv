`timescale 1ns / 1ps
//============================================================================
//  tb_lab8_snake.sv  ——  官方蛇程序 + DE1-SoC 顶层 首帧检查 (Questa)
//============================================================================
//  实例化完整顶层 top (含 clockdiv / 复位取反 / 7 段映射), 跑官方的
//  snake 内存 dump (insmem_h.txt / datamem_h.txt)。
//
//  复位释放后, 蛇程序的第一条 sw $t0, 0x7ff0($0) 会写入第一张图案
//  pattern[0] = 0x00200000, 即 28 位显示寄存器里只有 bit21 为 1。
//  bit21 落在 DispReg[27:21] -> HEX3 的段 0 (a 段):
//
//      HEX3 = ~7'b0000001 = 7'b1111110  (只亮 a 段)
//      HEX0 = HEX1 = HEX2 = 7'b1111111  (不亮)
//
//  本 tb 轮询等第一张图案出现, 并校验上述映射 + 复位取反 + 时钟分频都正确。
//============================================================================
module tb_lab8_snake;

  logic       clk50 = 0;
  logic [1:0] sw    = 2'b00;
  logic       key   = 1;          // KEY[0] 低有效; 初始 1 = 未按下
  wire [6:0]  hex0, hex1, hex2, hex3, hex4, hex5;

  top dut (
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
    key = 1'b0;                      // 按下复位 (KEY 低有效 -> RESET=1)
    repeat (20) @(posedge clk50);
    key = 1'b1;                      // 松开复位

    // 轮询等第一张图案: 复位后 HEX 全灭(7'h7F), 花点时间等第一个 sw 0x7ff0 落地
    for (integer i = 0; i < 200000; i++) begin
      @(posedge clk50);
      if (hex3 !== 7'h7F) begin
        seen = 1;
        break;
      end
    end

    if (!seen) begin
      $fatal(1, "tb_lab8_snake: 超时, 数码管没出现第一张图案");
    end

    // 第一张图案 = 0x00200000 -> 只点亮 HEX3 的段 0
    if (hex3 !== 7'h7E) begin
      $display("ERROR: HEX3 = %b, 期望 1111110 (只亮段0)", hex3);
      errors = errors + 1;
    end else begin
      $display("  OK : HEX3 = %b, 第一张图案(段0)正确", hex3);
    end

    if (hex0 !== 7'h7F || hex1 !== 7'h7F || hex2 !== 7'h7F) begin
      $display("ERROR: HEX0/1/2 不应点亮 (实际 %b %b %b)", hex0, hex1, hex2);
      errors = errors + 1;
    end else begin
      $display("  OK : HEX0/1/2 未点亮");
    end

    if (errors != 0) $fatal(1, "tb_lab8_snake: %0d 个错误", errors);

    $display("=== PASS tb_lab8_snake: 官方蛇程序 + DE1-SoC 顶层 首帧正确 ===");
    $finish;
  end

endmodule
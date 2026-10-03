`timescale 1ns / 1ps
//============================================================================
//  tb_lab8.sv  ——  MIPS 处理器微程序自检 testbench (Questa)
//============================================================================
//  用一个手编的 13 条指令微程序把 MIPS 的完整通路一次性测遍:
//
//      addi $t0,$0,5          -> $t0 = 5
//      addi $t1,$0,3          -> $t1 = 3
//      add  $t2,$t0,$t1       -> $t2 = 8   (R 型 ADD)
//      sub  $t3,$t0,$t1       -> $t3 = 2   (R 型 SUB)
//      slt  $t4,$t1,$t0       -> $t4 = 1   (R 型 SLT)
//      sw   $t2,0($0)         -> 数据内存[0] = 8  (DataMemWrite 通路)
//      lw   $t5,0($0)         -> $t5 = 8   (MemtoReg 读数据内存)
//      sw   $t5,0x7ff0($0)    -> I/O 写 8
//      sw   $t3,0x7ff0($0)    -> I/O 写 2
//      sw   $t4,0x7ff0($0)    -> I/O 写 1
//      lw   $t6,0x7ff4($0)    -> $t6 = IOReadData (I/O 读通路)
//      sw   $t6,0x7ff0($0)    -> I/O 写读回值
//      j    .                 -> 自旋
//
//  期望捕获到的 4 次 MMIO 写按顺序是  8 -> 2 -> 1 -> 0xABCD1234(回读值)。
//  机器码见 tb_insmem_h.txt; 用 IMEM_FILE/DMEM_FILE 参数注入微程序。
//============================================================================
module tb_lab8;

  logic        clk     = 0;
  logic        reset   = 1;
  logic [31:0] iowrite;
  logic [3:0]  ioaddr;
  logic        iowen;
  logic [31:0] ioread  = 32'hABCD1234;   // 模拟外设读入值

  // 期望的 4 次 I/O 写值
  logic [31:0] expected [0:3];
  int          exp_idx  = 0;
  int          captured = 0;
  int          errors   = 0;

  // 被测对象: MIPS, 注入微程序 (用参数指定内存文件)
  MIPS #(
        .IMEM_FILE("tb_insmem_h.txt"),
        .DMEM_FILE("tb_datamem_h.txt")
       ) dut (
        .CLK(clk),
        .RESET(reset),
        .IOWriteData(iowrite),
        .IOAddr(ioaddr),
        .IOWriteEn(iowen),
        .IOReadData(ioread)
       );

  // 100 MHz 时钟 (周期 10ns)
  always #5 clk = ~clk;

  // 在下降沿采样: 此刻组合逻辑稳定、且处在指令周期中部, 避免与 PC 更新的竞争
  always @(negedge clk) begin
    if (!reset && iowen) begin
      if (exp_idx < 4 && iowrite !== expected[exp_idx]) begin
        $display("ERROR: IO 写 #%0d 得到 %h, 期望 %h (IOAddr=%h)",
                 exp_idx, iowrite, expected[exp_idx], ioaddr);
        errors = errors + 1;
      end else begin
        $display("  OK : IO 写 #%0d = %h", exp_idx, iowrite);
      end
      exp_idx  = exp_idx  + 1;
      captured = captured + 1;
    end
  end

  initial begin
    expected[0] = 32'd8;           // add
    expected[1] = 32'd2;           // sub
    expected[2] = 32'd1;           // slt
    expected[3] = 32'hABCD1234;    // I/O 读回值

    reset = 1'b1;
    repeat (8) @(negedge clk);     // 保持复位几拍
    reset = 1'b0;

    // 最多等 200 拍等满 4 次 IO 写
    for (integer i = 0; i < 200 && captured < 4; i++) @(negedge clk);

    if (captured < 4) begin
      $fatal(1, "tb_lab8: 超时, 只捕获到 %0d 次 IO 写 (期望 4)", captured);
    end
    if (errors != 0) begin
      $fatal(1, "tb_lab8: %0d 个错误", errors);
    end

    $display("=== PASS tb_lab8: 微程序 4 次 IO 写 (8,2,1,回读值) 全部正确 ===");
    $finish;
  end

endmodule
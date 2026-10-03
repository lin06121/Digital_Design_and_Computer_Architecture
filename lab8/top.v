`timescale 1ns / 1ps
//============================================================================
//  top.v  ——  Lab 8 顶层 (移植到 DE1-SoC)
//============================================================================
//  官方 top.v 面向 Basys3 (4 位共阳数码管 + 扫描 AN[3:0] + 共享 7 段总线)。
//  DE1-SoC 有 6 个【独立】共阳数码管 HEX0~HEX5, 每位数码管自带 7 段线, 无 AN 扫描
//  —— 所以这里把 28 位显示寄存器的 4 个 7 位切片直接并行接到 HEX0~HEX3,
//    HEX4/HEX5 悬空(全灭)。
//
//  相比官方的改动:
//    (1) 复位 : DE1-SoC 的 KEY[0] 低有效, 取反得到高有效的 RESET。
//    (2) 数码管: 4 位蛇接 HEX0(LSB数字) ~ HEX3(MSB数字)。
//    (3) Part2 : 新增 2 位开关 SW[1:0] 读入, 挂在 I/O 寄存器 0x7FF4 (IOAddr==4)。
//
//  I/O 寄存器表 (官方 Lab 8.2):
//      0x7FF0  out  28bit  要送到 7 段显示的 28 位值 (IOWriteData[27:0])
//      0x7FF4  in   2bit   速度档 SW[1:0] (IOAddr 的低位为 4)
//============================================================================
module top #(
        // 内存文件参数: 默认加载官方蛇程序; testbench 用来注入自编程序 (开关回读等)
        parameter IMEM_FILE = "insmem_h.txt",
        parameter DMEM_FILE = "datamem_h.txt"
    )(
        input  wire       CLOCK_50,   // 50 MHz 系统时钟 (PIN_AF14)
        input  wire [1:0] SW,         // 速度档开关 SW[1:0] (SW[0]=LSB)
        input  wire       KEY,        // KEY[0], 低有效复位
        output wire [6:0] HEX0,       // 七段码 (段低有效), 蛇的四位数字分别接 0~3
        output wire [6:0] HEX1,
        output wire [6:0] HEX2,
        output wire [6:0] HEX3,
        output wire [6:0] HEX4,       // 未用, 全灭
        output wire [6:0] HEX5        // 未用, 全灭
    );

    wire RESET = ~KEY;                // KEY[0] 低有效 -> 模块内统一用高有效复位

    // ---------- 时钟: 50 MHz -> 12.5 MHz ----------
    wire CLK;                         // 分频后时钟 (内部处理器的时钟)
    clockdiv u_clkdiv (
        .clk(CLOCK_50),
        .rst(RESET),
        .clk_en(CLK)
    );

    // ---------- MIPS 接口 ----------
    wire [31:0] IOWriteData;
    wire [3:0]  IOAddr;
    wire        IOWriteEn;
    wire [31:0] IOReadData;

    // ---------- 显示寄存器: 28 位, 存 "要显示在 4 位数码管上的图案" ----------
    reg [27:0] DispReg;
    always @ (posedge CLK or posedge RESET)
        if      (RESET)     DispReg <= 28'h0;         // 复位清空
        else if (IOWriteEn) DispReg <= IOWriteData[27:0];

    // ---------- Part2: 开关读入 (I/O 寄存器 0x7FF4) ----------
    // IOAddr = ALUResult[3:0]; 地址 0x7FF4 -> 低 4 位 = 4'h4。
    // 只用 2 个 LSB 读开关, 其余位补 0。
    assign IOReadData = (IOAddr == 4'h4) ? {30'b0, SW[1:0]} : 32'h0;

    // ---------- 处理器 ----------
    MIPS #(
        .IMEM_FILE(IMEM_FILE),
        .DMEM_FILE(DMEM_FILE)
    ) u_mips (
        .CLK(CLK),
        .RESET(RESET),
        .IOWriteData(IOWriteData),
        .IOAddr(IOAddr),
        .IOWriteEn(IOWriteEn),
        .IOReadData(IOReadData)
    );

    // ---------- 7 段映射: 4 位蛇并行驱动 HEX0~HEX3 (共阳, 段低有效) ----------
    assign HEX0 = ~DispReg[6:0];       // 最低位数字
    assign HEX1 = ~DispReg[13:7];
    assign HEX2 = ~DispReg[20:14];
    assign HEX3 = ~DispReg[27:21];     // 最高位数字
    assign HEX4 = 7'h7F;               // 未用 -> 全灭 (低有效故全 1)
    assign HEX5 = 7'h7F;

endmodule
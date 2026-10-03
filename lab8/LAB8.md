# Lab 8 —— Full System Integration（单周期 MIPS 处理器 + 七段爬行蛇）

本 Lab 把 Harris & Harris 图 7.14 的单周期 MIPS 处理器完整拼起来，装进 DE1-SoC，
跑一个「单个灯珠沿 4 位数码管蛇形爬行」的演示程序。官方材料面向 Basys3 + Vivado，
这份移植做了三处平台适配：**时钟分频、复位取反、7 段数码管并行驱动**，并补上了
官方 Part 2 的**开关调速**。

> 最重要的结论：官方 Lab 8 的蛇跑在 **7 段数码管**上，不是 VGA。checklist 里
> 「VGA 蛇」是旧描述，`top.v`/`top.xdc` 实为 4 位 7 段显示。

---

## 一、文件清单

| 文件 | 类型 | 说明 |
|---|---|---|
| `MIPS.v` | RTL | **处理器顶层**，官方骨架，需填 4 处实例化 + 4 处 MMIO 赋值（已填） |
| `ALU.v` | RTL | 官方原样，7 种运算编码 = `aluop[3:0]` = `Funct[3:0]`，与 lab5 完全一致 |
| `ControlUnit.v` | RTL | 官方原样（主译码 + ALU 译码） |
| `InstructionMemory.v` | RTL | 64×32b 指令存储器，`$readmemh` 读 dump |
| `DataMemory.v` | RTL | 64×32b 数据存储器，`$readmemh` 读 dump |
| `RegisterFile.v` | RTL | **重写**（官方 `reg_half` 是 Xilinx 原语，Quartus/Questa 用不了；顺带修 `$0` 判定位宽 bug） |
| `clockdiv.v` | RTL | 官方原样，50 MHz ÷ 4 = 12.5 MHz |
| `top.v` | RTL | **重写**：DE1-SoC 顶层（时钟/复位/数码管/开关） |
| `insmem_h.txt` / `datamem_h.txt` | 数据 | 官方蛇程序内存 dump（part 1） |
| `snake_patterns.asm` | 汇编 | 官方蛇程序（带注释） |
| `snake_patterns_speed.asm` | 汇编 | Part 2 开关调速版 |
| `insmem_h_speed.txt` / `datamem_h_speed.txt` | 数据 | Part 2 dump（由 `asm.py` 生成） |
| `asm.py` | 工具 | 迷你 MIPS 汇编器（**替代 MARS**，本机无 Java） |
| `sw_readback.asm` + 两个 dump | 测试 | 开关回读小测试程序（验证顶层 MMIO 输入） |
| `tb_lab8.sv` + `tb_insmem_h.txt`/`tb_datamem_h.txt` | 仿真 | 微程序自检测 testbench |
| `tb_lab8_snake.sv` | 仿真 | 官方蛇程序 + 顶层首帧检查 |
| `tb_lab8_sw.sv` | 仿真 | Part 2 开关读入链路检查 |
| `run.sh` | 脚本 | Questa 一键仿真（三遍全 PASS） |
| `lab8_top.qsf` / `lab8_top.qpf` | 工程 | Quartus 综合/下载工程 |

---

## 二、MIPS.v：官方骨架待填的部分

官方骨架里留了 8 处要求你自己补的空，都在 [MIPS.v](MIPS.v) 里填好了：

**（1）四个子模块实例化**

| 实例化 | 关键连线 |
|---|---|
| 指令存储器 | `#(.MEMFILE(IMEM_FILE)) i_imem (.A(PC[7:2]), .RD(Instr))`，PC 取 `[7:2]` 得 64 字索引 |
| ALU | `i_alu (.a(SrcA), .b(SrcB), .aluop(ALUControl[3:0]), .result(ALUResult), .zero(Zero))`，控制单元给 6 位、ALU 只用低 4 位 |
| 数据存储器 | `#(.MEMFILE(DMEM_FILE)) i_dmem (.CLK(CLK), .A(ALUResult[7:2]), .WE(DataMemWrite), .WD(WriteData), .RD(ReadData))` |
| 控制单元 | `i_cont (.Op(Instr[31:26]), .Funct(Instr[5:0]), …全 8 个输出)` |

**（2）四处 MMIO 赋值**（把「访存」按地址分流到内存 or 外设）

```verilog
assign IsIO        = (ALUResult[31:4] == 28'h00007ff) ? 1 : 0; // 地址落在 0x7FF0..0x7FFF
assign DataMemWrite = MemWrite & ~IsIO;   // SW 且目标是数据内存
assign IOWriteData  = WriteData;          // 透传寄存器堆 B 口
assign IOAddr       = ALUResult[3:0];     // 低 4 位 = 外设号
assign IOWriteEn    = MemWrite & IsIO;    // SW 且目标在 I/O 段
assign ReadMemIO    = IsIO ? IOReadData : ReadData;  // 读: 内存 or I/O
```

`SW` 到不同地址的语义对照：

| 指令 | `IsIO` | `DataMemWrite` | `IOWriteEn` | 效果 |
|---|---|---|---|---|
| `sw $t, 0x00($0)` | 0 | 1 | 0 | 写数据内存（正常数据） |
| `sw $t, 0x7ff0($0)` | 1 | 0 | 1 | 写外设（刷新显示） |

（3）为方便测试注入程序，`MIPS` 加了 `parameter IMEM_FILE/DMEM_FILE`，默认值与官方一字不差，**不影响上板行为**。

---

## 三、RegisterFile（重写的缘由）

官方 `reg_half.v` 用 Xilinx `DIST_MEM_GEN` 原语（`.ngc`），Quartus/Questa 都不认。
而且官方有句 `A1 != 4'b0000` —— 常量宽度截断成 4 位，会把 `$16`（10000）也判成
`$0`。重写版 [RegisterFile.v](RegisterFile.v)：

```verilog
reg [31:0] rf [31:0];
assign RD1 = (A1 == 5'd0) ? 32'h0 : rf[A1];   // 5'b00000 全宽比较
assign RD2 = (A2 == 5'd0) ? 32'h0 : rf[A2];
always @(posedge CLK)
  if (WE3 && (A3 != 5'd0)) rf[A3] <= WD3;     // 写 $0 被忽略
```
端口 `A1/A2/A3/RD1/RD2/WD3/WE3/CLK` 与官方一致，`$0` 读恒 0、写 `$0` 无效。

---

## 四、top.v：移植到 DE1-SoC 的三处改动

| 官方（Basys3） | DE1-SoC |
|---|---|
| 4 位共阳数码管 + `AN[3:0]` 扫描 + 共享 7 段总线 | 6 位**独立**共阳数码管，无 AN 扫描 → 把 28 位显示寄存器的 4 个 7 位切片并行接 `HEX0~HEX3`，`HEX4/HEX5` 全灭 |
| 复位信号直接正逻辑 | `KEY[0]` 低有效 → `wire RESET = ~KEY` 取反 |
| 无开关 | 新增 `SW[1:0]` 读入，挂 I/O 寄存器 `0x7FF4`（Part 2） |

数码管映射：`HEX0 = ~DispReg[6:0]` … `HEX3 = ~DispReg[27:21]`（共阳，段低有效）。

---

## 五、内存映射 I/O

| 地址 | 方向 | 位宽 | 功能 |
|---|---|---|---|
| `0x7FF0` | 输出 | 28 bit | 显示寄存器（`IOWriteData[27:0]` 直接给 7 段） |
| `0x7FF4` | 输入 | 2 bit | 速度挡开关 `SW[1:0]`（`IOAddr` 低 4 位 = `4`） |

顶层读开关的多路器：

```verilog
assign IOReadData = (IOAddr == 4'h4) ? {30'b0, SW[1:0]} : 32'h0;
```

> **时钟**：`clockdiv` 里 `clk_en = &clk_count`（2 位计数器）→ 50 MHz ÷ 4 = 12.5 MHz。
> 官方注释写「10 MHz」是笔误。蛇的移动速度也受这个分频影响。

> **程序计数器初值 `0x2FFC`**：compact 布局 text 在 `0x3000`，复位后首拍取到 nop，
> 无害。保持官方不变。

---

## 六、蛇程序（part 1）

[snake_patterns.asm](snake_patterns.asm) 的核心循环：

```
lw   $t3, loopcnt        # 延迟上限 = 0x001e8484 (200 万, 让蛇慢下来)
addi $t5, $0, 48         # 12 个字 = 48 字节
restart: addi $t4, $0, 0
forward: beq  $t5,$t4,restart    # 爬完一轮 -> 重头
         lw   $t0, 0($t4)        # 取 pattern[i]
         sw   $t0, 0x7ff0($0)    # 刷新显示
         addi $t4, $t4, 4
wait:    (空转 200 万次后回 forward)
```

12 张图案 `pattern[]` 每张只有 1 位为 1（`0x00200000 … 0x04000000`），按序写进
显示寄存器，就有一个亮点在 4 位数码管上逐格爬行。

---

## 七、Part 2：开关调速

[snake_patterns_speed.asm](snake_patterns_speed.asm) 在 part 1 前面加了 3 条指令
读开关 + 查表选延迟值：

```
lw  $t3, 0x7ff4($0)   # $t3 = SW[1:0] (0..3)
add $t0, $t3, $t3     # } 两次 add 代替 sll:
add $t0, $t0, $t0     # } $t0 = 4*S (字节偏移, 本 Lab ALU 没有 sll)
lw  $t3, 0x30($t0)    # 查 delay_table[S]
… 后面与 part 1 相同
```

`delay_table` 紧跟 12 张图案之后（offset `0x30~0x3C`），四挡延迟值随开关变大而变小：

| SW | 延迟值 | 速度 |
|---|---|---|
| 00 | `0x001e8484` | 最慢（≈200 万次） |
| 01 | `0x000f4240` | |
| 10 | `0x0007a120` | |
| 11 | `0x0003d090` | 最快（≈25 万次） |

### asm.py —— 无 Java 时的 MARS 替代

本机没装 Java，跑不了官方 MARS 导 dump，所以写了 [asm.py](asm.py)（~150 行迷你
汇编器），覆盖蛇程序用到的 `add/addi/sub/slt/lw/sw/beq/j` + `.word` + 标签。

```bash
# 自检: 汇编 snake_patterns.asm 与官方 insmem_h.txt/datamem_h.txt 逐字比对 (PASS)
python asm.py --check

# 汇编 Part 2 -> 生成两份 dump
python asm.py snake_patterns_speed.asm insmem_h_speed.txt datamem_h_speed.txt
```

要把 Part 2 上板，把这对 dump 拷成 `insmem_h.txt`/`datamem_h.txt` 再综合即可
（`$readmemh` 按相对路径读工程目录下同名文件）。

---

## 八、验证（Questa，三遍全 PASS）

```bash
cd lab8 && bash run.sh
```

| testbench | 注入程序 | 断言 |
|---|---|---|
| `tb_lab8` | 13 条手编微程序 | 4 次 IO 写 `8 → 2 → 1 → 0xABCD1234`，一次盖遍 R 型 ALU、寄存器堆、lw/sw、**MMIO 写 + 读** |
| `tb_lab8_snake` | 官方蛇 dump | 复位 + 分频 + 顶层映射正确，首帧 `0x00200000` → 只亮 HEX3 段 0 |
| `tb_lab8_sw` | 开关回读程序 | `SW=2` → 显示寄存器 = 2 → HEX0 只亮段 b，验证 Part2 开关输入链路 |

三个都是一次 `Errors: 0, Warnings: 0`，打印 `PASS`。（Windows 控制台把中文 `$display`
显示成 `?` 是 GBK/UTF-8 编码差异，属正常现象，不影响判断。）

综合/上板仍由你在本机 Quartus 做最后确认（本会话无板、综合慢，只交付工程）。

---

## 九、Quartus 综合 & 上板

1. Quartus → 打开 `lab8_top.qpf`（器件已设 `5CSEMA5F31C6`，顶层 `top`）。
2. 若要跑 Part 1，确认 `lab8/` 下是 `insmem_h.txt`/`datamem_h.txt`；
   要跑 Part 2 调速，先 `python asm.py snake_patterns_speed.asm insmem_h.txt datamem_h.txt` 覆盖。
3. Start Compilation → Programmer 下载（`.sof`）。
4. 上板：`KEY[0]` 复位，`SW[1:0]` 调速度（Part 2），HEX0~HEX3 看蛇爬行。
# ETH Zurich DDCA 自学课程清单（DE1-SoC + Quartus Prime 版）

> 课程：**Digital Design and Computer Architecture (DDCA)**
> 课程号：`227-0003-00L`（旧号 `252-0028-00L` / 课程站路径 `digitaltechnik`）
> 主讲：Onur Mutlu（近年为 O. Mutlu / S. Sadrosadati，早年含 Frank K. Gürkaynak）
> 官方站：<https://safari.ethz.ch/ddca/>　视频：<https://video.ethz.ch/lectures/d-itet/2025/spring/227-0003-10L>
> 教材：Harris & Harris, *Digital Design and Computer Architecture*（RISC-V Edition 为主，实验仍按 MIPS Edition）
> 考核（原课）：180 分钟笔试（可带 **6 页手写笔记**）占 70 分 + 作业/实验占 30 分
> 工作量参考：约 9 个 Lab + 26~29 讲，社区估计 **100 小时**左右

---

## ⚠️ 0. 开工前必须知道的一件事

**ETH 官方实验用的是 Vivado + Digilent Basys 3，不是 Quartus + DE1-SoC。**

| 项目 | ETH 原课 | 你的环境 | 影响 |
|---|---|---|---|
| FPGA | Xilinx Artix-7 `XC7A35T` | Intel Cyclone V `5CSEMA5F31C6` | 引脚/约束全换 |
| 工具 | Vivado | Quartus Prime 25.1std Lite ✅ | 已装好 |
| 仿真 | Vivado Simulator | Questa Altera FPGA Starter ✅ | 已在 qsf 中配置 |
| 主时钟 | 100 MHz | **50 MHz** (`CLOCK_50`) | 所有分频系数要减半 |
| 数码管 | 4 位，**需扫描复用** | 6 位 `HEX5..HEX0`，**各段独立无需扫描** | 直接并行驱动 |
| VGA | 4bit/色 电阻网络 | ADV7123，**8bit/色** + 需外部 `VGA_CLK` | 需 PLL 出 25.175 MHz |
| 按键 | 5 个 | `KEY[3:0]` 4 个 | 贪吃蛇 4 方向刚好够 |
| 开关/LED | 16 开关 / 16 LED | 10 开关 `SW[9:0]` / 10 LED `LEDR[9:0]` | 超 10 位需拆分或改用数码管 |
| 外部 RAM | 无 | 板载 SDRAM | **建议不用**，跟原课一样只用片上 BRAM |

> 结论：**原理、Verilog 代码、测试思路可以完全照搬；只有"顶层的引脚/时钟/显示"这层要自己改。** 
> 这也正好是这门课最值钱的部分之一 —— 移植本身就是一次完整的板级设计练习。

---

## 1. 开发环境清单（你已完成大部分）

- [x] Quartus Prime 25.1std **Lite** Edition（Lite 版支持 Cyclone V，Pro 版**不支持**，别装错）
- [x] 器件设定 `FAMILY "Cyclone V"` / `DEVICE 5CSEMA5F31C6`
- [x] 下载链路打通（USB-Blaster II，JTAG 下载 `.sof`）
- [x] EDA 仿真工具指向 `Questa Altera FPGA (Verilog)`
- [x] 最小工程跑通：`de1_soc/led.v`，KEY3 → LEDR0
- [ ] **建一份自己的全量引脚约束文件** `de1soc_pins.qsf`
      → 从 Terasic DE1-SoC System CD 的 golden top 工程导出，或用 **Assignments → Import Assignments** 逐块导入
      → 至少覆盖：`CLOCK_50`、`SW[9:0]`、`KEY[3:0]`、`LEDR[9:0]`、`HEX0[6:0]`~`HEX5[6:0]`、`VGA_*`
- [ ] 写一个 `de1soc_top.sv` 模板工程（含时钟分频 + 复位同步 + 去抖），后面每个 Lab 从它开分支
- [ ] 备好仿真退路：`iverilog` / `Verilator` + GTKWave（纯 RTL 仿真不需要厂商库，比 Questa 起得快）
- [ ] 汇编环境：**MARS** 或 **RARS**（Lab 7 用）
- [ ] 下载参考：本地 `DE1-SoC_User_manual_revf.pdf`（引脚表在 Appendix）

**踩坑提醒**
- Cyclone V 综合一次约 2~5 分钟，别用 Quartus 做高频迭代 —— **仿真验证 90%，上板只做最终确认**。
- `HEX` 段码**低电平点亮**（共阳），和 Basys 3 一致，但 DE1-SoC 6 位是并行的，写到 `HEX0[6:0]` 即可，不要照抄 Basys 3 的扫描代码。
- VGA 的 `VGA_CLK` 是 FPGA **输出**给 DAC 的，必须自己用 PLL 生成 ~25.175 MHz，否则黑屏。
- 按键 KEY 已由板上 **Schmitt 触发器硬件去抖**（Manual §3.6.1），但进 FPGA 仍需两级同步器防亚稳态；滑动开关 SW **未**去抖、只作电平输入，别拿它做沿触发。

---

## 2. 讲义知识点清单（按模块，配 Harris & Harris 章节）

### 模块 A — 导论与数字抽象
- [ ] 课程定位、从晶体管到体系结构的分层
- [ ] 摩尔定律、抽象层次、设计度量（性能/功耗/面积）
- [ ] 二进制、进制转换、补码、有符号数运算、溢出
- [ ] 📖 Ch.1 *From Zero to One*

### 模块 B — 组合逻辑
- [ ] 布尔代数、公理、化简
- [ ] 组合逻辑门、多级网络、K-map / 逻辑最小化
- [ ] 无关项、毛刺（glitch）、冒险
- [ ] 常用功能块：译码器、多路选择器、编码器、优先编码器
- [ ] 📖 Ch.2 *Combinational Logic Design*

### 模块 C — 时序逻辑
- [ ] 双稳态、SR/D/JK 锁存器与触发器
- [ ] 同步时序机模型、有限状态机（Moore / Mealy）
- [ ] FSM 设计流程：状态图 → 状态编码 → 次态/输出逻辑
- [ ] 时钟偏斜、建立/保持时间、亚稳态、同步器
- [ ] 计数器、移位寄存器
- [ ] 📖 Ch.3 *Sequential Logic Design*

### 模块 D — 硬件描述语言与 Timing/Verification
- [ ] Verilog 结构级 / 行为级建模、`always` 块、阻塞 vs 非阻塞
- [ ] 组合逻辑与时序逻辑的 HDL 写法陷阱（latch 推断）
- [ ] testbench 编写、仿真波形调试
- [ ] 静态时序分析（STA）、时序约束、最高频率
- [ ] FPGA 架构、综合/布局布线/配置流程
- [ ] 📖 Ch.4 *Hardware Description Languages* + Ch.5 *Digital Building Blocks*

### 模块 E — ISA 与汇编
- [ ] 指令集体系结构概念、RISC vs CISC、寻址模式
- [ ] **MIPS**（Lab 用）指令格式：R/I/J 型、`lw/sw/beq/addi/jal`
- [ ] 汇编编程：分支、循环、数组、函数调用、栈帧
- [ ] 机器码编码、伪指令、编译器与汇编器角色
- [ ] 📖 Ch.6 *Architecture*

### 模块 F — 微架构（课程核心）
- [ ] 数据通路与控制器、寄存器堆、ALU
- [ ] **单周期**处理器：`lw` → 加指令 → 控制单元
- [ ] 性能分析：CPI × 周期时间 × 指令数
- [ ] **多周期**处理器、有限状态机控制器、微代码
- [ ] **流水线**：五级流水、流水寄存器
- [ ] 数据冒险（旁路/前递、停顿、气泡）
- [ ] 控制冒险（分支预测、延迟槽）
- [ ] 精确异常、异常与中断处理
- [ ] 📖 Ch.7 *Microarchitecture*

### 模块 G — 进阶微架构（偏概念，笔试常考）
- [ ] 动态调度、记分牌 / Tomasulo、乱序执行（OoO）
- [ ] 数据流执行、超标量、VLIW
- [ ] SIMD、GPU、脉动阵列、多线程
- [ ] 分支预测进阶、预取

### 模块 H — 存储系统
- [ ] 存储技术、存储层次、局部性原理
- [ ] Cache 基础：直接映射/组相联/全相联、替换策略、写策略
- [ ] Cache 性能分析：AMAT、缺失率/缺失代价
- [ ] 高级 Cache：多级、NUCA、非阻塞、预取
- [ ] **虚拟内存**：页表、TLB、地址翻译、页错误、MMU
- [ ] 📖 Ch.8 *Memory Systems*

### 模块 I — 前沿专题（论文导读，按当期 schedule 挑）
- [ ] Memory-centric computing / PIM
- [ ] 基因组分析加速、硬件安全、Rethinking Virtual Memory
- [ ] 当期 `S1~S7` seminar 论文（自学可略读）

---

## 3. 九个 Lab 清单（含 DE1-SoC 移植要点）

> 官方说明：**共 9 个 Lab，Lab 8 跨两次课**（8.1 / 8.2）。每个 Lab 需演示 + 提交 report。

- [ ] **Lab 1 — Drawing a Basic Circuit**
  比较两个电信号（`<`、`>`、`==`），**纸面设计，不上板**
  → 移植：无。重点是把 K-map 和门级设计做扎实。

- [ ] **Lab 2 — Mapping Your Circuit to FPGA**
  1 位全加器 → 复用成 4 位加法器，开关输入、LED 输出
  → 移植：`SW[3:0]`/`SW[7:4]` 作两个操作数，`LEDR[3:0]` 出和、`LEDR[4]` 出进位。**10 个开关够 4 位加法**；若 Lab 要 8 位操作数则改用数码管或分两次。

- [ ] **Lab 3 — Verilog for Combinatorial Circuits**
  把 Lab 2 的结果显示到七段数码管
  → 移植：DE1-SoC 是 `HEX0[6:0]`~`HEX5[6:0]` **六位独立、并行驱动、低电平点亮**。
  ⚠️ **不要照抄 Basys 3 的位扫描代码**，DE1-SoC 无需扫描。6 位数码管可以一次显示更多中间值，是本地实验的加分项。

- [ ] **Lab 4 — Finite State Machines**
  用 FSM 实现汽车转向灯式 LED 闪烁，实现并使用存储器，可调速
  → 移植：主时钟 **50 MHz 不是 100 MHz**，分频系数减半；只有 10 个 LEDR，跑马灯用 `LEDR[9:0]`。

- [ ] **Lab 5 — Implementing an ALU**
  实现完整 ALU：add / sub / mul / compare / and / or / shift
  → 移植：纯组合逻辑，**零改动**，直接复用。

- [ ] **Lab 6 — Testing the ALU**
  写 testbench 仿真验证 Lab 5，学调试方法
  → 移植：用 Quartus 自带 **Questa Altera FPGA Starter Edition**；也可用 iverilog/Verilator + GTKWave 加速。**这个 Lab 是纯 RTL 仿真，用开源工具完全够**，建议就用开源的，迭代快。
  → 建议把 Lab 5 的 ALU 做成参数化模块 + 自检测 testbench，Lab 8 直接复用。

- [ ] **Lab 7 — Writing Assembly Code**
  写 MIPS 汇编程序（图像处理），后续在自研处理器上运行
  → 移植：用 **MARS** 或 **RARS** 模拟器，与板卡无关。
  ⚠️ **ISA 选择建议**：跟着原课走 **MIPS**，因为 Lab 8/8.2 提供的 datapath 骨架、snake 程序和测试向量都是 MIPS 的。若教材读 RISC-V 版，Lab 8 需自己把 datapath 改成 RISC-V —— 那是额外一大块工作量，第一遍自学不划算。

- [ ] **Lab 8.1 / 8.2 — Full System Integration（跨两周，重头戏）**
  搭出第一个完整处理器，运行 "snake" 游戏（VGA 显示 + 按键控制）
  → 移植：**工作量最大的一个 Lab**
  - **VGA**：DE1-SoC 走 ADV7123，`VGA_R[7:0]/VGA_G[7:0]/VGA_B[7:0]` + `VGA_HS`/`VGA_VS`/`VGA_BLANK_N`/`VGA_SYNC_N`；需 PLL 出 25.175 MHz 给 `VGA_CLK`；把原设计 4bit/色 的高 4 位接到 8 位的高 4 位即可。
  - **显存**：**坚持用片上 BRAM**，不要引入 SDRAM 控制器 —— 那会把一个 Lab 变成三个。
  - **方向键**：`KEY[3:0]` 刚好 4 个方向，需自行加去抖 + 两级同步。
  - **时钟**：50 MHz，行/列计数器参数全部重算。
  - 建议先只做一个"VGA 彩条 + 方块随按键移动"的最小 demo 验证整条链路，再接入 CPU。

- [ ] **Lab 9 — The Performance of MIPS**
  在 Lab 8 处理器上增加指令（乘法、移位等）提升性能，分析 CPI/周期数
  → 移植：性能计数器显示到 `HEX0`~`HEX5`（6 位比原课 4 位还宽裕），改动很小。

### 额外建议加的 Lab 0（原课没有，但你需要）
- [ ] **Lab 0 — DE1-SoC 板级打通**：50 MHz 分频闪灯 + 数码管循环计数 + 按键去抖 + 一次 VGA 彩条
      → 把引脚、时钟、PLL、下载流程一次踩完，后面 9 个 Lab 都受益。**不要跳过这个。**

---

## 4. 建议 14 周进度表

| 周 | 讲义模块 | Lab | 里程碑 |
|---|---|---|---|
| W0 | 环境 | **Lab 0** | DE1-SoC 全外设打通 + 引脚文件成型 |
| W1 | B 组合逻辑 | Lab 1 | 手推 K-map，能画出门级实现 |
| W2 | B/D | Lab 2 | 加法器上板，LED 验证正确 |
| W3 | C 时序逻辑 | Lab 4 | FSM 跑马灯 + 分频器 |
| W4 | D HDL/Verilog | Lab 3 | 数码管显示（并行驱动版） |
| W5 | D 仿真与验证 | Lab 6 | testbench 熟练，Questa/iverilog 顺手 |
| W6 | E ISA + 汇编 | Lab 5 | ALU 完成并自检通过 |
| W7 | E 汇编 | Lab 7 | 汇编程序在 MARS 跑通 |
| W8 | F 单周期微架构 | — | 手画单周期数据通路 + 控制表 |
| W9–10 | F 单周期/多周期 | **Lab 8.1** | 最小 CPU 上板跑通 |
| W11 | F 流水线 | **Lab 8.2** | snake 游戏可玩 |
| W12 | F 冒险与异常 | Lab 9 | 加指令后性能提升可量化 |
| W13 | G/H 进阶微架构 + 存储 | — | 缓存/虚存概念闭环 |
| W14 | 复习 | — | 刷历年真题（课程站有存档） |

**节奏建议**：每周 8~10 小时。听讲 + 看教材占 4 小时，Lab 占 4~6 小时。**Lab 不要攒到最后**，它是这门课真正的理解来源。

---

## 5. 资源链接

- 课程主页（含课件/习题/实验/历年考题）：<https://safari.ethz.ch/ddca/>
- 实验页面（以你选的学期为准，lab 清单每学期略调）：<https://safari.ethz.ch/ddca/spring2025/doku.php?id=labs>
- 官方录播：<https://video.ethz.ch/lectures/d-itet/2025/spring/227-0003-10L>
- 中文自学攻略：<https://csdiy.wiki/体系结构/DDCA/>
- 教材：Harris & Harris, *Digital Design and Computer Architecture*（RISC-V Ed. 学指令集 / MIPS Ed. 配实验）
- 本地：`DE1-SoC_User_manual_revf.pdf`（引脚表、外设时序、VGA/SDRAM/GPIO 说明）
- Terasic DE1-SoC System CD（golden top 工程、默认引脚分配来源）
- MARS / RARS —— MIPS/RISC-V 汇编模拟器

---

## 6. 一句话心法

> 讲义和 Verilog 代码可以 100% 照搬，**只有"顶层引脚 + 时钟 + 显示"这三层需要你为 DE1-SoC 重写**。
> 把这层写成一个可复用的 `de1soc_top.sv`，9 个 Lab 就都能跑同一套骨架。

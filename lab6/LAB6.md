# Lab 6 — Testing the ALU（写 testbench 全面验证 ALU）

> 对应 ETH DDCA Lab 6。**纯 RTL 仿真，不上板**。官方给的是一个**留了 4 个 `TO DO`
> 的测试台骨架**（`ALU_test.v`）+ 一份 **故意写错的 ALU**（`bad_ALU.v`），
> 目的是训练"用 testbench 把 bug 逼出来"这个技能。
> 本仓库在官方骨架之外，另加了一套自写穷举 tb，两者都跑同一个 `alu` 模块。

---

## 1. 交付文件

| 文件 | 作用 |
|---|---|
| [`ALU_test.v`](ALU_test.v) | **官方骨架的填完版**（4 个 TO DO 已补），读文件驱动的测试台 |
| [`testvectors_hex.txt`](testvectors_hex.txt) | 102 条测试向量（官方原版只有 12 条且 Result 列全空，已补齐并扩到 ≥100） |
| [`testvectors_hex_official.txt`](testvectors_hex_official.txt) | ETH 官方原件，**原样保留**做对照 |
| [`bad_ALU.v`](bad_ALU.v) | ETH 官方**故意写错**的 ALU，调试练习用 |
| [`tb_lab6.sv`](tb_lab6.sv) | 自写穷举 testbench（8-bit 穷举 + 32-bit 定向） |
| [`alu.sv`](alu.sv) | 被测单元（Lab 5 的同一份 ALU） |
| [`run.sh`](run.sh) | Questa 一键脚本（三遍：穷举 / 官方骨架 / bad_ALU 调试） |

---

## 2. 两套 testbench 的分工

| | `tb_lab6.sv`（自写） | `ALU_test.v`（官方骨架） |
|---|---|---|
| 激励来源 | 代码里生成 | **文件驱动** `testvectors_hex.txt` |
| 覆盖 | 8-bit **全空间穷举** + 32-bit 定向 | 102 条**挑过的**向量 |
| 检查 | `result/zero/neg/carry/overflow` 五个全查 | 只查 `result` / `zero`（官方定义） |
| 规模 | **786465** 项 | 102 项 |
| 学到什么 | 怎么把一个组合电路测干净 | 怎么用文件驱动 + 怎么读调试输出 |

> 两者互补：穷举负责"值域内全覆盖"，定向向量负责"位位置/边界"，文件驱动那套
> 则是原课要求的交付形式。

---

## 3. 官方骨架的 4 个 TO DO 是怎么填的

`ALU_test.v` 骨架里原本留了 4 处 `TO DO`，逐条对应：

**[TO DO 1] 定义 `testvec` 数组**
```verilog
reg [99:0] testvec [0:199];
```
宽度由第 81 行的 `{aluop,a,b,exp_result} = testvec[vec_cnt];` 倒推：
`4 + 32 + 32 + 32 = 100` bit。这个 100 也正好是第 99 行 `testvec[..][99:96] === 4'bxxxx`
判"向量用完"时取的高 4 位（就是 `aluop` 那 4 位）。

**[TO DO 2] 读文件**
```verilog
$readmemh("testvectors_hex.txt", testvec);
```
文件每行 25 个 hex 数字（`AluOp` 1 位 + A/B/Result 各 8 位）= 100 bit。
**没被填到的表项保持 `X`** —— 这正是"向量用完"的判定机制，不用自己数条数。

**[TO DO 3] 算 `exp_zero`**
```verilog
assign exp_zero = (exp_result == 32'b0);
```
组合逻辑，结果全 0 时 `Zero` 为 1（官方 Table 1 的定义）。

**[TO DO 4] 实例化 UUT**
```verilog
alu #(.W(32)) uut (.a(a), .b(b), .op(aluop), .result(result), .zero(zero), ...);
```
注意 tb 里的信号叫 `aluop`（官方命名），本仓库 ALU 的端口叫 `op`，实例化时对接即可。
`neg/carry/overflow` 官方不检查，接成哑线只为消掉 vopt 的 "Missing connection" 警告。

### 关于 `testvectors_hex.txt`

官方原件只有 **12 条**，且**除第一行外 Result 列全是空的**——那是留给你填的模板，
而 TO DO 又要求"至少 100 条"。本仓库的版本：

- 扩到 **102 条**，12 种操作每种都有多条
- 每条 Result 都由**独立的生成脚本**算好（不是抄 RTL 逻辑）
- 覆盖边界：进位、正/负溢出、`slt` 的符号比较、移位量 0/31/32、`SRA` 符号扩展等
- 格式与官方原文件**逐字符一致**（同样 47 列、同样的 `_` 分隔），可直接 `diff` 对照

---

## 4. 使用方法

```bash
cd lab6
bash run.sh            # 一条命令跑完三遍
```

`run.sh` 内部三遍：

```bash
# 1) 穷举 + 定向
vlib work && vlog -sv alu.sv tb_lab6.sv
vsim -c -do "run -all; quit -f" work.tb_lab6

# 2) 官方骨架测试台
vlib work && vlog -sv alu.sv ALU_test.v
vsim -c -do "run -all; quit -f" work.ALU_test

# 3) 调试练习: 把同一套向量喂给官方带 bug 的 ALU
vlib work && vlog -sv bad_ALU.v +define+USE_BAD_ALU ALU_test.v
vsim -c -do "run -all; quit -f" work.ALU_test      # 故意 FAIL
```

**实测输出（1、2 必须全绿）：**

```
# PASS: ALU 全部 786465 项检查通过
#       - 8-bit 穷举: 65536 操作数 x 12 操作 (每项校 result/zero/neg/carry/overflow)
#       - 操作码: 官方 7 种 (ETH Table 1 编码) + 扩展 5 种
#       - 32-bit 定向: W=32 的进位/溢出位位置、符号扩展、大数乘法取低位

#  102 tests completed with    0 errors
```

> 均实测 `Errors: 0, Warnings: 0`。

---

## 5. 调试方法（Lab 6 真正要教你的）

`run.sh` 的第 3 遍会故意失败——**那就是这个 Lab 的正文**。原课给的 `bad_ALU.v`
埋了 bug，用同一套 102 条向量跑它，输出长这样：

```
# Error at  1480 ns: Aluop 0001 a = 00000001 b = 01234567
# Error at  9080 ns: Aluop 1010 a = 80000000 b = ffffffff
#        ffffffff (00000001 expected)
```

读失败的固定姿势：

1. **先看 `Aluop` 列，定位是"整片 op 错"还是"个别向量错"**
   - 某个 opcode **所有**向量都错 → 该 op 的译码/映射错了。
     （例如 `bad_ALU` 的 `1010` 全错，因为它内部把 `slt` 的结果挂在 `4'b1011` 上，
     而官方 Table 1 规定 `slt` 是 `1010` —— 这就是它埋的 bug。）
   - 只有**个别输入**错 → 边界问题（溢出、移位量 0/最大、正负号）。
2. **看 `Zero` 行**：`result` 对了但 `zero` 错 → 错误被压缩到"零标志生成"这一小块。
3. **缩小复现**：从失败向量里抽一条塞进波形，或临时 `$display` 中间量
   （`add_ext`）确认进位是不是算到了错误的 bit 位置。

自写 tb 那边同理，只是检查更细（五个信号全查、错误信息带 `c/v` 期望值）：

1. `got` 恒等于某个常数（尤其全 0）→ 大概率是**输入没驱动/驱动错了**，不是运算错。
2. `got` 与 `exp` 只在**某几种 op** 上差 → 那几种 op 的映射或符号处理错了。
3. 只在**个别输入**上差 → 边界值问题。

---

## 6. 自检 checklist

- [ ] 能解释为什么 8-bit 穷举 + 32-bit 定向两层缺一不可
- [ ] 知道 golden reference 为什么必须和 RTL **独立**重写一遍
- [ ] 知道"失败才拼消息 + 限量打印"对 78 万次穷举的性能意义
- [ ] 能说出 `testvec` 为什么是 **100 bit** 宽，以及"向量用完"是靠什么判定的
- [ ] 亲手把 `0x80000000 >>> 1` 手算一遍（= `0xC0000000`），理解符号扩展
- [ ] **能自己从 `bad_ALU` 的失败输出里指出 bug 在第几行**（答案：它的 `case`
      用 `4'b1011` 选 slt，官方是 `4'b1010`）
- [ ] 想通了：这套 ALU 的 `zero/neg/carry/overflow` 就是 Lab 8 处理器里
      `beq/bne` 和跳转指令要用的那些条件——Lab 6 把它们验到 0 错，Lab 8 才敢在上面搭 CPU

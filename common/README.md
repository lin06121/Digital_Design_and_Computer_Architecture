# common —— DE1-SoC 复用底座

两个文件,每个 Lab 都从这里出发:

| 文件 | 作用 | 要不要改 |
|---|---|---|
| `de1soc_pins.qsf` | 全量引脚约束(已按手册核对) | 不改,导入即可 |
| `de1soc_top.sv` | 顶层骨架 + Lab 0 演示 | 只改 `USER DEMO` 区域 |

`de1soc_top.sv` 里 `[KEEP]` 标注的基础模块(复位同步 / 两级同步 / 消抖 / 分频 / 七段译码 / VGA 时序)后续所有 Lab 共用,不要动。

---

## 新 Lab 三步走(每个 Lab 重复)

### 1. 建工程
Quartus → `File → New Project Wizard`:

- 目录 `labN/`,工程名 `labN`
- **Top-level entity 名字** = 你要实例化的模块名(复用底座就填 `de1soc_top`)
- 器件:`Family = Cyclone V`,`Device = 5CSEMA5F31C6`
- 添加文件:`de1soc_top.sv`(用到的 `.sv` 全勾上,Quartus 会自动识别被包含的库模块 `reset_sync` 等)

### 2. 导入引脚
`Assignments → Import Assignments` → 勾选 **Pin/Location** → 选 `common/de1soc_pins.qsf` → OK。

> 备选:把 `de1soc_pins.qsf` 内容整体追加到工程 `.qsf` 末尾(注意别和已有的 `set_location_assignment` 重复,新的会覆盖旧的)。

### 3. 编译 + 下载
`Processing → Start Compilation`(Cyclone V 全编译约 2~5 分钟)→ `Tools → Programmer` → 选 `output_files/*.sof` → Start。

---

## 开分支的两种姿势

### 姿势 A —— Git 分支(推荐)
当前目录还不是 git 仓库,先初始化:

```bash
git init
git add .
git commit -m "common base: pins + de1soc_top skeleton (Lab 0)"
git branch lab0    # 留一个干净的 Lab0 基线
git switch -c labN # 每个新 Lab 开一条分支
# 改 de1soc_top.sv 的 USER DEMO 区域 -> 编译下载
```

好处:每个 Lab 一个分支,随时 `git diff lab0` 看自己改了什么、`git switch` 回到任意 Lab。也符合你原来「从它开分支」的字面意图。

### 姿势 B —— 复制改名(不用 git)
```bash
cp common/de1soc_top.sv labN/labN_top.sv
```
然后:
1. 把文件里的 `module de1soc_top` 改成 `module labN_top`
2. 建工程时 Top-level entity 填 `labN_top`
3. 端口名不能改(必须还是 `SW/KEY/LEDR/HEX0..5/VGA_*`),否则引脚约束对不上

> 提示:绑定引脚靠的是**顶层端口名**,和模块名无关。所以无论哪种姿势,端口名都保持 `de1soc_top.sv` 里的那一份。

---

## Lab 0 —— 应该怎么做(就是验证这个底座)

Lab 0 的代码**已经写在** `de1soc_top.sv` 的 `USER DEMO` 区域,所以 Lab 0 = 建好工程、编译、下载、逐项验证,目标是把「引脚/时钟/分频/复位/消抖/VGA 下载链路」一次性踩通,后面 9 个 Lab 都不再碰这些坑。

### 验证清单(下载后按顺序查)

| # | 现象 | 验证了什么 |
|---|---|---|
| 1 | `LEDR` 一个灯左右来回跑(约 2Hz) | LED 引脚、分频、时序逻辑 |
| 2 | `SW[9]` 拨到上 → 10 个 LED 直通显示开关状态 | SW 引脚 + 两级同步 |
| 3 | `HEX5..HEX0` 六位十六进制不停自增(低位肉眼可见流动) | 七段译码 + 共阳低有效的理解 |
| 4 | 按 `KEY[1]` → 数码管清零为 0 | 按键同步 + 消抖 + 沿检测 |
| 5 | 按 `KEY[0]` → 整体复位(数码管归零、跑马灯回最右、VGA 重来) | 复位同步器 |
| 6 | 接 VGA 显示器 → 8 条竖色带(红橙黄绿青蓝紫白)稳定不滚动 | VGA 时序 + 25MHz 分频 + DAC 引脚 |

### 4 个最可能踩的坑

1. **引脚对不上**:忘记 Import Assignments,或端口名和 qsf 不一致 → `Processing → Start Fitter` 会报 `no location assigned` / 大量 `Error (171000)`。回去做第 2 步。
2. **HEX 显示乱码**:图省事把段码写反(共阳要把点亮写成 0)。`sevenseg` 模块脚本里给的是**共阳低有效**的段码,直接用。
3. **VGA 黑屏/花屏**:先确认 `VGA_CLK` 真有 25MHz 信号(用示波器),再查 `VGA_BLANK_N` 没焊反——消隐区应为低。25MHz 与标准 25.175 差 0.7%,绝大多数显示器能锁;极少数老显示器会偏,Lab 8 换 PLL 解决。
4. **按键当复位没反应**:`KEY[0]` 是低有效(按下=0),`reset_sync` 已按「异步低有效」处理,不需要再取反。

### Lab 0 之后的动作

- `git commit` 一下,这就是所有后续 Lab 的基线。
- 确认 `de1soc_top.sv` 里 `[KEEP]` 的模块你都能一句话讲清作用,这是课程前几周(组合/时序/HDL)的检验点。

---

## 消抖是否正确?一处更正

手册 **§3.6.1** 明确:DEl-SoC 的 4 个按键出厂已接 **Schmitt 触发器硬件消抖**,「可以直接用作电路的 clock 或 reset 输入」。所以:

- `KEY` → 硬件已消抖,进 FPGA **只需两级同步器防亚稳态**(`sync2`),再消抖是锦上添花(模板里 `debounce` 仍演示了一遍这个模式,可留可删)。
- `SW`(滑动开关)→ **没有**硬件消抖,但它是电平输入,通常只做静态配置;若拿它做边沿/计数用途,记得自己接 `debounce`。
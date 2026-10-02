//============================================================================
//  alu.sv  ——  Lab 5 算术逻辑单元 (纯组合, 无时钟)
//============================================================================
//  位宽 W 可参数化, 默认 32 (与 ETH 官方 Lab 5/8 的 MIPS ALU 一致);
//  Lab 5 上板演示用 W=8 (开关只有 4 位宽的操作数)。
//
//  操作码 op[3:0] —— 前 7 种是 ETH DDCA Lab 5 Table 1 的官方定义,
//  编码严格照官方, 因此官方 lab6_files/ALU_test.v 可直接对本模块运行:
//
//    官方 7 种 (Table 1, 编码不可改):
//      ADD  (4'b0000)  result = a + b                加法
//      SUB  (4'b0010)  result = a - b                减法
//      AND  (4'b0100)  result = a & b                按位与
//      OR   (4'b0101)  result = a | b                按位或
//      XOR  (4'b0110)  result = a ^ b                按位异或
//      NOR  (4'b0111)  result = ~(a | b)             按位或非
//      SLT  (4'b1010)  result = signed(a) < signed(b) ? 1 : 0   有符号比较
//
//    扩展 5 种 (占官方未定义的码位, 不影响官方兼容; 自学加练):
//      MUL  (4'b0001)  result = (a * b) 的低 W 位
//      SLTU (4'b0011)  result = unsigned(a) < unsigned(b) ? 1 : 0
//      SLL  (4'b1000)  result = a << b[log2(W)-1:0]   逻辑左移
//      SRL  (4'b1001)  result = a >> b[log2(W)-1:0]   逻辑右移
//      SRA  (4'b1011)  result = signed(a) >>> b[log2(W)-1:0]  算术右移
//
//    其余码位: 官方标注 "Don't Care", 本模块兜底为 result = 0。
//
//  标志位 (官方只要求 zero; 后三个是本模块多做给 Lab 8 用的):
//    zero     (result == 0)                          ← 官方要求, 名字必须叫 zero
//    neg      result[W-1] (符号位 / 最高位)
//    carry    ADD=进位, SUB=借位, 其余恒 0
//    overflow ADD/SUB 的有符号溢出, 其余恒 0
//
//  设计要点:
//    * always_comb 顶部先给 result/carry/overflow 默认值 → 不会推断出锁存器
//    * 移位量只取 b 的低 log2(W) 位, 保证 0 <= 移位量 <= W-1, 不会移出界
//    * 官方 Table 1 的 Note 1: slt 结果要扩展到 32 位 (本模块按 W 扩展)
//    * SLT 是「有符号」比较 —— 官方 Note 未特别说明, 但 MIPS 的 slt 语义
//      就是符号比较 (无符号的是 sltu), 这里按 MIPS 语义实现
//
//  验证: Lab 6 双 testbench
//    - ALU_test.v  官方骨架测试台 (读 testvectors_hex.txt, 100+ 条向量)
//    - tb_lab6.sv  8-bit 穷举 (256x256 x 12 op) + 32-bit 定向边界向量
//============================================================================
`default_nettype none

module alu #(parameter W = 32) (
    input  wire [W-1:0]  a, b,
    input  wire [3:0]    op,
    output logic [W-1:0] result,
    output logic         zero, neg, carry, overflow
);

    // ------------------------------------------------------------------
    //  官方 7 种 —— 编码严格照 ETH DDCA Lab 5 Table 1, 不可改动
    // ------------------------------------------------------------------
    localparam ADD  = 4'b0000;
    localparam SUB  = 4'b0010;
    localparam AND  = 4'b0100;
    localparam OR   = 4'b0101;
    localparam XOR  = 4'b0110;
    localparam NOR  = 4'b0111;
    localparam SLT  = 4'b1010;

    // ------------------------------------------------------------------
    //  扩展 5 种 —— 占官方未定义的码位, 想删就删, 删了官方兼容性不变
    // ------------------------------------------------------------------
    localparam MUL  = 4'b0001;
    localparam SLTU = 4'b0011;
    localparam SLL  = 4'b1000;
    localparam SRL  = 4'b1001;
    localparam SRA  = 4'b1011;

    // 移位量: 只取 b 的低 log2(W) 位 (0 .. W-1)
    localparam SHAMT_W = $clog2(W);
    wire [SHAMT_W-1:0] shamt = b[SHAMT_W-1:0];

    // 算术/逻辑的中间量 (连续赋值, 纯组合)
    wire [W-1:0]   add_r   = a + b;
    wire [W:0]     add_ext = {1'b0, a} + {1'b0, b};   // 第 W 位 = 进位
    wire [W-1:0]   sub_r   = a - b;
    wire [W:0]     sub_ext = {1'b0, a} - {1'b0, b};   // 第 W 位 = 借位
    wire [2*W-1:0] mul_r   = a * b;
    wire [W-1:0]   sll_r   = a << shamt;
    wire [W-1:0]   srl_r   = a >> shamt;
    wire [W-1:0]   sra_r   = $signed(a) >>> shamt;

    always_comb begin
        result   = '0;                                 // 默认值, 防锁存
        carry    = 1'b0;
        overflow = 1'b0;
        case (op)
            // ---- 官方 7 种 ----
            ADD:  begin
                result   = add_r;
                carry    = add_ext[W];
                overflow = (a[W-1] == b[W-1]) && (add_r[W-1] != a[W-1]);
            end
            SUB:  begin
                result   = sub_r;
                carry    = sub_ext[W];                 // 减法时为借位
                overflow = (a[W-1] != b[W-1]) && (sub_r[W-1] != a[W-1]);
            end
            AND:  result = a & b;
            OR:   result = a | b;
            XOR:  result = a ^ b;
            NOR:  result = ~(a | b);
            SLT:  result = ($signed(a) < $signed(b)) ? {{(W-1){1'b0}}, 1'b1} : '0;

            // ---- 扩展 5 种 ----
            MUL:  result = mul_r[W-1:0];
            SLTU: result = (a < b)                     ? {{(W-1){1'b0}}, 1'b1} : '0;
            SLL:  result = sll_r;
            SRL:  result = srl_r;
            SRA:  result = sra_r;

            default: result = '0;                      // 官方 "Don't Care": 兜底 0
        endcase
    end

    assign zero = (result == '0);
    assign neg  = result[W-1];

endmodule

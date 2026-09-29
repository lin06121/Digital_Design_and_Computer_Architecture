//====================================================================
// lab2_top.sv —— Lab 2: 把 1 位全加器复用成 4 位行波进位加法器/减法器
//====================================================================
// 目标: 用"画门级电路"的思路实现 1 位全加器, 再用 4 个实例拼成
//       4 位行波进位加法器, 映射到 DE1-SoC 的开关 / LED / 数码管。
//
// 输入映射:
//   A[3:0] = SW[3:0]    第 1 个 4 位操作数
//   B[3:0] = SW[7:4]    第 2 个 4 位操作数
//   SW[8]  = 加法模式的进位输入 Cin
//   SW[9]  = 运算模式: 0 = 加 (A+B+Cin), 1 = 减 (A-B, 用二补数 A + ~B + 1)
// 输出映射:
//   LEDR[3:0] = 和 sum,  LEDR[4] = 进位/借位 cout
//   HEX5=A, HEX4=B, HEX1=Carry, HEX0=Sum   (数码管是额外可读性, Lab 只要求 LED)
//
// 验证: 综合 -> 烧录 -> 拨开关 -> 读 LEDR 与 HEX。
//       (testbench 见 tb_lab2.sv, 用 Questa 或 iverilog -g2012 跑)
//====================================================================
`default_nettype none

module lab2_top (
    input  logic [9:0]  SW,
    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
);

    // ---- 输入映射 ----
    logic [3:0] a, b;
    logic       mode;     // 0 = 加, 1 = 减
    logic       cin;      // 送入最低位全加器的进位输入
    logic [3:0] b_eff;    // 真正送入加法器的 B (减法时取反)
    assign a    = SW[3:0];
    assign b    = SW[7:4];
    assign mode = SW[9];

    // 减法: A - B = A + (~B) + 1, 把 +1 复用成最低位的 carry-in;
    // 加法: cin = SW[8]
    assign b_eff = mode ? ~b : b;
    assign cin   = mode ? 1'b1 : SW[8];

    // ---- 4 位行波进位加法器 ----
    logic [3:0] sum;
    logic       cout;
    ripple_carry_adder #(.W(4)) u_adder (
        .a(a), .b(b_eff), .cin(cin), .sum(sum), .cout(cout)
    );

    // ---- 输出映射 ----
    assign LEDR[3:0] = sum;
    assign LEDR[4]   = cout;
    assign LEDR[9:5] = 5'b0;                 // 用不到的 LED 熄灭

    sevenseg u_a   (.hex(a),            .seg(HEX5)); // A
    sevenseg u_b   (.hex(b),            .seg(HEX4)); // B
    sevenseg u_sum (.hex(sum),          .seg(HEX0)); // Sum
    sevenseg u_co  (.hex({3'b0, cout}), .seg(HEX1)); // Carry (0/1)
    assign HEX2 = 7'b111_1111;                 // 熄灭
    assign HEX3 = 7'b111_1111;                 // 熄灭
endmodule


//====================================================================
// 1 位全加器 —— 门级结构 (这就是 Lab 2 要你"画出来"的电路)
//   sum  = a XOR b XOR cin
//   cout = (a AND b) OR (cin AND (a XOR b))
//====================================================================
module full_adder (
    input  logic a, b, cin,
    output logic sum, cout
);
    // TODO(你来完成): 从真值表推导 sum 和 cout 的最简逻辑。
    //   a b cin | sum  cout
    //   0 0  0  |  0    0
    //   0 0  1  |  1    0
    //   0 1  0  |  1    0
    //   0 1  1  |  0    1
    //   1 0  0  |  1    0
    //   1 0  1  |  0    1
    //   1 1  0  |  0    1
    //   1 1  1  |  1    1
    //   提示1: sum 检测"1 的个数是否为奇数" => 异或链 a^b^cin
    //   提示2: cout 是"至少两个输入为 1"(多数表决)
    //
    //   下面两行留空, 用 assign 写出来 (或改用 xor/and/or 门实例化):
    //   assign sum  = ?;
    //   assign cout = ?;
endmodule


//====================================================================
// N 位行波进位加法器 —— 把 N 个 1 位全加器首尾相连 (carry 链)
//====================================================================
module ripple_carry_adder #(parameter W = 4) (
    input  logic [W-1:0] a, b,
    input  logic         cin,
    output logic [W-1:0] sum,
    output logic         cout
);
    logic [W:0] carry;          // carry[0]=最低位进位(接 cin), carry[W]=最高位溢出(cout)
    assign carry[0] = cin;

    // TODO(你来完成): 复用上面的 full_adder, 实例化 W 个, 把 carry 链和 sum 接起来。
    //   第 i 个实例的连接方式:
    //     .a(a[i])  .b(b[i])  .cin(carry[i])  .sum(sum[i])  .cout(carry[i+1])
    //   用 generate-for 逐位生成。
    genvar i;
    generate
        // for (...) begin : gen_fa
        //     full_adder fa (...);
        // end
    endgenerate

    assign cout = carry[W];
endmodule


//====================================================================
// 共阳七段译码: hex -> seg[6:0]={g,f,e,d,c,b,a}, 段低有效 (与 common 版一致)
//====================================================================
module sevenseg (
    input  logic [3:0] hex,
    output logic [6:0] seg
);
    always_comb
        unique case (hex)
            4'h0: seg = 7'b100_0000;
            4'h1: seg = 7'b111_1001;
            4'h2: seg = 7'b010_0100;
            4'h3: seg = 7'b011_0000;
            4'h4: seg = 7'b001_1001;
            4'h5: seg = 7'b001_0010;
            4'h6: seg = 7'b000_0010;
            4'h7: seg = 7'b111_1000;
            4'h8: seg = 7'b000_0000;
            4'h9: seg = 7'b001_1000;
            4'hA: seg = 7'b000_1000;
            4'hB: seg = 7'b000_0011;
            4'hC: seg = 7'b100_0110;
            4'hD: seg = 7'b010_0001;
            4'hE: seg = 7'b000_0110;
            4'hF: seg = 7'b000_1110;
        endcase
endmodule
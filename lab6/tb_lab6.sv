//============================================================================
//  tb_lab6.sv  ——  Lab 6: 全面验证 Lab 5 的 ALU (纯仿真, 自检测)
//============================================================================
//  验证层次:
//   1) 8-bit 穷举: 256 x 256 = 65536 组操作数 x 全部 12 种操作, 每组比对
//        result / zero / neg / carry / overflow (ADD/SUB 校验 carry+overflow)
//        → 约 78 万组检查, 覆盖所有小数值组合与移位量 0..7。
//   2) 32-bit 定向向量: 期望值手算传入, 专测 W=32 时进位/溢出/符号扩展的
//        位位置 (bit 31/32 而非 7/8)、大数乘法取低位、算术右移符号扩展。
//   3) 未定义操作码: op=0xC..0xF 应落到 default → result=0。
//
//  操作码是 ETH 官方 Lab 5 Table 1 的编码 (前 7 种), 后 5 种是占官方未定义
//  码位的扩展 —— 详见 alu.sv 顶部注释。
//
//  运行 (本目录):
//     bash run.sh
//   或手动:
//     vlib work
//     vlog -sv alu.sv tb_lab6.sv
//     vsim -c -do "run -all; quit -f" work.tb_lab6
//
//  期望输出: PASS: ALU 全部 N 项检查通过 ...
//============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_lab6;

    // ---- 操作码 (与 alu.sv 定义一致) ----
    // 官方 7 种 (编码不可改)
    localparam ADD  = 4'b0000;
    localparam SUB  = 4'b0010;
    localparam AND  = 4'b0100;
    localparam OR   = 4'b0101;
    localparam XOR  = 4'b0110;
    localparam NOR  = 4'b0111;
    localparam SLT  = 4'b1010;
    // 扩展 5 种 (占官方未定义码位)
    localparam MUL  = 4'b0001;
    localparam SLTU = 4'b0011;
    localparam SLL  = 4'b1000;
    localparam SRL  = 4'b1001;
    localparam SRA  = 4'b1011;

    // 操作码总数 (穷举范围 0 .. OP_N-1)
    localparam integer OP_N = 12;

    // ---------------- 8-bit DUT ----------------
    logic [7:0] a8, b8;
    logic [3:0] op8;
    logic [7:0] r8;
    logic       z8, n8, c8, v8;
    alu #(.W(8)) u8 (
        .a(a8), .b(b8), .op(op8), .result(r8),
        .zero(z8), .neg(n8), .carry(c8), .overflow(v8)
    );

    // ---------------- 32-bit DUT ----------------
    logic [31:0] a32, b32;
    logic [3:0]  op32;
    logic [31:0] r32;
    logic        z32, n32, c32, v32;
    alu #(.W(32)) u32 (
        .a(a32), .b(b32), .op(op32), .result(r32),
        .zero(z32), .neg(n32), .carry(c32), .overflow(v32)
    );

    // ---- 计数器与循环变量 (提到模块级, 规避 Questa vlog-13069) ----
    integer     errs  = 0;
    integer     total = 0;
    integer     ai, bi, opi;
    logic [7:0] a_val, b_val;
    logic [3:0] op_val;

    // ---------------- 8-bit 金色参考 (与 alu 语义一致, SV 原生运算符) ----------------
    function automatic [7:0] gold8(input [7:0] a, input [7:0] b, input [3:0] op);
        case (op)
            ADD:  gold8 = a + b;
            SUB:  gold8 = a - b;
            MUL:  gold8 = a * b;                       // 自动截断 = 低 8 位积
            SLT:  gold8 = ($signed(a) < $signed(b)) ? 8'd1 : 8'd0;
            SLTU: gold8 = (a < b)               ? 8'd1 : 8'd0;
            AND:  gold8 = a & b;
            OR:   gold8 = a | b;
            XOR:  gold8 = a ^ b;
            NOR:  gold8 = ~(a | b);
            SLL:  gold8 = a << b[2:0];
            SRL:  gold8 = a >> b[2:0];
            SRA:  gold8 = $signed(a) >>> b[2:0];
            default: gold8 = 8'd0;
        endcase
    endfunction

    // ---------------- 8-bit 单条检查 (失败才拼消息, 穷举跑得快) ----------------
    task automatic check8(input [7:0] a, input [7:0] b, input [3:0] op);
        begin
            logic [7:0] exp;
            logic [8:0] add_ext, sub_ext;
            logic       ec, ev;
            a8 = a; b8 = b; op8 = op;             // 驱动 DUT
            #1;                                   // 组合逻辑稳定
            exp     = gold8(a, b, op);
            add_ext = {1'b0, a} + {1'b0, b};
            sub_ext = {1'b0, a} - {1'b0, b};
            ec = (op == ADD) ? add_ext[8] :
                 (op == SUB) ? sub_ext[8] : 1'b0;
            ev = (op == ADD) ? ((a[7]==b[7]) && (exp[7]!=a[7])) :
                 (op == SUB) ? ((a[7]!=b[7]) && (exp[7]!=a[7])) : 1'b0;

            total = total + 1;
            if ((r8 != exp) || (z8 != (exp == 8'd0)) || (n8 != exp[7]) ||
                (c8 != ec)  || (v8 != ev)) begin
                errs = errs + 1;
                if (errs <= 20)
                    $display("FAIL W8: op=%0h a=%h b=%h | exp=%h got=%h | z=%b n=%b c=%b v=%b (exp c=%b v=%b)",
                             op, a, b, exp, r8, z8, n8, c8, v8, ec, ev);
            end
        end
    endtask

    // ---------------- 32-bit 单条检查 (期望值手算传入) ----------------
    task automatic check32(input [31:0] a, input [31:0] b, input [3:0] op,
                           input [31:0] exp, input bit ec, input bit ev);
        begin
            a32 = a; b32 = b; op32 = op;          // 驱动 DUT
            #1;                                   // 组合逻辑稳定
            total = total + 1;
            if ((r32 != exp) || (z32 != (exp == 32'd0)) || (n32 != exp[31]) ||
                (c32 != ec)  || (v32 != ev)) begin
                errs = errs + 1;
                if (errs <= 20)
                    $display("FAIL W32: op=%0h a=%h b=%h | exp=%h got=%h | c=%b v=%b (exp c=%b v=%b)",
                             op, a, b, exp, r32, c32, v32, ec, ev);
            end
        end
    endtask

    // =================================================================
    //  主测试
    // =================================================================
    initial begin
        a8 = 8'd0; b8 = 8'd0; op8 = 4'd0;
        a32 = 32'd0; b32 = 32'd0; op32 = 4'd0;
        $display("== Lab 6: ALU 全面验证 ==");

        // ---------- 1) 8-bit 穷举 (12 种操作 x 65536 组操作数) ----------
        $display("-- 8-bit 穷举 (op = 0..%0d, 官方 7 种 + 扩展 5 种) --", OP_N - 1);
        for (opi = 0; opi < OP_N; opi = opi + 1) begin
            op_val = opi[3:0];
            for (ai = 0; ai < 256; ai = ai + 1) begin
                a_val = ai[7:0];
                for (bi = 0; bi < 256; bi = bi + 1) begin
                    b_val = bi[7:0];
                    check8(a_val, b_val, op_val);
                end
            end
        end

        // ---------- 2) 未定义操作码兜底 (0xC..0xF, 官方标 "Don't Care") ----------
        $display("-- 未定义 op 兜底 (0xC..0xF -> default -> 0) --");
        check8(8'h55, 8'hAA, 4'hC);
        check8(8'h55, 8'hAA, 4'hD);
        check8(8'h55, 8'hAA, 4'hE);
        check8(8'h55, 8'hAA, 4'hF);

        // ---------- 3) 32-bit 定向向量 ----------
        $display("-- 32-bit 定向向量 --");
        // ADD
        check32(32'h0000_0007, 32'h0000_0003, ADD, 32'h0000_000A, 0, 0); // 7+3
        check32(32'h0000_0000, 32'h0000_0000, ADD, 32'h0000_0000, 0, 0); // 0+0 零标志
        check32(32'hFFFF_FFFF, 32'h0000_0001, ADD, 32'h0000_0000, 1, 0); // -1+1 进位
        check32(32'h7FFF_FFFF, 32'h0000_0001, ADD, 32'h8000_0000, 0, 1); // 正溢出
        check32(32'h8000_0000, 32'h8000_0000, ADD, 32'h0000_0000, 1, 1); // 负溢+进位
        // SUB
        check32(32'h0000_0005, 32'h0000_0003, SUB, 32'h0000_0002, 0, 0); // 5-3
        check32(32'h0000_0000, 32'h0000_0001, SUB, 32'hFFFF_FFFF, 1, 0); // 0-1 借位
        check32(32'h8000_0000, 32'h0000_0001, SUB, 32'h7FFF_FFFF, 0, 1); // 负溢
        // MUL
        check32(32'hFFFF_FFFF, 32'h0000_0001, MUL, 32'hFFFF_FFFF, 0, 0); // -1*1 低32位
        check32(32'h0001_0000, 32'h0001_0000, MUL, 32'h0000_0000, 0, 0); // 积33位,低32=0
        check32(32'h1234_5678, 32'h0000_0001, MUL, 32'h1234_5678, 0, 0);
        // SLT / SLTU
        check32(32'hFFFF_FFFF, 32'h0000_0000, SLT, 32'h0000_0001, 0, 0); // -1<0 真
        check32(32'h0000_0000, 32'hFFFF_FFFF, SLT, 32'h0000_0000, 0, 0); // 0<-1 假
        check32(32'hFFFF_FFFF, 32'h0000_0000, SLTU,32'h0000_0000, 0, 0); // 无符号 大>0 假
        check32(32'h0000_0001, 32'h0000_0002, SLTU,32'h0000_0001, 0, 0); // 1<2 真
        // AND / OR / XOR / NOR
        check32(32'h0F0F_0F0F, 32'h00FF_00FF, AND, 32'h000F_000F, 0, 0);
        check32(32'h0000_00F0, 32'h0000_000F, OR,  32'h0000_00FF, 0, 0);
        check32(32'hAAAA_AAAA, 32'h5555_5555, XOR, 32'hFFFF_FFFF, 0, 0);
        check32(32'h0000_0000, 32'hF0A5_E187, NOR, 32'h0F5A_1E78, 0, 0); // ~(0|x) = 全取反
        check32(32'h0000_0000, 32'h0000_0000, NOR, 32'hFFFF_FFFF, 0, 0); // NOR(0,0) = 全1
        check32(32'hFFFF_FFFF, 32'hFFFF_FFFF, NOR, 32'h0000_0000, 0, 0); // NOR(全1,全1)=0
        // 移位 (移位量 = b[4:0])
        check32(32'h0000_0001, 32'h0000_001F, SLL, 32'h8000_0000, 0, 0); // 1<<31
        check32(32'h1234_5678, 32'h0000_0000, SLL, 32'h1234_5678, 0, 0); // 移0位
        check32(32'h8000_0000, 32'h0000_001F, SRL, 32'h0000_0001, 0, 0); // 逻辑 >>31
        check32(32'h8000_0000, 32'h0000_001F, SRA, 32'hFFFF_FFFF, 0, 0); // 算术 >>31 符号扩展
        check32(32'h8000_0000, 32'h0000_0001, SRA, 32'hC000_0000, 0, 0); // 算术 >>1
        check32(32'h4000_0000, 32'h0000_001F, SRA, 32'h0000_0000, 0, 0); // 正数 >>31 = 0
        // 未定义 op (32-bit 同样走 default)
        check32(32'h1234_ABCD, 32'h0000_FFFF, 4'hC,  32'h0000_0000, 0, 0);
        check32(32'hDEAD_BEEF, 32'hCAFE_F00D, 4'hF,  32'h0000_0000, 0, 0);

        // ---------- 汇总 ----------
        if (errs == 0) begin
            $display("PASS: ALU 全部 %0d 项检查通过", total);
            $display("      - 8-bit 穷举: 65536 操作数 x %0d 操作 (每项校 result/zero/neg/carry/overflow)", OP_N);
            $display("      - 操作码: 官方 %0d 种 (ETH Table 1 编码) + 扩展 %0d 种", 7, OP_N - 7);
            $display("      - 32-bit 定向: W=32 的进位/溢出位位置、符号扩展、大数乘法取低位");
        end else begin
            $display("FAIL: 共 %0d / %0d 项错误", errs, total);
        end
        $finish;
    end

endmodule

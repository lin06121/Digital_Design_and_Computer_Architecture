//====================================================================
// tb_lab2.sv —— Lab 2 加法器(含加/减模式)穷举验证
// DUT 直接是顶层 lab2_top, 验证 SW -> LEDR 的真实映射。
//
// 用 Quartus 跑: Tools -> Run Simulation Tool -> RTL Simulation (NativeLink)
//    (需在 Settings -> EDA Tool Settings -> Simulation 里先选工具并登记本 tb)
// 用 iverilog : iverilog -g2012 -o tb.out lab2_top.sv tb_lab2.sv && vvp tb.out
//====================================================================
`timescale 1ns/1ps
module tb_lab2;
    logic [9:0] SW;
    logic [9:0] LEDR;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

    lab2_top dut (.SW(SW), .LEDR(LEDR), .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
                  .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5));

    integer errs = 0;

    initial begin
        // ---- 加法模式: A + B + Cin, 穷举 16*16*2 = 512 组合 ----
        $display("== Lab 2: 加法模式穷举 ==");
        for (int A = 0; A < 16; A = A + 1) begin
            for (int B = 0; B < 16; B = B + 1) begin
                for (int C = 0; C < 2; C = C + 1) begin
                    SW = '0;
                    SW[3:0] = A;
                    SW[7:4] = B;
                    SW[8]   = C;
                    SW[9]   = 1'b0;             // 加法
                    #1;
                    if (LEDR[4:0] != (A + B + C)) begin
                        $display("FAIL(add): A=%0d B=%0d Cin=%0d -> 得 %b, 期望 %b",
                                 A, B, C, LEDR[4:0], (A + B + C));
                        errs = errs + 1;
                    end
                end
            end
        end

        // ---- 减法模式: A - B, 穷举 16*16 = 256 组合 ----
        // 硬件里 A-B = A + ~B + 1, 所以 {cout, sum} = 16 + (A - B);
        // cout=1 表示"无借位"(A>=B), cout=0 表示"借位"(A<B)。
        $display("== Lab 2: 减法模式穷举 ==");
        for (int A = 0; A < 16; A = A + 1) begin
            for (int B = 0; B < 16; B = B + 1) begin
                SW = '0;
                SW[3:0] = A;
                SW[7:4] = B;
                SW[9]   = 1'b1;                 // 减法 (SW[8] 无关, 保持 0)
                #1;
                if (LEDR[4:0] != (16 + (A - B))) begin
                    $display("FAIL(sub): A=%0d B=%0d -> 得 %b, 期望 %b",
                             A, B, LEDR[4:0], (16 + (A - B)));
                    errs = errs + 1;
                end
            end
        end

        if (errs == 0) $display("PASS: 加法 512 + 减法 256 = 768 组合全部正确");
        else           $display("共 %0d 处错误", errs);
        $finish;
    end
endmodule
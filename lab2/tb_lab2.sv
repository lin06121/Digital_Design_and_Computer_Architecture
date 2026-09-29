//====================================================================
// tb_lab2.sv —— Lab 2 全加器/行波加法器的穷举验证
//
// 运行 (3 选 1):
//   Questa   : Quartus 里 Assignments->Settings->EDA Tool Settings->Simulation,
//              把本文件设为 testbench, 跑 RTL Simulation
//   iverilog : iverilog -g2012 -o tb.out lab2_top.sv tb_lab2.sv && vvp tb.out
//   Verilator: verilator --binary -Wno-fatal lab2_top.sv tb_lab2.sv -o tb
//====================================================================
`timescale 1ns/1ps
module tb_lab2;
    logic [3:0] a, b;
    logic       cin;
    logic [3:0] sum;
    logic       cout;

    ripple_carry_adder #(.W(4)) dut (
        .a(a), .b(b), .cin(cin), .sum(sum), .cout(cout)
    );

    integer errs = 0;
    initial begin
        $display("== Lab 2: 穷举验证 4 位行波进位加法器 ==");
        for (int A = 0; A < 16; A = A + 1) begin
            for (int B = 0; B < 16; B = B + 1) begin
                for (int C = 0; C < 2; C = C + 1) begin
                    a = A; b = B; cin = C;
                    #1;
                    if ({cout, sum} != (A + B + C)) begin
                        $display("FAIL: a=%0d b=%0d cin=%0d -> 得 %b, 期望 %b",
                                 A, B, C, {cout, sum}, (A + B + C));
                        errs = errs + 1;
                    end
                end
            end
        end
        if (errs == 0) $display("PASS: 16*16*2 = 512 种组合全部正确");
        else           $display("共 %0d 处错误", errs);
        $finish;
    end
endmodule
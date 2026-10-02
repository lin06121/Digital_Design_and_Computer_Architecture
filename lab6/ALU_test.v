`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: ETH Zurich
// Engineer: Frank K. Gurkaynak
//
// Create Date:   15:24:03 03/17/2011
// Design Name:   alu
// Module Name:   ALU_test.v
// Project Name:  Lab5b
// Target Device:
// Tool versions:
// Description: Simple testbench to test the ALU
//
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
////////////////////////////////////////////////////////////////////////////////
//
//  本文件是 ETH 官方 lab6_files/ALU_test.v 骨架的【填完版】。
//  官方原本留了 4 个 TO DO, 下面用 [TO DO n] 标出对应位置和填法:
//
//    [TO DO 1] 定义 testvec 数组 —— 每条 100 bit = {aluop, a, b, exp_result}
//              4 + 32 + 32 + 32 = 100, 与第 81 行的拼接和 99 行的
//              testvec[..][99:96] 判 X 完全对应。开 200 条 (需要 >=100)。
//    [TO DO 2] 把 testvectors_hex.txt 读进 testvec —— 用 $readmemh。
//              文件每行就是一个 100 bit 的十六进制字, 25 个 hex 数字。
//    [TO DO 3] 由 exp_result 算出 exp_zero —— 组合逻辑, 结果全 0 时为 1。
//    [TO DO 4] 实例化被测 ALU (UUT)。
//
//  UUT 可切换:
//    默认             -> 本目录 alu.sv (Lab 5 写的 ALU)
//    +define+USE_BAD_ALU -> bad_ALU.v (官方故意写错的版本, 用来练调试)
//  跑法:  vlog -sv alu.sv ALU_test.v          然后 vsim work.ALU_test
//
//  注: 官方原始 testvectors_hex.txt 里除第一行外 Result 列全是空的
//      (那是留给你填的模板)。本目录的 testvectors_hex.txt 已扩到 102 条
//      并全部算好期望值; 官方原件另存为 testvectors_hex_official.txt。
////////////////////////////////////////////////////////////////////////////////

module ALU_test();

    // Inputs
    reg [31:0]	a;
    reg [31:0]	b;
    reg [3:0]	aluop;

    // Outputs
    wire [31:0]	result;
    wire		zero;

    // Test clock
    reg			clk ; // in this version we do not really need the clock

    // Expected outputs
    reg [31:0]	exp_result;
    wire		exp_zero;

    // Vector and Error counts
    reg [10:0]	vec_cnt, err_cnt;

    // ------------------------------------------------------------------------
    // [TO DO 1] 定义 testvec 数组, 宽度足以放下:
    //             输入  aluop, a, b
    //             输出  exp_result
    //           每条 4+32+32+32 = 100 bit, 至少 100 条。
    //           (exp_zero 不入数组, 由 exp_result 现算)
    // ------------------------------------------------------------------------
    reg [99:0]	testvec [0:199];

    // The test clock generation
    always				// process always triggers
    begin
    clk = 1; #50;		// clk is 1 for 50 ns
    clk = 0; #50;		// clk is 0 for 50 ns
    end					// generate a 100 ns clock

    // Initialization
    initial
    begin
        // --------------------------------------------------------------------
        // [TO DO 2] 把 testvectors_hex.txt 读进 testvec。
        //           文件是十六进制, 每行 25 个 hex 数字 = 100 bit,
        //           $readmemh 会把每个字依次填进 testvec[0], testvec[1] ...
        //           没被填到的表项保持 X —— 正是第 99 行判 [99:96]===4'bxxxx
        //           用来识别"向量用完了"的机制。
        // --------------------------------------------------------------------
        $readmemh("testvectors_hex.txt", testvec);

        err_cnt = 0; // number of errors
        vec_cnt = 0; // number of vectors
    end

    // ------------------------------------------------------------------------
    // [TO DO 3] 由 exp_result 算出 exp_zero。
    //           纯组合: 结果全 0 时 Zero 标志为 1 (官方 Table 1 的定义)。
    // ------------------------------------------------------------------------
    assign exp_zero = (exp_result == 32'b0);

    // Tests
    always @ (posedge clk)		// trigger with the test clock
    begin
        // Wait 20 ns, so that we can safely apply the inputs
        #20;

        // Assign the signals from the testvec array
        {aluop,a,b,exp_result} = testvec[vec_cnt];

        // Wait another 60ns after which we will be at 80ns
        #60;

        // Check if output is not what we expect to see
        if ((result !== exp_result) | (zero !== exp_zero))
        begin
            // Display message
            $display("Error at %5d ns: Aluop %b a = %h b = %h", $time, aluop,a,b);	// %h displays hex
            $display("       %h (%h expected)",result,exp_result);
            $display(" Zero: %b (%b expected)",zero,exp_zero);							// %b displays binary
            err_cnt = err_cnt + 1;																// increment error count
        end

        vec_cnt = vec_cnt + 1;																	// next vector

        // We use === so that we can also test for X
        if ((testvec[vec_cnt][99:96] === 4'bxxxx))
        begin
            // End of test, no more entries...
            $display ("%d tests completed with %d errors", vec_cnt, err_cnt);

            // Wait so that we can see the last result
            #20;

            // Terminate simulation
            $finish;
        end
    end

    // ------------------------------------------------------------------------
    // [TO DO 4] 实例化被测 ALU (UUT)。
    //           端口对应:  tb 的 aluop -> UUT 的 op (本仓库 ALU 的端口名)
    //           neg / carry / overflow 官方测试台不检查, 留空不接。
    // ------------------------------------------------------------------------
`ifdef USE_BAD_ALU
    bad_ALU uut (
        .a(a), .b(b), .aluop(aluop),
        .result(result), .zero(zero)
    );
`else
    // 官方测试台只看 result/zero。本仓库 ALU 多出的三个标志位接成哑线,
    // 否则 vopt 会报 "Missing connection for port" 警告 —— 接上即可保持 0 warning。
    wire neg_dummy, carry_dummy, overflow_dummy;
    alu #(.W(32)) uut (
        .a(a), .b(b), .op(aluop),
        .result(result), .zero(zero),
        .neg(neg_dummy), .carry(carry_dummy), .overflow(overflow_dummy)
    );
`endif

endmodule

//============================================================================
//  clockdiv.v  ——  Lab 8 时钟分频 (ETH DDCA 官方原版, 逻辑未改)
//============================================================================
//  功能 : 50 MHz -> 12.5 MHz (÷4)。用 2 位计数器, 计到 3 时 clk_en = &clk_count = 1,
//         于是每 4 个主时钟周期产生一拍高电平, 整机逻辑用它的上升沿当作 12.5MHz 时钟。
//         (官方注释里写的 "10 MHz / divided by 5" 是笔误: 这里其实是 ÷4 = 12.5 MHz,
//          与 lab8_1_manual 正文 "4x slower (12.5 MHz)" 一致。)
//============================================================================
module clockdiv(
    input  clk,
    input  rst,
    output clk_en
    );

    reg [1:0] clk_count;
    always @ (posedge clk, posedge rst)
    begin
        if (rst) clk_count <= 0;
        else
            clk_count <= clk_count + 1'b1;
    end

    assign clk_en = &clk_count;

endmodule
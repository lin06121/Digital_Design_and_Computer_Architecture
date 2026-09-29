//============================================================================
//  de1soc_top.sv  ——  DE1-SoC 通用顶层骨架 (Lab 0 模板)
//============================================================================
//  板卡      : Terasic DE1-SoC  (Cyclone V  5CSEMA5F31C6)
//  主时钟    : CLOCK_50 = 50 MHz (PIN_AF14)
//  引脚约束  : common/de1soc_pins.qsf  (Import Assignments 导入)
//
//  本文件同时是:
//    (1) 复用底座 —— 下面 [KEEP] 标注的基础模块每个 Lab 都要用, 不要改
//    (2) Lab 0 演示 —— "USER DEMO (Lab 0)" 区域已写: 跑马灯 + 数码管计数 + VGA 色条
//
//  新 Lab 的开法 (详见 common/README.md):
//    姿势 A(推荐): git-branch 后只改 "USER DEMO (Lab 0)" 区域
//    姿势 B      : 复制本文件改名 labN_top.sv, 模块名一并改, 其余保留
//============================================================================
`default_nettype none

module de1soc_top (
    input  wire         CLOCK_50,      // 50 MHz
    input  wire  [9:0]  SW,            // 滑动开关 (电平输入)
    input  wire  [3:0]  KEY,           // 按键, 低有效; [0] 作异步复位
    output logic [9:0]  LEDR,          // 红 LED, 高有效
    output logic [6:0]  HEX0, HEX1, HEX2,   // 六位七段码, 段低有效 (共阳)
    output logic [6:0]  HEX3, HEX4, HEX5,
    output logic [7:0]  VGA_R, VGA_G, VGA_B, // VGA 8bit DAC (高有效)
    output logic        VGA_CLK,       // 像素时钟 (本模板 25MHz; Lab8 换 PLL 出 25.175)
    output logic        VGA_BLANK_N,   // 低有效: 消隐
    output logic        VGA_SYNC_N,    // 本模板恒为 1
    output logic        VGA_HS, VGA_VS // 低有效同步
);

    // -----------------------------------------------------------------
    // [KEEP] 复位: KEY[0] (按下=低) -> 两级同步器异步复位/同步释放
    // -----------------------------------------------------------------
    logic rst_n, rst;
    reset_sync u_rst (.clk(CLOCK_50), .async_n(KEY[0]), .rst_n(rst_n));
    assign rst = ~rst_n;

    // -----------------------------------------------------------------
    // [KEEP] 滑动开关两级同步 (防亚稳态, SW 是异步外部输入)
    // -----------------------------------------------------------------
    logic [9:0] sw_meta, sw;
    always_ff @(posedge CLOCK_50 or negedge rst_n)
        if (!rst_n) begin sw <= '0; sw_meta <= '0; end
        else        begin {sw, sw_meta} <= {sw_meta, SW}; end

    // =================================================================
    // USER DEMO (Lab 0)  —— 新 Lab 只替换到这里为止的 demo 逻辑
    // =================================================================

    // -- 时钟分频: 100 Hz (数码管计数) / 2 Hz (跑马灯) --
    logic tick_100hz, tick_2hz;
    clk_en_div #(.DIV(25'd500_000))    u_100hz (.clk(CLOCK_50), .rst_n(rst_n), .tick(tick_100hz));
    clk_en_div #(.DIV(25'd25_000_000)) u_2hz   (.clk(CLOCK_50), .rst_n(rst_n), .tick(tick_2hz));

    // -- 数码管: 24 位计数器 100Hz 递增, 六位十六进制显示, KEY[1] 清零 --
    logic [23:0] hex_cnt;
    logic key1_sync, key1_db, key1_db_d;
    sync2        u_k1s  (.clk(CLOCK_50), .rst_n(rst_n), .d(KEY[1]),  .q(key1_sync));
    debounce #(.N(20'd100_000)) u_k1db (.clk(CLOCK_50), .rst_n(rst_n), .in(key1_sync), .out(key1_db));
    always_ff @(posedge CLOCK_50 or negedge rst_n)
        if (!rst_n) key1_db_d <= 1'b1; else key1_db_d <= key1_db;
    wire key1_pressed = key1_db_d & ~key1_db;   // 下降沿 = 按下 (低有效)

    always_ff @(posedge CLOCK_50 or negedge rst_n)
        if (!rst_n)            hex_cnt <= '0;
        else if (key1_pressed) hex_cnt <= '0;
        else if (tick_100hz)   hex_cnt <= hex_cnt + 1'b1;

    sevenseg u_h0 (.hex(hex_cnt[3:0]),   .seg(HEX0));
    sevenseg u_h1 (.hex(hex_cnt[7:4]),   .seg(HEX1));
    sevenseg u_h2 (.hex(hex_cnt[11:8]),  .seg(HEX2));
    sevenseg u_h3 (.hex(hex_cnt[15:12]), .seg(HEX3));
    sevenseg u_h4 (.hex(hex_cnt[19:16]), .seg(HEX4));
    sevenseg u_h5 (.hex(hex_cnt[23:20]), .seg(HEX5));

    // -- 红 LED: 跑马灯左右来回; SW[9]=1 时改直通显示开关状态 --
    logic [9:0] rider;
    logic       dir;
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin rider <= 10'b0000000001; dir <= 1'b0; end
        else if (tick_2hz) begin
            if (dir == 1'b0) begin
                if (rider == 10'b1000000000) dir   <= 1'b1;
                else                         rider <= rider << 1;
            end else begin
                if (rider == 10'b0000000001) dir   <= 1'b0;
                else                         rider <= rider >> 1;
            end
        end
    end
    assign LEDR = sw[9] ? sw : rider;

    // -- VGA: 50MHz 二分频 -> 25MHz 像素时钟 + 640x480@60 八条色带 --
    //    注意: 25MHz 与标准 25.175MHz 差 0.7%, 多数显示器仍能锁;
    //    Lab 8 要精确 60Hz 时, 把下面二分频替换成 PLL(50MHz -> 25.175MHz)。
    logic vga_clk;
    always_ff @(posedge CLOCK_50 or negedge rst_n)
        if (!rst_n) vga_clk <= 1'b0; else vga_clk <= ~vga_clk;
    assign VGA_CLK = vga_clk;

    logic vga_hs_n, vga_vs_n, vga_active;
    logic [10:0] hc, vc;
    vga_timing u_vga (.clk(vga_clk), .rst_n(rst_n),
                      .hsync(vga_hs_n), .vsync(vga_vs_n), .active(vga_active),
                      .hcount(hc), .vcount(vc));

    logic [7:0] r, g, b;
    always_comb begin
        if (!vga_active) {r,g,b} = 24'h000000;   // 消隐区黑
        else case (hc[9:7])                       // 8 条色带, 每条 128 像素
            3'd0: {r,g,b} = {8'hFF, 8'h00, 8'h00};// 红
            3'd1: {r,g,b} = {8'hFF, 8'h80, 8'h00};// 橙
            3'd2: {r,g,b} = {8'hFF, 8'hFF, 8'h00};// 黄
            3'd3: {r,g,b} = {8'h00, 8'hFF, 8'h00};// 绿
            3'd4: {r,g,b} = {8'h00, 8'hFF, 8'hFF};// 青
            3'd5: {r,g,b} = {8'h00, 8'h00, 8'hFF};// 蓝
            3'd6: {r,g,b} = {8'h80, 8'h00, 8'h80};// 紫
            default:{r,g,b} = {8'hFF, 8'hFF, 8'hFF};// 白
        endcase
    end
    assign VGA_R = r;  assign VGA_G = g;  assign VGA_B = b;
    assign VGA_BLANK_N = vga_active;   // 消隐区间拉低
    assign VGA_SYNC_N  = 1'b1;         // DE1-SoC 常规做法: 恒定高
    assign VGA_HS = vga_hs_n;
    assign VGA_VS = vga_vs_n;

endmodule


//============================================================================
//  [KEEP] 基础模块库 —— 后续 Lab 共用, 不要改
//============================================================================

// ------------- 复位同步器: 异步低有效, 同步释放 (两级) -------------
module reset_sync #(parameter STAGES = 2) (
    input  wire  clk, async_n,
    output logic rst_n
);
    logic [STAGES-1:0] sr;
    always_ff @(posedge clk, negedge async_n)
        if (!async_n) sr <= '0;
        else          sr <= {sr[STAGES-2:0], 1'b1};
    assign rst_n = sr[STAGES-1];
endmodule

// ------------- 两级同步器 (单 bit, 防亚稳态) -------------
module sync2 #(parameter STAGES = 2) (
    input  wire  clk, rst_n, d,
    output logic q
);
    logic [STAGES-1:0] sr;
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n) sr <= '0;
        else        sr <= {sr[STAGES-2:0], d};
    assign q = sr[STAGES-1];
endmodule

// ------------- 消抖: 输入保持稳定 N 个周期后才输出 -------------
module debounce #(parameter N = 20'd100_000) (
    input  wire  clk, rst_n, in,
    output logic out
);
    logic in_reg;
    logic [31:0] cnt;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin in_reg <= 1'b0; out <= 1'b0; cnt <= '0; end
        else begin
            in_reg <= in;
            if (in != in_reg)  cnt <= '0;     // 电平在变, 重新计时
            else if (cnt == N) out <= in;     // 稳定 N 个周期, 接受
            else               cnt <= cnt + 1'b1;
        end
    end
endmodule

// ------------- 时钟分频: 每 DIV 周期产出一拍 tick (用 tick 而非门控时钟) -------------
module clk_en_div #(parameter DIV = 32'd50_000_000) (
    input  wire  clk, rst_n,
    output logic tick
);
    logic [31:0] cnt;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)             begin cnt <= '0;  tick <= 1'b0; end
        else if (cnt == DIV-1)  begin cnt <= '0;  tick <= 1'b1; end
        else                    begin cnt <= cnt + 1'b1; tick <= 1'b0; end
    end
endmodule

// ------------- 共阳七段译码: hex -> seg[6:0]={g,f,e,d,c,b,a}, 段低有效 -------------
module sevenseg (
    input  wire  [3:0] hex,
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

// ------------- VGA 640x480@60 时序发生器 (像素时钟 ~25.175MHz) -------------
module vga_timing #(
    parameter H_ACTIVE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48, // 一行 800
    parameter V_ACTIVE = 480, V_FRONT = 10, V_SYNC = 2,  V_BACK = 33  // 一帧 525
)(
    input  wire  clk, rst_n,
    output logic hsync, vsync, active,
    output logic [10:0] hcount, vcount
);
    localparam H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
    localparam V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n)                  hcount <= '0;
        else if (hcount == H_TOTAL-1) hcount <= '0;
        else                          hcount <= hcount + 1'b1;

    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n)                       vcount <= '0;
        else if (hcount == H_TOTAL-1) begin
            if (vcount == V_TOTAL-1) vcount <= '0;
            else                     vcount <= vcount + 1'b1;
        end

    always_comb begin
        hsync  = ~((hcount >= H_ACTIVE + H_FRONT) && (hcount < H_ACTIVE + H_FRONT + H_SYNC));
        vsync  = ~((vcount >= V_ACTIVE + V_FRONT) && (vcount < V_ACTIVE + V_FRONT + V_SYNC));
        active = (hcount < H_ACTIVE) && (vcount < V_ACTIVE);
    end
endmodule
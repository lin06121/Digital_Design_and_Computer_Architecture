`timescale 1ns / 1ps
//============================================================================
//  DataMemory.v  ——  Lab 8 数据存储器 (简单单口 RAM, 64 x 32bit)
//============================================================================
//  来源  : ETH DDCA Lab 8 官方 (逻辑未改)
//  改动  : 新增 MEMFILE 参数, 默认 "datamem_h.txt" (理由同 InstructionMemory.v)。
//============================================================================
module DataMemory(
             input         CLK,  // Clock signal rising edge
             input   [5:0] A,    // Address for 64 locations (ALUResult[7:2])
             input         WE,   // Write Enable 1: Write 0: no write
             input  [31:0] WD,   // 32-bit data in
             output [31:0] RD    // 32-bit read data
    );

    parameter MEMFILE = "datamem_h.txt";

    reg [31:0] DataArr [63:0];   // This is the variable that holds the memory
    initial
      begin
        $readmemh(MEMFILE, DataArr);  // Initialize the array with this content
      end

    assign RD = DataArr[A];      // Read Data (RD) corresponds to address (A)

    always @ ( posedge CLK )     // At rising edge of CLK
      begin
        if (WE)                  // if Write Enable (WE) is set
           DataArr[A] <= WD;     // Copy Write Data (WD) to the address (A)
      end

endmodule
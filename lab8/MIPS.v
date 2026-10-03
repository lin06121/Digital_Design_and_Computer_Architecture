`timescale 1ns / 1ps
//============================================================================
//  MIPS.v  ——  Lab 8 单周期 MIPS 处理器 (Harris & Harris, 图 7.14)
//============================================================================
//  来源  : ETH DDCA Lab 8 官方骨架 (Frank K. Gurkaynak)
//  本仓库改动 (即官方要求你完成的 "TODO Part 1"):
//    (1) 填了 4 个实例化  —— 指令存储器 / ALU / 数据存储器 / 控制单元
//    (2) 填了 4 个 MMIO 赋值 —— DataMemWrite / IOWriteData / IOAddr / IOWriteEn
//    (3) 新增 IMEM_FILE / DMEM_FILE 参数, 供仿真注入测试程序
//        (默认值与官方一致, 不改上板行为)
//
//  注意:
//    * RESET 高有效, 复位后 PC = 0x00002FFC (compact 布局 text 在 0x3000,
//      首拍取到的是 nop, 无害)。
//    * ALU 只用了 ALUControl 的低 4 位 [3:0] (= Funct[3:0])。
//    * IsIO 判断 ALUResult 落在 0x00007FF0 .. 0x00007FFF 这段 MMIO 地址。
//============================================================================
module MIPS(
             input CLK,                   // Clock signal
             input RESET,                 // Reset (active high) sets back the Program counter
             output [31:0] IOWriteData,   // IO Data to be written to the interface
             output [3:0]  IOAddr,        // IO Address, 4 bits (could be more)
             output        IOWriteEn,     // 1: There is a valid IO Write
             input  [31:0] IOReadData     // 32bit input from the I/O interface
    );

   parameter IMEM_FILE = "insmem_h.txt";
   parameter DMEM_FILE = "datamem_h.txt";

//////////////////////////////////////////////////////////////////////////////////
   // Signal Declarations (Refer to Figure 7.14, p.379 for names)

   // Instruction Decoding
   wire [31:0] Instr;     // The output of the Instruction memory
   wire [31:0] SignImm;   // 32-bit extended Immediate value
   wire [4:0]  WriteReg;  // Address of the register for write back

   // Address controls
   reg  [31:0] PC;        // The Program counter (registered)
   wire [31:0] PCbar;     // Next state value of the Program counter, PC' in the diagram
   wire [31:0] PCCalc;    // Calculated value for the (next) PC
   wire [31:0] PCJump;    // Value for immediate jump
   wire [31:0] PCBranch;  // Value calculated for the branch instructions
   wire [31:0] PCPlus4;   // The current value of PC + 4, default next memory address

   // ALU related
   wire [31:0] SrcA;      // One input of the ALU
   wire [31:0] SrcB;      // Other input of the ALU
   wire [31:0] ALUResult; // The output of the ALU
   wire        Zero;      // The Zero flag, 1: if ALUResult == 0

   // Data Memory
   wire [31:0] WriteData; // The output of Register File port 2
   wire [31:0] ReadData;  // Output of the Data Memory
   wire [31:0] Result;    // End result that will be written back to register file
   wire        MemWrite;  // Write Enable for the Memory

   // Control Signals
   wire        Jump;      // A direct jump instruction has been issued
   wire        MemtoReg;  // 1: Copy data from Data Memory to Register File
   wire        Branch;    // 1: We have a branch instruction
   wire        PCSrc;     // We have a Branch AND ALUResult is zero, we will branch
   wire [5:0]  ALUControl;// Control signals for the ALU
   wire        ALUSrc;    // 0: Register file, 1: Immediate value
   wire        RegDst;    // Destination Register 1: Instr[15:11] 0: Instr[20:15]
   wire        RegWrite;  // 1: We will write back to the RegisterFile

   // Memory Mapped I/O Signals
   wire        IsIO;        // 1: if Address is in I/O range 0x00007ff0 to 0x00007fff
   wire        DataMemWrite;// 1: if MemWrite and not IsIO, we write to memory (not IO)
   wire [31:0] ReadMemIO;   // Read from either Memory or I/O

//////////////////////////////////////////////////////////////////////////////////
// The Main Part of the MIPS processor

   // The Program Counter
   always @ ( posedge CLK, posedge RESET )
     if    (RESET   == 1'b1) PC <= 32'h00002FFC; // default program counter
     else                    PC <= PCbar;        // Copy next value to present

   // Calculation of the next PC value
   assign PCPlus4  = PC + 4;                             // By default the PC increments by 4
   assign PCBranch = PCPlus4 + {SignImm[29:0],2'b00};    // Branch address, p.373 Fig 7.10
   assign PCCalc   = PCSrc ? PCBranch : PCPlus4;         // Mux selects Branch or only +4
   assign PCJump   = {PCPlus4[31:28], Instr[25:0], 2'b00}; // The Jump value
   assign PCbar    = Jump  ? PCJump   : PCCalc;          // Mux selects Jump or Normal

   // Instruction Memory: 地址取 PC[7:2] (丢掉低 2 位字节地址, 得 64 字索引)
   InstructionMemory #(.MEMFILE(IMEM_FILE)) i_imem (
                          .A(PC[7:2]),
                          .RD(Instr)
                        );

   // Sign extension, replicate the MSB of the Immediate value
   assign SignImm = {{16{Instr[15]}}, Instr[15:0]};

   // Determine the Write Back address for the Register File
   assign WriteReg = RegDst ? Instr[15:11] : Instr[20:16];

   // Register File
   RegisterFile i_regf (
                        .A1(Instr[25:21]),   // Address for First Register (rs)
                        .A2(Instr[20:16]),   // Address for Second Register (rt)
                        .A3(WriteReg),       // Address for Write Back
                        .RD1(SrcA),          // First output directly connected to ALU
                        .RD2(WriteData),     // Second output
                        .WD3(Result),        // Output of ALU or Data Memory
                        .WE3(RegWrite),      // From the control unit
                        .CLK(CLK)            // System Clock
                       );

   // ALU: first determine the B input (immediate or register), then instantiate
   assign SrcB = ALUSrc ? SignImm : WriteData;

   ALU i_alu (
              .a(SrcA),
              .b(SrcB),
              .aluop(ALUControl[3:0]),   // 控制单元给 6 位, ALU 只用低 4 位
              .result(ALUResult),
              .zero(Zero)
             );

   // Generate the PCSrc signal that tells to take the branch
   assign PCSrc = Branch & Zero;

   // Data Memory: 地址取 ALUResult[7:2] (64 字索引)
   DataMemory #(.MEMFILE(DMEM_FILE)) i_dmem (
                      .CLK(CLK),
                      .A(ALUResult[7:2]),
                      .WE(DataMemWrite),
                      .WD(WriteData),
                      .RD(ReadData)
                     );

   // Memory Mapped I/O
   assign IsIO = (ALUResult[31:4] == 28'h00007ff) ? 1 : 0; // 地址落在 I/O 段

   assign DataMemWrite = MemWrite & ~IsIO;   // SW 且目标是数据内存
   assign IOWriteData  = WriteData;          // 直接透传寄存器堆 B 口
   assign IOAddr       = ALUResult[3:0];     // 取地址低 4 位作为外设号
   assign IOWriteEn    = MemWrite & IsIO;    // SW 且目标在 I/O 段

   assign ReadMemIO = IsIO ? IOReadData : ReadData;     // Mux 选 内存 or I/O
   assign Result    = MemtoReg ? ReadMemIO : ALUResult; // 写回数据来源

   // The Control Unit
   ControlUnit i_cont (
                       .Op(Instr[31:26]),
                       .Funct(Instr[5:0]),
                       .Jump(Jump),
                       .MemtoReg(MemtoReg),
                       .MemWrite(MemWrite),
                       .Branch(Branch),
                       .ALUControl(ALUControl),
                       .ALUSrc(ALUSrc),
                       .RegDst(RegDst),
                       .RegWrite(RegWrite)
                      );

endmodule
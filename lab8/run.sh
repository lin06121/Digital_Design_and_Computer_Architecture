#!/usr/bin/env bash
# ============================================================================
#  Lab 8 —— MIPS 处理器验证一键脚本 (Git Bash; 需 Questa Altera FPGA Starter)
#  用法:  cd lab8 && bash run.sh
#
#  跑三遍:
#    1) tb_lab8       —— 手编微程序自检 (R型ALU + 寄存器堆 + lw/sw + MMIO写 + IO读)
#    2) tb_lab8_snake —— 官方蛇程序 + DE1-SoC 顶层, 检查首帧图案
#    3) tb_lab8_sw    —— Part2 开关读入链路 (SW -> IOReadData -> 显示)
#  三遍都必须 PASS。综合/上板用 Quartus 工程 lab8_top.qpf 另行确认。
# ============================================================================
set -e
cd "$(dirname "$0")"

echo "=============================================================="
echo " 编译所有 RTL + testbench"
echo "=============================================================="
rm -rf work
vlib work >/dev/null
vlog -sv \
  MIPS.v ALU.v ControlUnit.v InstructionMemory.v DataMemory.v \
  RegisterFile.v clockdiv.v top.v \
  tb_lab8.sv tb_lab8_snake.sv tb_lab8_sw.sv

echo
echo "=============================================================="
echo " 1/3  tb_lab8 —— 微程序自检"
echo "=============================================================="
vsim -c -do "run -all; quit -f" work.tb_lab8

echo
echo "=============================================================="
echo " 2/3  tb_lab8_snake —— 官方蛇程序首帧"
echo "=============================================================="
vsim -c -do "run -all; quit -f" work.tb_lab8_snake

echo
echo "=============================================================="
echo " 3/3  tb_lab8_sw —— Part2 开关读入链路"
echo "=============================================================="
vsim -c -do "run -all; quit -f" work.tb_lab8_sw

echo
echo "=============================================================="
echo " Lab 8 全部仿真通过 ✅"
echo "=============================================================="
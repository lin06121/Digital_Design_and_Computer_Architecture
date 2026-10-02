#!/usr/bin/env bash
# ============================================================================
#  Lab 6 —— ALU 验证一键脚本 (Git Bash; 需 Questa Altera FPGA Starter 在 PATH)
#  用法:  cd lab6 && bash run.sh
#
#  跑三遍:
#    1) tb_lab6    —— 穷举 8-bit + 定向 32-bit (自检测, 期望值来自参考模型/手算)
#    2) ALU_test   —— ETH 官方骨架测试台, 读 testvectors_hex.txt 的 102 条向量
#    3) bad_ALU    —— 官方故意写错的 ALU, 用同一套向量把 bug 抓出来 (调试练习)
#
#  1、2 都必须 PASS; 第 3 遍【故意 FAIL】, 那是原课要你观察的调试输出。
# ============================================================================
set -e
cd "$(dirname "$0")"

echo "=============================================================="
echo " 1/3  tb_lab6  —— 穷举 + 定向 (自检测)"
echo "=============================================================="
rm -rf work; vlib work >/dev/null
vlog -sv alu.sv tb_lab6.sv
vsim -c -do "run -all; quit -f" work.tb_lab6

echo
echo "=============================================================="
echo " 2/3  ALU_test —— ETH 官方骨架测试台 (102 条向量)"
echo "=============================================================="
rm -rf work; vlib work >/dev/null
vlog -sv alu.sv ALU_test.v
vsim -c -do "run -all; quit -f" work.ALU_test

echo
echo "=============================================================="
echo " 3/3  bad_ALU  —— 官方带 bug 版本 (预期 FAIL, 观察报错)"
echo "=============================================================="
rm -rf work; vlib work >/dev/null
vlog -sv bad_ALU.v +define+USE_BAD_ALU ALU_test.v
vsim -c -do "run -all; quit -f" work.ALU_test || true
echo
echo "(第 3 遍失败是正常的 —— bad_ALU.v 就是官方留给你调的那份)"

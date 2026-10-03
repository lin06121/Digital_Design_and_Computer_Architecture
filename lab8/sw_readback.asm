# sw_readback.asm —— 顶层开关多路器测试程序
# 功能: 读 I/O 寄存器 0x7FF4 (2-bit 开关 SW[1:0]) 立即写回显示寄存器 0x7FF0。
#       tb_lab8_sw 据此断言: 显示寄存器 = {30'b0, SW}, 即顶层 IOReadData 多路器
#       把开关值正确送到了处理器, 处理器再经 MMIO 写回到数码管。
# 用 asm.py 汇编:
#       python asm.py sw_readback.asm sw_readback_insmem_h.txt sw_readback_datamem_h.txt

        .text
        lw      $t0, 0x7ff4($0)     # $t0 = IOReadData = {30'b0, SW}
        sw      $t0, 0x7ff0($0)     # 显示寄存器 = $t0 -> HEX0 低两位反映 SW
loop:
        j       loop                # 自旋
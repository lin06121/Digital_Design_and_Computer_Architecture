#============================================================================
#  snake_patterns_speed.asm  ——  Lab 8 Part 2: 开关调速的爬行蛇
#============================================================================
#  在官方 snake_patterns.asm 基础上加"读开关调速"。本机没装 Java 跑不了
#  MARS 导出 dump, 所以用同目录的 asm.py 把这俩 .text/.data 转成内存 dump:
#
#      python asm.py snake_patterns_speed.asm insmem_h_speed.txt datamem_h_speed.txt
#
#  思路 (只能用手头 ALU 支持的指令, 没有 sll/mul):
#    1. lw $t3, 0x7ff4($0)    读速度档 SW[1:0] (I/O 寄存器 0x7FF4)
#    2. add $t0,$t3,$t3        $t0 = 2*S
#       add $t0,$t0,$t0        $t0 = 4*S (两次 add 代替 sll, 得到字节偏移)
#    3. lw $t3, 0x30($t0)     用查表法取出 delay_table[S]
#    4. 后面与官方完全相同: 12 张图案循环, 每张之间用 $t3 次空转减速
#
#  数据内存布局 (compact, 数据从 0 起):
#      offset 0x00..0x2C  pattern 12 个字 (图案)
#      offset 0x30..0x3C  delay_table 4 个字 (四个速度档的延迟值)
#  速度档越大, 延迟值越小 => 蛇爬得越快:
#      SW=00 (0) -> 0x001e8484 最慢 (约 200 万次)
#      SW=01 (1) -> 0x000f4240
#      SW=10 (2) -> 0x0007a120
#      SW=11 (3) -> 0x0003d090 最快 (约 25 万次)
#============================================================================

.data
pattern:    .word 0x00200000,0x00004000,0x00000080,0x00000001,0x00000002,0x00000004,0x00000008,0x00000400,0x00020000,0x01000000,0x02000000,0x04000000
delay0:     .word 0x001e8484
delay1:     .word 0x000f4240
delay2:     .word 0x0007a120
delay3:     .word 0x0003d090

.text
   lw   $t3, 0x7ff4($0)     # $t3 = 开关速度档 (0..3)
   add  $t0, $t3, $t3       # $t0 = 2*S
   add  $t0, $t0, $t0       # $t0 = 4*S (字节偏移, 无 sll 用两次 add)
   lw   $t3, 0x30($t0)      # $t3 = delay_table[S]
   addi $t5, $0, 48         # 图案总长度 12 字 = 48 字节

restart:
   addi $t4, $0, 0          # $t4 = 当前字节偏移归 0

forward:
   beq  $t5, $t4, restart   # 偏移到 48 ? -> 重头再来
   lw   $t0, 0($t4)         # $t0 = pattern[$t4/4]
   sw   $t0, 0x7ff0($0)     # 写到 MMIO 显示寄存器 0x7FF0
   addi $t4, $t4, 4         # 偏移 += 4
   addi $t2, $0, 0          # 延迟计数器清零

wait:
   beq  $t2, $t3, forward   # 延迟计到 $t3 ? -> 显示下一张
   addi $t2, $t2, 1         # 延迟计数器 +1
   j    wait                # 继续空转
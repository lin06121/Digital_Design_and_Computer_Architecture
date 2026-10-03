#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""asm.py -- 迷你 MIPS 汇编器 (只支持 Lab 8 snake 程序用到的指令子集)

为何存在:  Lab 8 Part 2 要改 snake 程序并重新导出 insmem_h.txt/datamem_h.txt,
           官方流程用 MARS 的 "Memory Dump" 功能, 但本机没装 Java 跑不了 MARS。
           这个 ~150 行的 mini-assembler 覆盖 snake 用到的全部指令, 把 .asm 转成
           64 个 32-bit 十六进制字的内存 dump (与 MARS "Hexadecimal Text" 一致)。

支持:
   指令  add / addi / sub / slt / lw / sw / beq / j
   数据  .word
   标签  文本标签(跳转目标) / 数据标签(lw 直接引用 -> 解析成 offset($0) )

用法:
   python asm.py snake_patterns.asm insmem.txt datamem.txt     # 汇编并写两份 dump
   python asm.py --check                                       # 自检: 汇编 snake_patterns.asm
                                                                #  与官方 insmem_h.txt / datamem_h.txt 逐字比对
"""
import sys

REG = {
    'zero': 0, 'at': 1, 'v0': 2, 'v1': 3,
    'a0': 4, 'a1': 5, 'a2': 6, 'a3': 7,
    't0': 8, 't1': 9, 't2': 10, 't3': 11, 't4': 12, 't5': 13, 't6': 14, 't7': 15,
    's0': 16, 's1': 17, 's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23,
    't8': 24, 't9': 25, 'k0': 26, 'k1': 27, 'gp': 28, 'sp': 29, 'fp': 30, 'ra': 31,
}

R_FUNCT = {'add': 0x20, 'sub': 0x22, 'slt': 0x2A}
OPCODE  = {'addi': 0x08, 'lw': 0x23, 'sw': 0x2B, 'beq': 0x04, 'j': 0x02}

TEXT_BASE = 0x3000          # compact 布局: text 在 0x3000
MEMWORDS  = 64


def parse_reg(tok):
    t = tok.strip()
    if t.startswith('$'):
        name = t[1:]
        if name.isdigit():
            return int(name)
        return REG[name]
    raise ValueError('不是寄存器: %r' % tok)


def parse_imm(tok):
    t = tok.strip()
    if t.lower().startswith('0x'):
        return int(t, 16)
    return int(t, 0)


def enc_r(funct, rs, rt, rd):
    return (rs << 21) | (rt << 16) | (rd << 11) | funct


def enc_i(op, rs, rt, imm):
    return (op << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)


def enc_j(op, addr):
    return (op << 26) | ((addr >> 2) & 0x3FFFFFF)


def assemble(path):
    """返回 (insmem, datamem): 两个 64 元素的 32-bit 列表。"""
    # ---- 清洗: 去注释/空行, 保留行类型 ----
    lines = []
    for ln in open(path, encoding='utf-8'):
        ln = ln.split('#', 1)[0].strip()
        if ln:
            lines.append(ln)

    # ---- 第一遍: 收集标签地址 ----
    text_label = {}   # 标签 -> 指令 index
    data_label = {}   # 标签 -> 字节地址
    cur_seg = None
    text = []         # 指令字符串 (按序)
    data = []         # 数据字 (32-bit, 按序)
    for ln in lines:
        if ln.startswith('.'):
            if ln.startswith('.text'):
                cur_seg = 'text'
            elif ln.startswith('.data'):
                cur_seg = 'data'
            elif cur_seg == 'data' and ln.startswith('.word'):
                # 可能带标签: "label: .word ..." 或 ".word ..."
                rest = ln
                if ':' in ln:
                    lab, rest = ln.split(':', 1)
                    data_label[lab.strip()] = len(data) * 4
                for v in rest.replace('.word', '', 1).split(','):
                    v = v.strip()
                    if v:
                        data.append(parse_imm(v) & 0xFFFFFFFF)
            continue
        # 带标签的行 (文本标签)
        if ':' in ln and not ln.startswith('$'):
            lab, rest = ln.split(':', 1)
            lab = lab.strip()
            if cur_seg == 'text':
                text_label[lab] = len(text)
            else:
                data_label[lab] = len(data) * 4
            rest = rest.strip()
            if rest.startswith('.word'):
                for v in rest.replace('.word', '', 1).split(','):
                    v = v.strip()
                    if v:
                        data.append(parse_imm(v) & 0xFFFFFFFF)
            elif rest:
                text.append(rest)
            continue
        if cur_seg == 'text':
            text.append(ln)

    # ---- 第二遍: 编码文本指令 ----
    insmem = []
    for i, ins in enumerate(text):
        toks = ins.replace(',', ' ').split()
        op = toks[0]
        if op in R_FUNCT:
            rd, rs, rt = parse_reg(toks[1]), parse_reg(toks[2]), parse_reg(toks[3])
            word = enc_r(R_FUNCT[op], rs, rt, rd)
        elif op == 'addi':
            rt, rs, imm = parse_reg(toks[1]), parse_reg(toks[2]), parse_imm(toks[3])
            word = enc_i(OPCODE[op], rs, rt, imm)
        elif op in ('lw', 'sw'):
            rt = parse_reg(toks[1])
            off_tok = toks[2]
            if '(' in off_tok:                       # offset(base)
                off, base = off_tok.split('(')
                base = parse_reg(base.rstrip(')'))
                off = parse_imm(off) if off.strip() else 0
            else:                                    # 纯数据标签 -> offset($0)
                off = data_label[off_tok]
                base = 0
            word = enc_i(OPCODE[op], base, rt, off)
        elif op == 'beq':
            rs, rt, lab = parse_reg(toks[1]), parse_reg(toks[2]), toks[3]
            target = text_label[lab]
            off = target - (i + 1)                   # 相对下一条指令
            word = enc_i(OPCODE[op], rs, rt, off)
        elif op == 'j':
            lab = toks[1]
            addr = TEXT_BASE + 4 * text_label[lab]
            word = enc_j(OPCODE[op], addr)
        else:
            raise ValueError('不支持的指令: %s' % ins)
        insmem.append(word & 0xFFFFFFFF)

    # ---- 补齐到 64 字, 后补 0 ----
    insmem += [0] * (MEMWORDS - len(insmem))
    data   += [0] * (MEMWORDS - len(data))
    return insmem, data


def dump_str(words):
    return '\n'.join('%08x' % w for w in words)


def write_mem(path, words):
    with open(path, 'w') as f:
        f.write(dump_str(words) + '\n')


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == '--check':
        insmem, data = assemble('snake_patterns.asm')
        ok = True
        got_i = dump_str(insmem).splitlines()
        got_d = dump_str(data).splitlines()
        exp_i = open('insmem_h.txt').read().splitlines()
        exp_d = open('datamem_h.txt').read().splitlines()
        for fname, got, exp in [('insmem_h.txt', got_i, exp_i),
                                ('datamem_h.txt', got_d, exp_d)]:
            # 只比对齐到 64 行的部分
            got = [g for g in got if g]
            exp = [e for e in exp if e]
            if got != exp:
                ok = False
                print('MISMATCH in %s:' % fname)
                for n, (g, e) in enumerate(zip(got, exp)):
                    if g != e:
                        print('  行%02d: 汇编=%s  官方=%s' % (n, g, e))
                        break
        if ok:
            print('PASS: asm.py 汇编 snake_patterns.asm 与官方 dump 逐字一致')
            return 0
        print('FAIL: 见上')
        return 1

    if len(sys.argv) < 2:
        sys.stderr.write(__doc__)
        return 2
    src = sys.argv[1]
    insmem, data = assemble(src)
    if len(sys.argv) >= 4:
        write_mem(sys.argv[2], insmem)
        write_mem(sys.argv[3], data)
        print('已写入 %s (text, %d 字) 和 %s (data, %d 字)'
              % (sys.argv[2], len([w for w in insmem if w]),
                 sys.argv[3], len([w for w in data if w])))
    else:
        print('# ---- insmem (text) ----')
        print(dump_str(insmem))
        print('# ---- datamem (data) ----')
        print(dump_str(data))
    return 0


if __name__ == '__main__':
    sys.exit(main())
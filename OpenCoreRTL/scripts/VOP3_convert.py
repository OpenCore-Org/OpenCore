#!/usr/bin/env python3

import sys

if len(sys.argv) < 2:
    print("Not enough arguments!")
    sys.exit(0)


scale = 16
first_32bits = bin(int(sys.argv[1], scale))[2:].zfill(32)
second_32_bits = bin(int(sys.argv[2], scale))[2:].zfill(32) 

# print(first_32bits)
# print(second_32_bits)

vop3_type_bits = first_32bits[0:6]
op = int(first_32bits[6:16], 2)
clmp = first_32bits[16]
sdst = int(first_32bits[17:24], 2)
op_sel = first_32bits[17:21]
abs = first_32bits[21:24]
vdst = int(first_32bits[24:32], 2)

neg = second_32_bits[0:3]
omod = second_32_bits[3:5]
src2 = int(second_32_bits[5:14], 2)
src1 = int(second_32_bits[14:23], 2)
src0 = int(second_32_bits[23:32], 2)

if vop3_type_bits != "110101":
    print("Not a VOP3 instruction!")
else:
    print(f"op={op}, clmp={clmp}, opsel={op_sel}, abs={abs}, sdst={sdst}, vdst={vdst}")
    print(f"neg={neg}, omod={omod}, src2={src2}, src1={src1}, src0={src0}")

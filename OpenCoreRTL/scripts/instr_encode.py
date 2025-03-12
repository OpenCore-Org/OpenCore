import argparse

parser = argparse.ArgumentParser()

# Instruction Types
scalar_inst_types = ["SOP1", "SOP2", "SOPK", "SOPC", "SOPP"]
vector_inst_types = ["VOP1", "VOP2", "VOPC", "VOP3A", "VOP3B"]
all_inst_types = scalar_inst_types + vector_inst_types

# Insruction fields
parser.add_argument("--inst", type=str, choices=all_inst_types, required=True)
parser.add_argument("--op", type=int)
parser.add_argument("--sdst", type=int)
parser.add_argument("--vdst", type=int)
parser.add_argument("--src0", type=int)
parser.add_argument("--src1", type=int)
parser.add_argument("--src2", type=int)
parser.add_argument("--simm16", type=int)
parser.add_argument("--clmp", type=int)
parser.add_argument("--op_sel", type=int)
parser.add_argument("--abs", type=lambda x: x if len(x) == 3 and x.isnumeric() else False)
parser.add_argument("--neg", type=lambda x: x if len(x) == 3 and x.isnumeric() else False)
parser.add_argument("--omod", type=int)
# Optional Arguments
vop3_group = parser.add_mutually_exclusive_group()
vop3_group.add_argument("--as_VOP3A", action="store_true", default=False)
vop3_group.add_argument("--as_VOP3B", action="store_true", default=False)

# Parse Args
args = parser.parse_args()

# Build Instruction
inst_bin = ["", ""]
if args.inst in scalar_inst_types:
    inst_bin[0] += "10"

    match args.inst:
        case "SOP1":
            inst_bin[0] += "1111101"
            inst_bin[0] += format(args.sdst, '07b')     # sdst
            inst_bin[0] += format(args.op, '08b')       # op
            inst_bin[0] += format(args.src0, '08b')     # ssrc0
        case "SOP2":
            inst_bin[0] += format(args.op, '07b')       # op
            inst_bin[0] += format(args.sdst, '07b')     # sdst
            inst_bin[0] += format(args.src1, '08b')     # ssrc1
            inst_bin[0] += format(args.src0, '08b')     # ssrc0
        case "SOPK":
            inst_bin[0] += "11"
            inst_bin[0] += format(args.op, '05b')       # op
            inst_bin[0] += format(args.sdst, '07b')     # sdst
            inst_bin[0] += format(args.simm16, '016b')  # simm16
        case "SOPC":
            inst_bin[0] += "1111110"
            inst_bin[0] += format(args.op, '07b')       # op
            inst_bin[0] += format(args.src1, '08b')     # ssrc1
            inst_bin[0] += format(args.src0, '08b')     # ssrc0
        case "SOPP":
            inst_bin[0] += "1111111"
            inst_bin[0] += format(args.op, '07b')       # op
            inst_bin[0] += format(args.simm16, '016b')  # simm16
        case _:
            raise Exception("Shouldn't be able to get here!")
elif args.inst in vector_inst_types:
    if "VOP3" in args.inst:
        inst_bin[0] += "110101"
    else:
        inst_bin[0] += "0"

        match args.inst:
            case "VOP2":
                if args.as_VOP3A or args.asVOP3B:
                    # Remove previous '0'
                    inst_bin[0] = inst_bin[0][:-1]

                    inst_bin[0] += "110101"
                    inst_bin[0] += format(args.op, '010b')  # op
                    inst_bin[0] += format(args.clmp, '01b') # clmp
                    inst_bin[0] += format(args.sdst, '07b') if args.asVOP3B else format(args.op_sel, '04b') + args.abs
                    inst_bin[0] += format(args.vdst, '08b') # vdst

                    inst_bin[1] += args.neg                 # neg
                    inst_bin[1] += format(args.omod, '02b') # omod
                    inst_bin[1] += format(args.src2, '09b') # src2
                    inst_bin[1] += format(args.src1, '09b') # src1
                    inst_bin[1] += format(args.src0, '09b') # src0

                else:
                    inst_bin[0] += format(args.op, '06b')   # op
                    inst_bin[0] += format(args.vdst, '08b') # vdst
                    inst_bin[0] += format(args.src1, '08b') # vsrc1
                    inst_bin[0] += format(args.src0, '09b') # src0
            case "VOP1":
                inst_bin[0] += "111111"
                inst_bin[0] += format(args.vdst, '08b')  # vdst
                inst_bin[0] += format(args.op, '08b')    # op
                inst_bin[0] += format(args.src0, '09b')  # ssrc0
            case "VOPC":
                inst_bin[0] += "111110"
                inst_bin[0] += format(args.op, '08b')    # op
                inst_bin[0] += format(args.src1, '08b')  # vsrc1
                inst_bin[0] += format(args.src0, '09b')  # src0
            case _:
                raise Exception("Shouldn't be able to get here!")
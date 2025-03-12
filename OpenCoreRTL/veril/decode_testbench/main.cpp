#include <stdlib.h>
#include <iostream>
#include <fstream> 
#include <bitset>
#include <limits>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vsimd32_decode.h"
// #include "Vsimd32_decode___024unit.h"

#define MAX_SIM_TIME 10000
// VERBOSE: 0 = minimal messages, 1=detailed error messages, 2=all messages
#define VERBOSE 1

#define V_ADD_CO_U32 783
#define V_SUB_CO_U32 784
#define V_SUBREV_CO_U32 793
#define V_DIV_SCALE_F32 365
#define V_DIV_SCALE_F64 366
#define V_MAD_U64_U32 374
#define V_MAD_I64_I32 375


enum Instruction_Type {SCALAR, VECTOR, FLAT, DS, EXPORT, MIMG, MBUF, SMEM};
enum Scalar_Type {SOP2, SOP1, SOPK, SOPP, SOPC};
enum Vector_Type {VOP2, VOP1, VOPC, VINTRP, VOP3A, VOP3B, VOP3P};
enum MBuf_Type {MTBUF, MUBUF};

std::string convert_enum_string(const Instruction_Type in){
    switch (in)
    {
    case SCALAR:
        return "SCALAR";
    case VECTOR:
        return "VECTOR";
    case FLAT:
        return "FLAT";
    case DS:
        return "DS";
    case EXPORT:
        return "EXPORT";
    case MIMG:
        return "MIMG";
    case MBUF:
        return "MBUF";
    case SMEM:
        return "SMEM";
    
    default:
        return "ERROR";
    }
}

std::string convert_enum_string(const Scalar_Type in){
    switch (in)
    {
    case SOP2:
        return "SOP2";
    case SOP1:
        return "SOP1";
    case SOPK:
        return "SOPK";
    case SOPP:
        return "SOPP";
    case SOPC:
        return "SOPC";
    
    default:
        return "ERROR";
    }
}

std::string convert_enum_string(const Vector_Type in){
    switch (in)
    {
    case VOP2:
        return "VOP2";
    case VOP1:
        return "VOP1";
    case VOPC:
        return "VOPC";
    case VINTRP:
        return "VINTRP";
    case VOP3A:
        return "VOP3A";
    case VOP3B:
        return "VOP3B";
    case VOP3P:
        return "VOP3P";
    
    default:
        return "ERROR";
    }
}

std::string convert_enum_string(const MBuf_Type in){
    switch (in)
    {
    case MTBUF:
        return "MTBUF";
    case MUBUF:
        return "MUBUF";

    default:
        return "ERROR";
    }
}

std::string convert_allflag_string(const uint8_t in){
    switch (in){
    case 0:
        return "NONE";
    case 0b01000000:
        return "SCALAR";
    case 0b10000000:
        return "VECTOR";
    case 0b00100000:
        return "FLAT";
    case 0b00010000:
        return "DS";
    case 0b00001000:
        return "EXPORT";
    case 0b00000100:
        return "MIMG";
    case 0b00000010:
        return "MBUF";
    case 0b00000001:
        return "SMEM";
    
    default:
        return "ERROR";
    }
}


struct Decoded_SCALAR {
    Scalar_Type type;
    uint32_t opcode: 8;
    uint32_t dest: 7;
    uint32_t dest_in_use: 1;
    uint32_t src0: 8;
    uint32_t src0_in_use: 1;
    uint32_t src1: 8;
    uint32_t src1_in_use: 1;
    uint32_t imm: 16;
    uint32_t imm_in_use: 1;
    uint32_t literal: 32;
    uint32_t literal_in_use: 1;
};

void print_decoded_instructions(struct Decoded_SCALAR &out){
    std::cout << "-----------------------------------" << std::endl;
    std::cout << "type: " << convert_enum_string(out.type) << " (" << out.type << ")" << std::endl;
    std::cout << "opcode: " << out.opcode << std::endl;
    std::cout << "dest: " << out.dest << std::endl;
    std::cout << "dest_in_use: " << out.dest_in_use << std::endl;
    std::cout << "src0: " << out.src0 << std::endl;
    std::cout << "src0_in_use: " << out.src0_in_use << std::endl;
    std::cout << "src1: " << out.src1 << std::endl;
    std::cout << "src1_in_use: " << out.src1_in_use << std::endl;
    std::cout << "imm: " << out.imm << std::endl;
    std::cout << "imm_in_use: " << out.imm_in_use << std::endl;
    std::cout << "literal: " << out.literal << std::endl;
    std::cout << "literal_in_use: " << out.literal_in_use << std::endl;
    std::cout << "-----------------------------------" << std::endl;
}

struct SDWA{
    uint32_t sdwa_in_use:1;
    uint32_t sdwab_in_use:1;
    uint32_t s1:1;
    uint32_t src1_abs:1;
    uint32_t src1_negs:1;
    uint32_t src1_sext:1;
    uint32_t src1_sel:3;
    uint32_t s0:1;
    uint32_t src0_abs:1;
    uint32_t src0_negs:1;
    uint32_t src0_sext:1;
    uint32_t src0_sel:3;
    uint32_t omod:2;
    uint32_t cimp:1;
    uint32_t dst_u:1;
    uint32_t dst_sel:1;
    uint32_t sd:1;
    uint32_t sdst:7;
    uint32_t src0:8;
};

struct DDP8{
    uint32_t ddp8_in_use:1;
    uint32_t src0:8;
    uint32_t sel0:3;
    uint32_t sel1:3;
    uint32_t sel2:3;
    uint32_t sel3:3;
    uint32_t sel4:3;
    uint32_t sel5:3;
    uint32_t sel6:3;
    uint32_t sel7:3;
};

struct DDP16{
    uint32_t ddp16_in_use:1;
    uint32_t row_mask:4;
    uint32_t bank_mask:4;
    uint32_t src1_abs:1;
    uint32_t src1_neg:1;
    uint32_t src0_abs:1;
    uint32_t src0_neg:1;
    uint32_t bc:1;
    uint32_t fi:1;
    uint32_t dpp_ctrl:9;
    uint32_t src0:8;
};

struct Decoded_VECTOR {
    Vector_Type type;
    struct SDWA sdwa;
    struct DDP8 ddp8;
    struct DDP16 ddp16;
    uint32_t opcode: 10;
    uint32_t vdest: 8;
    uint32_t vsrc1: 8;
    uint32_t src0: 9;
    uint32_t attr: 6;
    uint32_t attr_chan: 2;
    uint32_t cimp: 1;
    uint32_t op_sel: 4;
    uint32_t op_sel_hi: 3;
    uint32_t sdest: 7;
    uint32_t abs: 3;
    uint32_t neg: 3;
    uint32_t omod: 2;
    uint32_t src1: 9;
    uint32_t src2: 9;
    uint32_t neg_hi: 8;
    uint32_t literal_in_use: 1;
    uint32_t literal: 32;
};

void print_decoded_instructions(struct Decoded_VECTOR &out){
    std::cout << "-----------------------------------" << std::endl;
    std::cout << "type: " << convert_enum_string(out.type) << " (" << out.type << ")" << std::endl;
    std::cout << "sdwa_in_use: " << out.sdwa.sdwa_in_use << std::endl;
    std::cout << "sdwab_in_use: " << out.sdwa.sdwab_in_use << std::endl;
    std::cout << "ddp8_in_use: " << out.ddp8.ddp8_in_use << std::endl;
    std::cout << "ddp16_in_use: " << out.ddp16.ddp16_in_use << std::endl;
    std::cout << "opcode: " << std::hex << out.opcode << std::endl;
    std::cout << "vdest: " << std::hex << out.vdest << std::endl;
    std::cout << "vsrc1: " << std::hex << out.vsrc1 << std::endl;
    std::cout << "src0: " << std::hex << out.src0 << std::endl;
    std::cout << "attr: " << std::hex << out.attr << std::endl;
    std::cout << "attr_chan: " << std::hex << out.attr_chan << std::endl;
    std::cout << "clmp: " << std::hex << out.cimp << std::endl;
    std::cout << "op_sel: " << std::hex << out.op_sel << std::endl;
    std::cout << "op_sel_hi: " << std::hex << out.op_sel_hi << std::endl;
    std::cout << "sdest: " << std::hex << out.sdest << std::endl;
    std::cout << "abs: " << std::hex << out.abs << std::endl;
    std::cout << "neg: " << std::hex << out.neg << std::endl;
    std::cout << "omod: " << std::hex << out.omod << std::endl;
    std::cout << "src1: " << std::hex << out.src1 << std::endl;
    std::cout << "src2: " << std::hex << out.src2 << std::endl;
    std::cout << "neg_hi: " << std::hex << out.neg_hi << std::endl;
    std::cout << "literal_in_use: " << std::hex << out.literal_in_use << std::endl;
    std::cout << "literal: " << std::hex << out.literal << std::endl;
    std::cout << "-----------------------------------" << std::endl;
}

struct Decoded_SMEM {
    uint32_t opcode: 8;
    uint32_t glc: 1;
    uint32_t dlc: 1;
    uint32_t sdata: 7;
    uint32_t sbase: 6;
    uint32_t soffset: 7;
    uint32_t offset: 21;
};

struct Decoded_DS{
    uint32_t opcode: 8;
    uint32_t gds: 1;
    uint32_t offset1: 8;
    uint32_t offset0: 8;
    uint32_t vdest: 8;
    uint32_t data1: 8;
    uint32_t data0: 8;
    uint32_t addr: 8;
};

struct Decoded_MTBUF{
    uint32_t format: 7;
    uint32_t opcode: 3;
    uint32_t dlc: 1;
    uint32_t glc: 1;
    uint32_t idxen: 1;
    uint32_t offen: 1;
    uint32_t offset: 12;
    uint32_t soffset: 8;
    uint32_t tfe: 1;
    uint32_t slc: 1;
    uint32_t opm: 1;
    uint32_t srsrc: 5;
    uint32_t vdata: 8;
    uint32_t vaddr: 8;
};

struct Decoded_MUBUF{
    uint32_t opm: 1;
    uint32_t opcode: 7;
    uint32_t lds: 1;
    uint32_t dlc: 1;
    uint32_t glc: 1;
    uint32_t idxen: 1;
    uint32_t offen: 1;
    uint32_t offset: 12;
    uint32_t soffset: 8;
    uint32_t tfe: 1;
    uint32_t slc: 1;
    uint32_t srsrc: 5;
    uint32_t vdata: 8;
    uint32_t vaddr: 8;
};

union Both_MBUF{
    struct Decoded_MTBUF mtbuf_instr;
    struct Decoded_MUBUF mubuf_instr;
};

struct Decoded_MBUF{
    MBuf_Type type;
    Both_MBUF instr;
};

void print_decoded_instructions(struct Decoded_MBUF &out){
    std::cout << "-----------------------------------" << std::endl;
    std::cout << "type: " << convert_enum_string(out.type) << " (" << out.type << ")" << std::endl;
    switch (out.type){
        case MTBUF:
            std::cout << std::hex << "format: " << out.instr.mtbuf_instr.format << std::endl;
            std::cout << std::hex << "opcode: " << out.instr.mtbuf_instr.opcode << std::endl;
            std::cout << std::hex << "dlc: " << out.instr.mtbuf_instr.dlc << std::endl;
            std::cout << std::hex << "glc: " << out.instr.mtbuf_instr.glc << std::endl;
            std::cout << std::hex << "idxen: " << out.instr.mtbuf_instr.idxen << std::endl;
            std::cout << std::hex << "offen: " << out.instr.mtbuf_instr.offen << std::endl;
            std::cout << std::hex << "offset: " << out.instr.mtbuf_instr.offset << std::endl;
            std::cout << std::hex << "soffset: " << out.instr.mtbuf_instr.soffset << std::endl;
            std::cout << std::hex << "tfe: " << out.instr.mtbuf_instr.tfe << std::endl;
            std::cout << std::hex << "slc: " << out.instr.mtbuf_instr.slc << std::endl;
            std::cout << std::hex << "opm: " << out.instr.mtbuf_instr.opm << std::endl;
            std::cout << std::hex << "srsrc: " << out.instr.mtbuf_instr.srsrc << std::endl;
            std::cout << std::hex << "vdata: " << out.instr.mtbuf_instr.vdata << std::endl;
            std::cout << std::hex << "vaddr: " << out.instr.mtbuf_instr.vaddr << std::endl;
            break;

        case MUBUF:
            std::cout << std::hex << "opm: " << out.instr.mubuf_instr.opm << std::endl;
            std::cout << std::hex << "opcode: " << out.instr.mubuf_instr.opcode << std::endl;
            std::cout << std::hex << "lds: " << out.instr.mubuf_instr.lds << std::endl;
            std::cout << std::hex << "dlc: " << out.instr.mubuf_instr.dlc << std::endl;
            std::cout << std::hex << "glc: " << out.instr.mubuf_instr.glc << std::endl;
            std::cout << std::hex << "idxen: " << out.instr.mubuf_instr.idxen << std::endl;
            std::cout << std::hex << "offen: " << out.instr.mubuf_instr.offen << std::endl;
            std::cout << std::hex << "offset: " << out.instr.mubuf_instr.offset << std::endl;
            std::cout << std::hex << "soffset: " << out.instr.mubuf_instr.soffset << std::endl;
            std::cout << std::hex << "tfe: " << out.instr.mubuf_instr.tfe << std::endl;
            std::cout << std::hex << "slc: " << out.instr.mubuf_instr.slc << std::endl;
            std::cout << std::hex << "srsrc: " << out.instr.mubuf_instr.srsrc << std::endl;
            std::cout << std::hex << "vdata: " << out.instr.mubuf_instr.vdata << std::endl;
            std::cout << std::hex << "vaddr: " << out.instr.mubuf_instr.vaddr << std::endl;
            break;
    
    default:
        std::cout << "ERROR: unrecognized type" << std::endl;
        break;
    }
    std::cout << "-----------------------------------" << std::endl;
}

struct Decoded_FLAT{
    uint32_t opcode: 7;
    uint32_t slc: 1;
    uint32_t glc: 1;
    uint32_t seg: 2;
    uint32_t lds: 1;
    uint32_t dlc: 1;
    uint32_t offset: 12;
    uint32_t vdest: 8;
    uint32_t saddr: 7;
    uint32_t data: 8;
    uint32_t addr: 8;
};

struct Decoded_EXPORT{
    uint32_t vm: 1;
    uint32_t done: 1;
    uint32_t compr: 1;
    uint32_t target: 6;
    uint32_t en: 4;
    uint32_t vsrc3: 8;
    uint32_t vsrc2: 8;
    uint32_t vsrc1: 8;
    uint32_t vsrc0: 8;
};

union Decoded_Instruction {
    struct Decoded_SCALAR scalar_instr;
    struct Decoded_VECTOR vector_instr;
    struct Decoded_SMEM smem_instr;
    struct Decoded_DS ds_instr;
    struct Decoded_MBUF mbuf_instr;
    struct Decoded_FLAT flat_instr;
    struct Decoded_EXPORT export_instr;
};


uint64_t sim_time = 0;
Vsimd32_decode *dut;
VerilatedVcdC *m_trace;


// stoi but for unsigned
unsigned stou(std::string const & str, size_t * idx = 0, int base = 10) {
    unsigned long result = std::stoul(str, idx, base);
    if (result > std::numeric_limits<unsigned>::max()) {
        throw std::out_of_range("stou");
    }
    return result;
}


void nextCycle()
{
    dut->clk ^= 1;
    dut->eval();
    m_trace->dump(sim_time);
    sim_time++;

    dut->clk ^= 1;
    dut->eval();
    m_trace->dump(sim_time);
    sim_time++;
}

int parse_string_from_file(std::string line_in, uint32_t &instruction, uint32_t &following_instr, bool &bit64_instr){
    if (line_in.size() == 9){
        instruction = stou(line_in, nullptr, 16);
        following_instr = 0;
        bit64_instr = false;
        return 0;
    } else if (line_in.size() == 18 && line_in.substr(8,1) == " "){
        instruction = stou(line_in.substr(0,8), nullptr, 16);
        following_instr = stou(line_in.substr(9,8), nullptr, 16);
        bit64_instr = true;
        return 0;
    } else {
        return 1;
    }
}


int decode_instructions(uint32_t instruction, uint32_t instruction2, bool instr2_used, Instruction_Type &instruction_type, Decoded_Instruction &decoded_instr){
    // std::cout << std::hex << instruction << std::endl;
    // std::bitset<32> x(instruction);
    // std::cout << std::hex << x << std::endl;
    // std::cout << std::hex << (instruction & 0x80000000) << std::endl;

    if ((instruction & 0x80000000) == 0){
        if ((instruction & 0xFE000000) == 0x7E000000) {
            // 0111111: VOP1 instruction
            instruction_type = VECTOR;
            decoded_instr.vector_instr.type = VOP1;
            decoded_instr.vector_instr.vdest = (instruction & 0x01FE0000) >> 17;
            decoded_instr.vector_instr.opcode = (instruction & 0x0001FE00) >> 9;
            decoded_instr.vector_instr.src0 = (instruction & 0x000001FF);
            if (decoded_instr.vector_instr.src0 == 249)
                decoded_instr.vector_instr.sdwa.sdwa_in_use = 1;
            else{
                decoded_instr.vector_instr.sdwa.sdwa_in_use = 0;
                if(instr2_used){
                    decoded_instr.vector_instr.literal = instruction2;
                    decoded_instr.vector_instr.literal_in_use = 1;
                } else {
                    decoded_instr.vector_instr.literal_in_use = 0;
                }
            }
            decoded_instr.vector_instr.sdwa.sdwab_in_use = 0;
            
        } else if ((instruction & 0xFE000000) == 0x7C000000){
            // 0111110: VOPC instruction
            instruction_type = VECTOR;
            decoded_instr.vector_instr.type = VOPC;
            decoded_instr.vector_instr.opcode = (instruction & 0x01FE0000) >> 17;
            decoded_instr.vector_instr.vsrc1 = (instruction & 0x0001FE00) >> 9;
            decoded_instr.vector_instr.src0 = (instruction & 0x000001FF);
            if (decoded_instr.vector_instr.src0 == 249)
                decoded_instr.vector_instr.sdwa.sdwab_in_use = 1;
            else{
                decoded_instr.vector_instr.sdwa.sdwab_in_use = 0;
                if(instr2_used){
                    decoded_instr.vector_instr.literal_in_use = 1;
                    decoded_instr.vector_instr.literal = instruction2;
                } else {
                    decoded_instr.vector_instr.literal_in_use = 0;
                }
            }
            decoded_instr.vector_instr.sdwa.sdwa_in_use = 0;
        } else {
            // VOP2 instruction
            instruction_type = VECTOR;
            decoded_instr.vector_instr.type = VOP2;
            decoded_instr.vector_instr.opcode = (instruction & 0x7E000000) >> 25;
            decoded_instr.vector_instr.vdest = (instruction & 0x01FE0000) >> 17;
            decoded_instr.vector_instr.vsrc1 = (instruction & 0x0001FE00) >> 9;
            decoded_instr.vector_instr.src0 = (instruction & 0x000001FF);
            if (decoded_instr.vector_instr.src0 == 249)
                decoded_instr.vector_instr.sdwa.sdwa_in_use = 1;
            else{
                decoded_instr.vector_instr.sdwa.sdwa_in_use = 0;
                if(instr2_used){
                    decoded_instr.vector_instr.literal_in_use = 1;
                    decoded_instr.vector_instr.literal = instruction2;
                } else {
                    decoded_instr.vector_instr.literal_in_use = 0;
                }
            }
            decoded_instr.vector_instr.sdwa.sdwab_in_use = 0;
        }

        if (decoded_instr.vector_instr.src0 == 233 || decoded_instr.vector_instr.src0 == 234){
            decoded_instr.vector_instr.ddp8.ddp8_in_use = 1;
            decoded_instr.vector_instr.ddp16.ddp16_in_use = 0;
        } else if (decoded_instr.vector_instr.src0 == 233){
            decoded_instr.vector_instr.ddp8.ddp8_in_use = 0;
            decoded_instr.vector_instr.ddp16.ddp16_in_use = 1;
        } else {
            decoded_instr.vector_instr.ddp8.ddp8_in_use = 0;
            decoded_instr.vector_instr.ddp16.ddp16_in_use = 0;
        }
    } else {
        if((instruction & 0x40000000) == 0){
            // first 2 bits are 10, there scalar ALU instruction
            instruction_type = SCALAR;
            if((instruction & 0xFF800000) == 0xBF800000){
                // 101111111: SOPP instruction
                decoded_instr.scalar_instr.type = SOPP;
                decoded_instr.scalar_instr.opcode = (instruction & 0x007F0000) >> 16;
                decoded_instr.scalar_instr.dest_in_use = 0;
                decoded_instr.scalar_instr.src0_in_use = 0;
                decoded_instr.scalar_instr.src1_in_use = 0;
                decoded_instr.scalar_instr.imm = (instruction & 0x0000FFFF);
                decoded_instr.scalar_instr.imm_in_use = 1;
                if(instr2_used){
                    decoded_instr.scalar_instr.literal_in_use = 1;
                    decoded_instr.scalar_instr.literal = instruction2;
                } else {
                    decoded_instr.scalar_instr.literal_in_use = 0;
                }
            } else if ((instruction & 0xFF800000) == 0xBF000000){
                // 101111110: SOPC instruction
                decoded_instr.scalar_instr.type = SOPC;
                decoded_instr.scalar_instr.opcode = (instruction & 0x007F0000) >> 16;
                decoded_instr.scalar_instr.dest_in_use = 0;
                decoded_instr.scalar_instr.src1 = (instruction & 0x0000FF00) >> 8;
                decoded_instr.scalar_instr.src1_in_use = 1;
                decoded_instr.scalar_instr.src0 = (instruction & 0x000000FF);
                decoded_instr.scalar_instr.src0_in_use = 1;
                decoded_instr.scalar_instr.imm_in_use = 0;
                if(instr2_used){
                    decoded_instr.scalar_instr.literal_in_use = 1;
                    decoded_instr.scalar_instr.literal = instruction2;
                } else {
                    decoded_instr.scalar_instr.literal_in_use = 0;
                }
            } else if ((instruction & 0xFF800000) == 0xBE800000){
                // 101111101: SOP1 instruction
                decoded_instr.scalar_instr.type = SOP1;
                decoded_instr.scalar_instr.dest = (instruction & 0x007F0000) >> 16;
                decoded_instr.scalar_instr.dest_in_use = 1;
                decoded_instr.scalar_instr.opcode = (instruction & 0x0000FF00) >> 8;
                decoded_instr.scalar_instr.src1_in_use = 0;
                decoded_instr.scalar_instr.src0 = (instruction & 0x000000FF);
                decoded_instr.scalar_instr.src0_in_use = 1;
                decoded_instr.scalar_instr.imm_in_use = 0;
                if(instr2_used){
                    decoded_instr.scalar_instr.literal_in_use = 1;
                    decoded_instr.scalar_instr.literal = instruction2;
                } else {
                    decoded_instr.scalar_instr.literal_in_use = 0;
                }
            } else if ((instruction & 0xF0000000) == 0xB0000000){
                // 1011: SOPK instruction
                decoded_instr.scalar_instr.type = SOPK;
                decoded_instr.scalar_instr.opcode = (instruction & 0x0F800000) >> 23;
                decoded_instr.scalar_instr.dest = (instruction & 0x007F0000) >> 16;
                decoded_instr.scalar_instr.dest_in_use = 1;
                decoded_instr.scalar_instr.src1_in_use = 0;
                decoded_instr.scalar_instr.src0_in_use = 0;
                decoded_instr.scalar_instr.imm = (instruction & 0x0000FFFF);
                decoded_instr.scalar_instr.imm_in_use = 1;
                if(instr2_used){
                    decoded_instr.scalar_instr.literal_in_use = 1;
                    decoded_instr.scalar_instr.literal = instruction2;
                } else {
                    decoded_instr.scalar_instr.literal_in_use = 0;
                }
            } else {
                // 10: SOP2 instruction
                decoded_instr.scalar_instr.type = SOP2;
                decoded_instr.scalar_instr.opcode = (instruction & 0x3F800000) >> 23;
                decoded_instr.scalar_instr.dest = (instruction & 0x007F0000) >> 16;
                decoded_instr.scalar_instr.dest_in_use = 1;
                decoded_instr.scalar_instr.src1 = (instruction & 0x0000FF00) >> 8;
                decoded_instr.scalar_instr.src1_in_use = 1;
                decoded_instr.scalar_instr.src0 = (instruction & 0x000000FF);
                decoded_instr.scalar_instr.src0_in_use = 1;
                decoded_instr.scalar_instr.imm_in_use = 0;
                if(instr2_used){
                    decoded_instr.scalar_instr.literal_in_use = 1;
                    decoded_instr.scalar_instr.literal = instruction2;
                } else {
                    decoded_instr.scalar_instr.literal_in_use = 0;
                }
            }
        } else {
            // first 2 bits are 11
            // 111101 is SMEM
            // 110101 is VOP3A, VOP3B
            // 110011 is VOP3P
            // 110110 is LDS, GDS
            // 111010 is MTBUF
            // 111000 is MUBUF
            // 111100 is MIMG
            // 110111 is FLAT
            // 111110 is EXPORT
            switch ((instruction & 0xFC000000) >> 26)
            {
                case 0b111101:
                    // SMEM
                    instruction_type = SMEM;
                    decoded_instr.smem_instr.opcode = (instruction & 0x03FC0000) >> 18;
                    decoded_instr.smem_instr.glc = (instruction & 0x00010000) >> 16;
                    decoded_instr.smem_instr.dlc = (instruction & 0x00004000) >> 14;
                    decoded_instr.smem_instr.sdata = (instruction & 0x00001FC0) >> 6;
                    decoded_instr.smem_instr.sbase = (instruction & 0x0000003F);
                    decoded_instr.smem_instr.soffset = (instruction2 & 0xFE000000) >> 25;
                    decoded_instr.smem_instr.offset = (instruction2 & 0x001FFFFF);
                    break;
                case 0b110101:
                    // VOP3A, VOP3B
                    instruction_type = VECTOR;
                    decoded_instr.vector_instr.opcode = (instruction & 0x03FF0000) >> 16;
                    if((decoded_instr.vector_instr.opcode == V_ADD_CO_U32)
                        || (decoded_instr.vector_instr.opcode == V_SUB_CO_U32)
                        || (decoded_instr.vector_instr.opcode == V_SUBREV_CO_U32)
                        || (decoded_instr.vector_instr.opcode == V_DIV_SCALE_F32)
                        || (decoded_instr.vector_instr.opcode == V_DIV_SCALE_F64)
                        || (decoded_instr.vector_instr.opcode == V_MAD_U64_U32)
                        || (decoded_instr.vector_instr.opcode == V_MAD_I64_I32)){
                            decoded_instr.vector_instr.type = VOP3B;
                        } else {
                            decoded_instr.vector_instr.type = VOP3A;
                        }
                    decoded_instr.vector_instr.cimp = (instruction & 0x00008000) >> 15;
                    decoded_instr.vector_instr.op_sel = (instruction & 0x00007800) >> 11;
                    decoded_instr.vector_instr.abs = (instruction & 0x00000700) >> 8;
                    decoded_instr.vector_instr.sdest = (instruction & 0x00007F00) >> 8;
                    decoded_instr.vector_instr.vdest = (instruction & 0x000000FF);
                    decoded_instr.vector_instr.neg = (instruction2 & 0xE0000000) >> 29;
                    decoded_instr.vector_instr.omod = (instruction2 & 0x18000000) >> 27;
                    decoded_instr.vector_instr.src2 = (instruction2 & 0x07FC0000) >> 18;
                    decoded_instr.vector_instr.src1 = (instruction2 & 0x0003FE00) >> 9;
                    decoded_instr.vector_instr.src0 = (instruction2 & 0x000001FF);
                    if (decoded_instr.vector_instr.src0 == 249)
                        return 2;
                    decoded_instr.vector_instr.sdwa.sdwa_in_use = 0;
                    decoded_instr.vector_instr.sdwa.sdwab_in_use = 0;
                    decoded_instr.vector_instr.literal_in_use = 0;
                    decoded_instr.vector_instr.ddp16.ddp16_in_use = 0;
                    decoded_instr.vector_instr.ddp8.ddp8_in_use = 0;
                    break;
                case 0b110011:
                    // VOP3P
                    instruction_type = VECTOR;
                    decoded_instr.vector_instr.type = VOP3P;
                    decoded_instr.vector_instr.opcode = (instruction & 0x007F0000) >> 16;
                    decoded_instr.vector_instr.cimp = (instruction & 0x00008000) >> 15;
                    decoded_instr.vector_instr.op_sel_hi = (instruction & 0x00004000) >> 12;     //moved 14 to the right, 2 to the left
                    decoded_instr.vector_instr.op_sel = (instruction & 0x00003800) >> 11;
                    decoded_instr.vector_instr.neg_hi = (instruction & 0x00000700) >> 8;
                    decoded_instr.vector_instr.vdest = (instruction & 0x000000FF);
                    decoded_instr.vector_instr.neg = (instruction2 & 0xE0000000) >> 29;
                    decoded_instr.vector_instr.op_sel_hi = decoded_instr.vector_instr.op_sel_hi + (instruction2 & 0x18000000) >> 27;
                    decoded_instr.vector_instr.src2 = (instruction2 & 0x07FC0000) >> 18;
                    decoded_instr.vector_instr.src1 = (instruction2 & 0x0003FE00) >> 9;
                    decoded_instr.vector_instr.src0 = (instruction2 & 0x000001FF);
                    if (decoded_instr.vector_instr.src0 == 249)
                        return 2;
                    decoded_instr.vector_instr.sdwa.sdwa_in_use = 0;
                    decoded_instr.vector_instr.sdwa.sdwab_in_use = 0;
                    decoded_instr.vector_instr.literal_in_use = 0;
                    decoded_instr.vector_instr.ddp16.ddp16_in_use = 0;
                    decoded_instr.vector_instr.ddp8.ddp8_in_use = 0;
                    break;
                case 0b110110:
                    // LDS, GDS
                    instruction_type = DS;
                    decoded_instr.ds_instr.opcode = (instruction & 0x03FC0000) >> 18;
                    decoded_instr.ds_instr.gds = (instruction & 0x00020000) >> 17;
                    decoded_instr.ds_instr.offset1 = (instruction & 0x0000FF00) >> 8;
                    decoded_instr.ds_instr.offset0 = (instruction & 0x000000FF);
                    decoded_instr.ds_instr.vdest = (instruction2 & 0xFF000000) >> 24;
                    decoded_instr.ds_instr.data1 = (instruction2 & 0x00FF0000) >> 16;
                    decoded_instr.ds_instr.data0 = (instruction2 & 0x0000FF00) >> 8;
                    decoded_instr.ds_instr.addr = (instruction2 & 0x000000FF);
                    break;
                case 0b111010:
                    // MTBUF
                    instruction_type = MBUF;
                    decoded_instr.mbuf_instr.type = MTBUF;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.format = (instruction & 0x03F80000) >> 19;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.opcode = (instruction & 0x00070000) >> 16;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.dlc = (instruction & 0x00008000) >> 15;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.glc = (instruction & 0x00004000) >> 14;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.idxen = (instruction & 0x00002000) >> 13;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.offen = (instruction & 0x00001000) >> 12;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.offset = (instruction & 0x00000FFF);
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.soffset = (instruction2 & 0xFF000000) >> 24;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.tfe = (instruction2 & 0x00800000) >> 23;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.slc = (instruction2 & 0x00400000) >> 22;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.opm = (instruction2 & 0x00200000) >> 21;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.srsrc = (instruction2 & 0x001F0000) >> 16;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.vdata = (instruction2 & 0x0000FF00) >> 8;
                    decoded_instr.mbuf_instr.instr.mtbuf_instr.vaddr = (instruction2 & 0x000000FF);
                    break;
                case 0b111000:
                    // MUBUF
                    instruction_type = MBUF;
                    decoded_instr.mbuf_instr.type = MUBUF;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.opm = (instruction & 0x02000000) >> 25;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.opcode = (instruction & 0x01FC0000) >> 18;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.lds = (instruction & 0x00010000) >> 16;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.dlc = (instruction & 0x00008000) >> 15;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.glc = (instruction & 0x00004000) >> 14;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.idxen = (instruction & 0x00002000) >> 13;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.offen = (instruction & 0x00001000) >> 12;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.offset = (instruction & 0x00000FFF);
                    decoded_instr.mbuf_instr.instr.mubuf_instr.soffset = (instruction2 & 0xFF000000) >> 24;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.tfe = (instruction2 & 0x00800000) >> 23;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.slc = (instruction2 & 0x00400000) >> 22;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.srsrc = (instruction2 & 0x001F0000) >> 16;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.vdata = (instruction2 & 0x0000FF00) >> 8;
                    decoded_instr.mbuf_instr.instr.mubuf_instr.vaddr = (instruction2 & 0x000000FF);
                    break;
                case 0b111100:
                    // MIMG
                    instruction_type = MIMG;
                    break;
                case 0b110111:
                    // FLAT
                    instruction_type = FLAT;
                    decoded_instr.flat_instr.opcode = (instruction & 0x01FC0000) >> 18;
                    decoded_instr.flat_instr.slc = (instruction & 0x00020000) >> 17;
                    decoded_instr.flat_instr.glc = (instruction & 0x00010000) >> 16;
                    decoded_instr.flat_instr.seg = (instruction & 0x0000C000) >> 14;
                    decoded_instr.flat_instr.lds = (instruction & 0x00002000) >> 13;
                    decoded_instr.flat_instr.dlc = (instruction & 0x00001000) >> 12;
                    decoded_instr.flat_instr.offset = (instruction & 0x00000FFF);
                    decoded_instr.flat_instr.vdest = (instruction2 & 0xFF000000) >> 24;
                    decoded_instr.flat_instr.saddr = (instruction2 & 0x007F0000) >> 16;
                    decoded_instr.flat_instr.data = (instruction2 & 0x0000FF00) >> 8;
                    decoded_instr.flat_instr.addr = (instruction2 & 0x000000FF);
                    break;
                case 0b111110:
                    // EXPORT
                    instruction_type = EXPORT;
                    decoded_instr.export_instr.vm = (instruction & 0x00001000) >> 12;
                    decoded_instr.export_instr.done = (instruction & 0x00000800) >> 11;
                    decoded_instr.export_instr.compr = (instruction & 0x00000400) >> 10;
                    decoded_instr.export_instr.target = (instruction & 0x000003F0) >> 4;
                    decoded_instr.export_instr.en = (instruction & 0x0000000F);
                    decoded_instr.export_instr.vsrc3 = (instruction2 & 0xFF000000) >> 24;
                    decoded_instr.export_instr.vsrc2 = (instruction2 & 0x00FF0000) >> 16;
                    decoded_instr.export_instr.vsrc1 = (instruction2 & 0x0000FF00) >> 8;
                    decoded_instr.export_instr.vsrc0 = (instruction2 & 0x000000FF);
                    break;
                
                default:
                    return 1;
            }
        }
    }
    return 0;
}


int interpret_scalar(struct Decoded_SCALAR &scalar_struct){
    VlWide<3> val = dut->scalar_inst_out;

    scalar_struct.literal = val[0];     //bottom 32 bits
    scalar_struct.imm = (val[1] & 0xFFFF);
    val[1] = val[1]>>16;
    scalar_struct.dest = (val[1] & 0x7F);
    val[1] = val[1]>>7;
    scalar_struct.src1 = (val[1] & 0xFF);
    val[1] = val[1]>>8;
    scalar_struct.src0 = ((val[2] & 0x7F) << 1) + (val[1] & 0x1);
    val[2] = val[2]>>7;
    scalar_struct.opcode = (val[2] & 0xFF);
    val[2] = val[2]>>8;
    uint8_t format = (val[2] & 0x7);
    switch (format){
        case 0:
            scalar_struct.type = SOP2;
            break;
        case 1:
            scalar_struct.type = SOP1;
            break;
        case 2:
            scalar_struct.type = SOPK;
            break;
        case 3:
            scalar_struct.type = SOPP;
            break;
        case 4:
            scalar_struct.type = SOPC;
            break;
        
        default:
            return 1;
    }
    return 0;
}

int compare_scalar(struct Decoded_SCALAR &golden, struct Decoded_SCALAR &comp){
    if(golden.type != comp.type){
        return 1;
    }
    if(golden.opcode != comp.opcode)
        return 2;
    if((golden.dest_in_use) && (golden.dest != comp.dest))
        return 3;
    if((golden.src0_in_use) && (golden.src0 != comp.src0))
        return 4;
    if((golden.src1_in_use) && (golden.src1 != comp.src1))
        return 5;
    if((golden.imm_in_use) && (golden.imm != comp.imm))
        return 6;
    if((golden.literal_in_use) && (golden.literal != comp.literal))
        return 7;
    return 0;
}

int interpret_vector(struct Decoded_VECTOR &vector_struct){
    VlWide<7> val = dut->vector_inst_out;   //207 bits, or 6 * 32 bits + 15 bits, with 17 MSB empty

    vector_struct.ddp8.sel7 = (val[0] & 0b111);
    val[0] = val[0] >> 3;
    vector_struct.ddp8.sel6 = (val[0] & 0b111);
    val[0] = val[0] >> 3;
    vector_struct.ddp8.sel5 = (val[0] & 0b111);
    val[0] = val[0] >> 3;
    vector_struct.ddp8.sel4 = (val[0] & 0b111);
    val[0] = val[0] >> 3;
    vector_struct.ddp8.sel3 = (val[0] & 0b111);
    val[0] = val[0] >> 3;
    vector_struct.ddp8.sel2 = (val[0] & 0b111);
    val[0] = val[0] >> 3;
    vector_struct.ddp8.sel1 = (val[0] & 0b111);
    val[0] = val[0] >> 3;
    vector_struct.ddp8.sel0 = (val[0] & 0b111);
    val[0] = val[0] >> 3;

    vector_struct.ddp16.row_mask = (val[0] & 0xF);
    val[0] = val[0] >> 4;
    vector_struct.ddp16.bank_mask = (val[0] & 0xF);
    vector_struct.ddp16.src1_abs = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.ddp16.src1_neg = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.ddp16.src0_abs = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.ddp16.src0_neg = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.ddp16.bc = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.ddp16.fi = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.ddp16.dpp_ctrl = (val[1] & 0x1FF);
    val[1] = val[1] >> 9;   //val[1] has 15 bits used, 17 bits left
    vector_struct.ddp16.src0 = (val[1] & 0xFF);
    vector_struct.ddp8.src0 = vector_struct.ddp16.src0;
    val[1] = val[1] >> 8;   //val[1] has 9 bits left

    vector_struct.sdwa.s1 = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.sdwa.src1_abs = (val[1] & 0x1);
    val[1] = val[1] >> 1;    
    vector_struct.sdwa.src1_negs = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.sdwa.src1_sext = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.sdwa.src1_sel = (val[1] & 0b111);
    val[1] = val[1] >>3;
    vector_struct.sdwa.s0 = (val[1] & 0x1);
    val[1] = val[1] >> 1;
    vector_struct.sdwa.src0_abs = (val[1] & 0x1);
    vector_struct.sdwa.src0_negs = (val[2] & 0x1);
    val[2] = val[2] >> 1;
    vector_struct.sdwa.src0_sext = (val[2] & 0x1);
    val[2] = val[2] >> 1;
    vector_struct.sdwa.src0_sel = (val[2] & 0b111);
    val[2] = val[2] >> 3;
    vector_struct.sdwa.omod = (val[2] & 0b11);
    val[2] = val[2] >> 2;
    vector_struct.sdwa.cimp = (val[2] & 0x1);
    val[2] = val[2] >> 1;
    vector_struct.sdwa.dst_u = (val[2] & 0b11);
    val[2] = val[2] >> 2;
    vector_struct.sdwa.dst_sel = (val[2] & 0b111);
    val[2] = val[2] >> 3;
    vector_struct.sdwa.sd = (val[2] & 0x1);
    val[2] = val[2] >> 1;
    vector_struct.sdwa.sdst = (val[2] & 0x7F);
    val[2] = val[2] >> 7;
    vector_struct.sdwa.src0 = (val[2] & 0xFF);
    val[2] = val[2] >> 8;   //val[2] has 29 bits used, 3 bits left

    vector_struct.literal = ((val[3] << 3) & 0xFFFFFFFF) + (val[2] & 0b111);
    val[3] = val[3] >> 29;
    vector_struct.omod = (val[3] & 0b11);
    val[3] = val[3] >> 2;
    vector_struct.neg_hi = ((val[4] & 0b11) << 1) + (val[3] & 0b1);
    val[4] = val[4] >> 2;
    vector_struct.neg = (val[4] & 0b111);
    val[4] = val[4] >> 3;
    vector_struct.abs = (val[4] & 0b111);
    val[4] = val[4] >> 3;
    vector_struct.op_sel_hi = (val[4] & 0b111);
    val[4] = val[4] >> 3;
    vector_struct.op_sel = (val[4] & 0xF);
    val[4] = val[4] >> 4;
    vector_struct.cimp = (val[4] & 0b1);
    val[4] = val[4] >> 1;
    vector_struct.attr_chan = (val[4] & 0b11);
    val[4] = val[4] >> 2;   //val[4] has 18 bits used, 14 bits left
    vector_struct.attr = (val[4] & 0x3F);
    val[4] = val[4] >> 6;
    vector_struct.sdest = (val[4] & 0x7F);
    val[4] = val[4] >> 7;
    vector_struct.vdest = ((val[5] & 0x7F) << 1) + (val[4] & 0b1);
    val[5] = val[5] >> 7;
    vector_struct.src2 = (val[5] & 0x1FF);
    val[5] = val[5] >> 9;
    vector_struct.src1 = (val[5] & 0x1FF);
    vector_struct.vsrc1 = vector_struct.src1;
    val[5] = val[5] >> 9;
    vector_struct.src0 = ((val[6] & 0b11) << 7) + (val[5] & 0x7F);
    val[6] = val[6] >> 2;
    vector_struct.opcode = (val[6] & 0x3FF);
    val[6] = val[6] >> 10;

    uint8_t format = (val[6] & 0x7);
    switch (format){
        case 0:
            vector_struct.type = VOP2;
            break;
        case 1:
            vector_struct.type = VOP1;
            break;
        case 2:
            vector_struct.type = VOPC;
            break;
        case 3:
            vector_struct.type = VINTRP;
            break;
        case 4:
            vector_struct.type = VOP3A;
            break;
        case 5:
            vector_struct.type = VOP3P;
            break;
        
        default:
            return 1;
    }
    return 0;
}


int compare_vector(struct Decoded_VECTOR &golden, struct Decoded_VECTOR &comp){
    if(golden.opcode != comp.opcode){
        return 1;
    }

    if(golden.sdwa.sdwa_in_use || golden.sdwa.sdwab_in_use || golden.ddp8.ddp8_in_use || golden.ddp16.ddp16_in_use)
        return -3;

    // Later execute phase is in charge of this, so it is not the responsibility of decode phase
    // if(golden.sdwa.sdwa_in_use != comp.sdwa.sdwa_in_use)
    //     return 2;
    // if(golden.sdwa.sdwab_in_use != comp.sdwa.sdwab_in_use)
    //     return 3;
    // if(golden.ddp8.ddp8_in_use != comp.ddp8.ddp8_in_use)
    //     return 4;
    // if(golden.ddp16.ddp16_in_use != comp.ddp16.ddp16_in_use)
    //     return 5;
    if((golden.literal_in_use) && (golden.literal != comp.literal))
        return 6;

    switch (golden.type){
        case VOP1:
            if(golden.type != comp.type)
                return 7;
            if(golden.vdest != comp.vdest)
                return 8;
            if(golden.src0 != comp.src0)
                return 8;
            break;
        case VOP2:
            if(golden.type != comp.type)
                return 9;
            if(golden.vdest != comp.vdest)
                return 10;
            if(golden.src0 != comp.src0)
                return 11;
            if(golden.vsrc1 != comp.vsrc1)
                return 12;
            break;
        case VOPC:
            if(golden.type != comp.type)
                return 9;
            if(golden.vsrc1 != comp.vsrc1)
                return 13;
            if(golden.src0 != comp.src0)
                return 14;
            break;
        case VINTRP:
            return -2;
            break;
        case VOP3A:
            if(comp.type != VOP3A && comp.type !=VOP3B)
                return 15;
            if(golden.cimp != comp.cimp)
                return 16;
            if(golden.op_sel != comp.op_sel)
                return 17;
            if(golden.abs != comp.abs)
                return 18;
            if(golden.vdest != comp.vdest)
                return 19;
            if(golden.neg != comp.neg)
                return 20;
            if(golden.omod != comp.omod)
                return 21;
            if(golden.src2 != comp.src2)
                return 22;
            if(golden.src1 != comp.src1)
                return 23;
            if(golden.src0 != comp.src0)
                return 24;
            break;
        case VOP3B:
            if(comp.type != VOP3A && comp.type !=VOP3B)
                return 25;
            if(golden.cimp != comp.cimp)
                return 26;
            if(golden.sdest != comp.sdest)
                return 27;
            if(golden.vdest != comp.vdest)
                return 28;
            if(golden.neg != comp.neg)
                return 29;
            if(golden.omod != comp.omod)
                return 30;
            if(golden.src2 != comp.src2)
                return 31;
            if(golden.src1 != comp.src1)
                return 32;
            if(golden.src0 != comp.src0)
                return 33;
            break;
        case VOP3P:
            if(golden.type != comp.type)
                return 34;
            if(golden.cimp != comp.cimp)
                return 35;
            if(golden.op_sel != comp.op_sel)
                return 36;
            if(golden.op_sel_hi != comp.op_sel_hi)
                return 37;
            if(golden.neg_hi != comp.neg_hi)
                return 38;
            if(golden.vdest != comp.vdest)
                return 39;
            if(golden.neg != comp.neg)
                return 40;
            if(golden.src2 != comp.src2)
                return 41;
            if(golden.src1 != comp.src1)
                return 42;
            if(golden.src0 != comp.src0)
                return 43;
            break;
        
        default:
            return -1;
    }
    return 0;
}

int interpret_flat(struct Decoded_FLAT &flat_struct){
    uint64_t val = dut->flat_inst_out;   //56 bits

    flat_struct.vdest = (val & 0xFF);
    val = val >> 8;
    flat_struct.saddr = (val & 0x7F);
    val = val >> 7;
    flat_struct.data = (val & 0xFF);
    val = val >> 8;
    flat_struct.addr = (val & 0xFF);
    val = val >> 8;
    flat_struct.opcode = (val & 0x7F);
    val = val >> 7;
    flat_struct.slc = (val & 0b1);
    val = val >> 1;
    flat_struct.glc = (val & 0b1);
    val = val >> 1;
    flat_struct.seg = (val & 0b11);
    val = val >> 2;
    flat_struct.lds = (val & 0b1);
    val = val >> 1;
    flat_struct.dlc = (val & 0b1);
    val = val >> 1;
    flat_struct.offset = (val & 0xFFF);
    return 0;
}

int compare_flat(struct Decoded_FLAT &golden, struct Decoded_FLAT &comp){
    if(golden.opcode != comp.opcode)
        return 1;
    if(golden.slc != comp.slc)
        return 2;
    if(golden.glc != comp.glc)
        return 3;
    if(golden.seg != comp.seg)
        return 4;
    if(golden.lds != comp.lds)
        return 5;
    if(golden.dlc != comp.dlc)
        return 6;
    if(golden.offset != comp.offset)
        return 7;
    if(golden.vdest != comp.vdest)
        return 8;
    if(golden.saddr != comp.saddr)
        return 9;
    if(golden.data != comp.data)
        return 10;
    if(golden.addr != comp.addr)
        return 11;
    return 0;
}

int interpret_ds(struct Decoded_DS &ds_struct){
    uint64_t val = dut->ds_inst_out;   //57 bits

    ds_struct.vdest = (val & 0xFF);
    val = val >> 8;
    ds_struct.data1 = (val & 0xFF);
    val = val >> 8;
    ds_struct.data0 = (val & 0xFF);
    val = val >> 8;
    ds_struct.addr = (val & 0xFF);
    val = val >> 8;
    ds_struct.opcode = (val & 0xFF);
    val = val >> 8;
    ds_struct.gds = (val & 0b1);
    val = val >> 1;
    ds_struct.offset1 = (val & 0xFF);
    val = val >> 8;
    ds_struct.offset0 = (val & 0xFF);
    val = val >> 8;

    return 0;
}

int compare_ds(struct Decoded_DS &golden, struct Decoded_DS &comp){
    if(golden.opcode != comp.opcode)
        return 1;
    if(golden.gds != comp.gds)
        return 2;
    if(golden.offset1 != comp.offset1)
        return 3;
    if(golden.offset0 != comp.offset0)
        return 4;
    if(golden.vdest != comp.vdest)
        return 5;
    if(golden.data1 != comp.data1)
        return 6;
    if(golden.data0 != comp.data0)
        return 7;
    if(golden.addr != comp.addr)
        return 8;
    return 0;
}

int interpret_export(struct Decoded_EXPORT &export_struct){
    uint64_t val = dut->export_inst_out;   //45 bits

    export_struct.vsrc3 = (val & 0xFF);
    val = val >> 8;
    export_struct.vsrc2 = (val & 0xFF);
    val = val >> 8;
    export_struct.vsrc1 = (val & 0xFF);
    val = val >> 8;
    export_struct.vsrc0 = (val & 0xFF);
    val = val >> 8;
    export_struct.vm = (val & 0b1);
    val = val >> 1;
    export_struct.done = (val & 0b1);
    val = val >> 1;
    export_struct.compr = (val & 0b1);
    val = val >> 1;
    export_struct.target = (val & 0x3F);
    val = val >> 1;
    export_struct.en = (val & 0b111);

    return 0;
}

int compare_export(struct Decoded_EXPORT &golden, struct Decoded_EXPORT &comp){
    if(golden.en != comp.en)
        return 1;
    if(golden.target != comp.target)
        return 2;
    if(golden.compr != comp.compr)
        return 3;
    if(golden.done != comp.done)
        return 4;
    if(golden.vm != comp.vm)
        return 5;
    if(golden.vsrc0 != comp.vsrc0)
        return 6;
    if(golden.vsrc1 != comp.vsrc1)
        return 7;
    if(golden.vsrc2 != comp.vsrc2)
        return 8;
    if(golden.vsrc3 != comp.vsrc3)
        return 9;
    return 0;
}

// int interpret_mimg(struct Decoded_MIMG &mimg_struct){
//     VlWide<3> val = dut->mimg_inst_out >> 1; //148 bits

//     return 0;
// }

// int compare_mimg(struct Decoded_MIMG &golden, struct Decoded_MIMG &comp){
//     if(golden.type != comp.type){
//         return 1;
//     }
//     if(golden.opcode != comp.opcode)
//         return 2;

//     return 0;
// }

int interpret_mbuf(struct Decoded_MBUF &mbuf_struct){
    uint64_t val = dut->mbuf_inst_out; //64 bits

    uint8_t format = (val >> 63) & 0b1;
    switch (format){
        case 0:
            mbuf_struct.type = MTBUF;
            mbuf_struct.instr.mtbuf_instr.soffset = (val & 0xFF);
            val = val >> 8;
            mbuf_struct.instr.mtbuf_instr.slc = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mtbuf_instr.tfe = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mtbuf_instr.srsrc = (val & 0b11111);
            val = val >> 5;
            mbuf_struct.instr.mtbuf_instr.vdata = (val & 0xFF);
            val = val >> 8;
            mbuf_struct.instr.mtbuf_instr.vaddr = (val & 0xFF);
            val = val >> 8;
            mbuf_struct.instr.mtbuf_instr.format = (val & 0x7F);
            val = val >> 7;
            mbuf_struct.instr.mtbuf_instr.opcode = (val & 0xF);     // extract 4 bits, shift 9
            val = val >> 9;
            mbuf_struct.instr.mtbuf_instr.dlc = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mtbuf_instr.glc = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mtbuf_instr.idxen = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mtbuf_instr.offen = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mtbuf_instr.offset = (val & 0xFFF);
            break;
        case 1:
            mbuf_struct.type = MUBUF;
            mbuf_struct.instr.mubuf_instr.soffset = (val & 0xFF);
            val = val >> 8;
            mbuf_struct.instr.mubuf_instr.slc = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mubuf_instr.tfe = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mubuf_instr.srsrc = (val & 0b11111);
            val = val >> 5;
            mbuf_struct.instr.mubuf_instr.vdata = (val & 0xFF);
            val = val >> 8;
            mbuf_struct.instr.mubuf_instr.vaddr = (val & 0xFF);
            val = val >> 8;
            val = val >> 7;     // format, used by MTBUF
            mbuf_struct.instr.mubuf_instr.opcode = (val & 0xFF);
            val = val >> 8;
            mbuf_struct.instr.mubuf_instr.lds = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mubuf_instr.dlc = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mubuf_instr.glc = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mubuf_instr.idxen = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mubuf_instr.offen = (val & 0b1);
            val = val >> 1;
            mbuf_struct.instr.mubuf_instr.offset = (val & 0xFFF);
            break;
        
        default:
            return 1;
    }

    return 0;
}

int compare_mbuf(struct Decoded_MBUF &golden, struct Decoded_MBUF &comp){
    if(golden.type != comp.type){
        return 1;
    }
    switch (golden.type){
        case MTBUF:
            if (golden.instr.mtbuf_instr.format != comp.instr.mtbuf_instr.format)
                return 2;
            if (golden.instr.mtbuf_instr.opcode != comp.instr.mtbuf_instr.opcode)
                return 3;
            if (golden.instr.mtbuf_instr.dlc != comp.instr.mtbuf_instr.dlc)
                return 4;
            if (golden.instr.mtbuf_instr.glc != comp.instr.mtbuf_instr.glc)
                return 5;
            if (golden.instr.mtbuf_instr.idxen != comp.instr.mtbuf_instr.idxen)
                return 6;
            if (golden.instr.mtbuf_instr.offen != comp.instr.mtbuf_instr.offen)
                return 7;
            if (golden.instr.mtbuf_instr.offset != comp.instr.mtbuf_instr.offset)
                return 8;
            if (golden.instr.mtbuf_instr.soffset != comp.instr.mtbuf_instr.soffset)
                return 9;
            if (golden.instr.mtbuf_instr.tfe != comp.instr.mtbuf_instr.tfe)
                return 10;
            if (golden.instr.mtbuf_instr.slc != comp.instr.mtbuf_instr.slc)
                return 11;
            // if (golden.instr.mtbuf_instr.opm != comp.instr.mtbuf_instr.opm)
            //     return 12;
            if (golden.instr.mtbuf_instr.srsrc != comp.instr.mtbuf_instr.srsrc)
                return 13;
            if (golden.instr.mtbuf_instr.vdata != comp.instr.mtbuf_instr.vdata)
                return 14;
            if (golden.instr.mtbuf_instr.vaddr != comp.instr.mtbuf_instr.vaddr)
                return 15;
            break;

        case MUBUF:
            // if (golden.instr.mubuf_instr.opm != comp.instr.mubuf_instr.opm)
            //     return 16;
            if (golden.instr.mubuf_instr.opcode != comp.instr.mubuf_instr.opcode)
                return 17;
            if (golden.instr.mubuf_instr.lds != comp.instr.mubuf_instr.lds)
                return 18;
            if (golden.instr.mubuf_instr.dlc != comp.instr.mubuf_instr.dlc)
                return 19;
            if (golden.instr.mubuf_instr.glc != comp.instr.mubuf_instr.glc)
                return 20;
            if (golden.instr.mubuf_instr.idxen != comp.instr.mubuf_instr.idxen)
                return 21;
            if (golden.instr.mubuf_instr.offen != comp.instr.mubuf_instr.offen)
                return 22;
            if (golden.instr.mubuf_instr.offset != comp.instr.mubuf_instr.offset)
                return 23;
            if (golden.instr.mubuf_instr.soffset != comp.instr.mubuf_instr.soffset)
                return 24;
            if (golden.instr.mubuf_instr.tfe != comp.instr.mubuf_instr.tfe)
                return 25;
            if (golden.instr.mubuf_instr.slc != comp.instr.mubuf_instr.slc)
                return 26;
            if (golden.instr.mubuf_instr.srsrc != comp.instr.mubuf_instr.srsrc)
                return 27;
            if (golden.instr.mubuf_instr.vdata != comp.instr.mubuf_instr.vdata)
                return 28;
            if (golden.instr.mubuf_instr.vaddr != comp.instr.mubuf_instr.vaddr)
                return 29;
            break;
        
        default:
            break;
    }
    return 0;
}


int interpret_smem(struct Decoded_SMEM &smem_struct){
    uint64_t val = dut->smem_inst_out;   //51 bits

    smem_struct.soffset = (val & 0x7F);
    val = val >> 7;
    smem_struct.offset = (val & 0x1FFFFF);
    val = val >> 21;
    smem_struct.opcode = (val & 0xFF);
    val = val >> 8;
    smem_struct.glc = (val & 0b1);
    val = val >> 1;
    smem_struct.dlc = (val & 0b1);
    val = val >> 1;
    smem_struct.sdata = (val & 0x7F);
    val = val >> 7;
    smem_struct.sbase = (val & 0x3F);

    return 0;
}

int compare_smem(struct Decoded_SMEM &golden, struct Decoded_SMEM &comp){
    if (golden.opcode != comp.opcode)
        return 1;
    if (golden.glc != comp.glc)
        return 2;
    if (golden.dlc != comp.dlc)
        return 3;
    if (golden.sdata != comp.sdata)
        return 4;
    if (golden.sbase != comp.sbase)
        return 5;
    if (golden.soffset != comp.soffset)
        return 6;
    if (golden.offset != comp.offset)
        return 7;
    return 0;
}


int check_flag(Instruction_Type itype){
    // Flag order: vector, scalar, flat, ds, export, mimg, mbuf, smem
    uint8_t all_flag;
    
    switch (itype)
    {
        case SCALAR:
            all_flag = 0b01000000;
            break;

        case VECTOR:
            all_flag = 0b10000000;
            break;

        case FLAT:
            all_flag = 0b00100000;
            break;

        case DS:
            all_flag = 0b00010000;
            break;

        case EXPORT:
            all_flag = 0b00001000;
            break;

        case MIMG:
            all_flag = 0b00000100;
            break;

        case MBUF:
            all_flag = 0b00000010;
            break;

        case SMEM:
            all_flag = 0b00000001;
            break;
        
        default:
            return -1;
    }
    return !(dut->dec_ex1_all_flags == all_flag);
}

void debug_printout(const std::string in_line, bool is_64bit, Instruction_Type itype){
    std::cout << "---------------------" << std::endl << "Cycle: " << std::dec << sim_time << std::endl;
    std::cout << in_line << std::endl;
    if(is_64bit)
        std::cout << "64 bit sintruction, skipping cycle" << std::endl;

    std::cout << "Expected: " << convert_enum_string(itype) << std::endl;
    std::cout << "Got: " << convert_allflag_string(dut->dec_ex1_all_flags) << std::endl;
}


int main(int argc, char** argv, char** env) {
    dut = new Vsimd32_decode;

    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);     // limit waveform dumping to 5 levels under DUT
    m_trace->open("waveform.vcd");

    std::ifstream ilist("instruction_list.txt");
    if (!ilist.is_open()) {
        std::cerr << "Error opening the instruction list file!  Does it exist?";
        return 1;
    }
    std::string s;
    uint32_t instruction = 0;
    uint32_t following_32bits = 0;
    bool is_64bit_instr = false;
    Instruction_Type itype;
    Decoded_Instruction decoded_inst;
    Decoded_Instruction dut_inst;
    uint32_t passed_instr = 0;
    uint32_t failed_instr = 0;
    int cmp_reslt;
    // uint32_t vector_fails[44] = {0};

    dut->reset = 1;
    dut->inst = 0x0;
    dut->ex1_dec_ready = 1;
    nextCycle();

    dut->reset = 0;
    // dut->inst = 0x7E080280;
    while ((sim_time < MAX_SIM_TIME) && getline(ilist, s)) {

        if (parse_string_from_file(s, instruction, following_32bits, is_64bit_instr)) {
            std::cout << "Line read from file: " << s << std::endl;
            std::cerr << "Error Parsing Instruction " << std::endl;
        }
        if(decode_instructions(instruction, following_32bits, is_64bit_instr, itype, decoded_inst)){
            std::cerr << "Error Decoding Instruction " << std::endl;
        }


        dut->inst = instruction;
        nextCycle();
        if(is_64bit_instr){
            dut->inst = following_32bits;
            nextCycle();
        }
        
        if(check_flag(itype)){
            debug_printout(s, is_64bit_instr, itype);
            std::cout << "Fail" << std::endl;
            failed_instr++;
        } else { 
            #if (defined(VERBOSE) && VERBOSE >= 2)
                debug_printout(s, is_64bit_instr, itype);
                std::cout << "Pass" << std::endl;
            #endif
            switch (itype){
                case SCALAR:
                    interpret_scalar(dut_inst.scalar_instr);
                    cmp_reslt = compare_scalar(decoded_inst.scalar_instr, dut_inst.scalar_instr);
                    if(cmp_reslt){
                        debug_printout(s, is_64bit_instr, itype);
                        std::cout << "Comparison of decoded values FAIL: " << cmp_reslt << std::endl;
                        #if (defined(VERBOSE) && VERBOSE >= 1)
                            print_decoded_instructions(decoded_inst.scalar_instr);
                            print_decoded_instructions(dut_inst.scalar_instr);
                        #endif
                        failed_instr++;
                    } else {
                        #if (defined(VERBOSE) && VERBOSE >= 2)
                            print_decoded_instructions(decoded_inst.scalar_instr);
                            print_decoded_instructions(dut_inst.scalar_instr);
                        #endif
                        passed_instr++;
                    }
                    break;

                case VECTOR:
                    interpret_vector(dut_inst.vector_instr);
                    cmp_reslt = compare_vector(decoded_inst.vector_instr, dut_inst.vector_instr);
                    if(cmp_reslt){
                        debug_printout(s, is_64bit_instr, itype);
                        std::cout << "Comparison of decoded values FAIL: " << std::dec << cmp_reslt << std::endl;
                        #if (defined(VERBOSE) && VERBOSE >= 1)
                            print_decoded_instructions(decoded_inst.vector_instr);
                            print_decoded_instructions(dut_inst.vector_instr);
                        #endif
                        failed_instr++;
                        // if(cmp_reslt>0)
                        //     vector_fails[cmp_reslt]++;
                    } else {
                        #if (defined(VERBOSE) && VERBOSE >= 2)
                            print_decoded_instructions(decoded_inst.vector_instr);
                            print_decoded_instructions(dut_inst.vector_instr);
                        #endif
                        passed_instr++;
                    }
                    break;
                
                case FLAT:
                    interpret_flat(dut_inst.flat_instr);
                    cmp_reslt = compare_flat(decoded_inst.flat_instr, dut_inst.flat_instr);
                    if(cmp_reslt){
                        debug_printout(s, is_64bit_instr, itype);
                        std::cout << "Comparison of decoded values FAIL: " << std::dec << cmp_reslt << std::endl;
                        // #if (defined(VERBOSE) && VERBOSE >= 1)
                        //     print_decoded_instructions(decoded_inst.vector_instr);
                        //     print_decoded_instructions(dut_inst.vector_instr);
                        // #endif
                        failed_instr++;
                    } else {
                        // #if (defined(VERBOSE) && VERBOSE >= 2)
                        //     print_decoded_instructions(decoded_inst.scalar_instr);
                        //     print_decoded_instructions(dut_inst.scalar_instr);
                        // #endif
                        passed_instr++;
                    }
                    break;
                
                case DS:
                    interpret_ds(dut_inst.ds_instr);
                    cmp_reslt = compare_ds(decoded_inst.ds_instr, dut_inst.ds_instr);
                    if(cmp_reslt){
                        debug_printout(s, is_64bit_instr, itype);
                        std::cout << "Comparison of decoded values FAIL: " << std::dec << cmp_reslt << std::endl;
                        // #if (defined(VERBOSE) && VERBOSE >= 1)
                        //     print_decoded_instructions(decoded_inst.vector_instr);
                        //     print_decoded_instructions(dut_inst.vector_instr);
                        // #endif
                        failed_instr++;
                    } else {
                        // #if (defined(VERBOSE) && VERBOSE >= 2)
                        //     print_decoded_instructions(decoded_inst.vector_instr);
                        //     print_decoded_instructions(dut_inst.vector_instr);
                        // #endif
                        passed_instr++;
                    }
                    break;
                
                case EXPORT:
                    interpret_export(dut_inst.export_instr);
                    cmp_reslt = compare_export(decoded_inst.export_instr, dut_inst.export_instr);
                    if(cmp_reslt){
                        debug_printout(s, is_64bit_instr, itype);
                        std::cout << "Comparison of decoded values FAIL: " << std::dec << cmp_reslt << std::endl;
                        // #if (defined(VERBOSE) && VERBOSE >= 1)
                        //     print_decoded_instructions(decoded_inst.vector_instr);
                        //     print_decoded_instructions(dut_inst.vector_instr);
                        // #endif
                        failed_instr++;
                    } else {
                        // #if (defined(VERBOSE) && VERBOSE >= 2)
                        //     print_decoded_instructions(decoded_inst.vector_instr);
                        //     print_decoded_instructions(dut_inst.vector_instr);
                        // #endif
                        passed_instr++;
                    }
                    break;
                
                // case MIMG:
                //     interpret_mimg(dut_inst.mimg_instr);
                //     cmp_reslt = compare_mimg(decoded_inst.mimg_instr, dut_inst.mimg_instr);
                //     if(cmp_reslt){
                //         debug_printout(s, is_64bit_instr, itype);
                //         std::cout << "Comparison of decoded values FAIL: " << std::dec << cmp_reslt << std::endl;
                //         #if (defined(VERBOSE) && VERBOSE >= 1)
                //             print_decoded_instructions(decoded_inst.vector_instr);
                //             print_decoded_instructions(dut_inst.vector_instr);
                //         #endif
                //         failed_instr++;
                //     } else {
                //         passed_instr++;
                //     }
                //     break;
                
                case MBUF:
                    interpret_mbuf(dut_inst.mbuf_instr);
                    cmp_reslt = compare_mbuf(decoded_inst.mbuf_instr, dut_inst.mbuf_instr);
                    if(cmp_reslt){
                        debug_printout(s, is_64bit_instr, itype);
                        std::cout << "Comparison of decoded values FAIL: " << std::dec << cmp_reslt << std::endl;
                        #if (defined(VERBOSE) && VERBOSE >= 1)
                            print_decoded_instructions(decoded_inst.mbuf_instr);
                            print_decoded_instructions(dut_inst.mbuf_instr);
                        #endif
                        failed_instr++;
                    } else {
                        #if (defined(VERBOSE) && VERBOSE >= 2)
                            print_decoded_instructions(decoded_inst.mbuf_instr);
                            print_decoded_instructions(dut_inst.mbuf_instr);
                        #endif
                        passed_instr++;
                    }
                    break;
                
                case SMEM:
                    interpret_smem(dut_inst.smem_instr);
                    cmp_reslt = compare_smem(decoded_inst.smem_instr, dut_inst.smem_instr);
                    if(cmp_reslt){
                        debug_printout(s, is_64bit_instr, itype);
                        std::cout << "Comparison of decoded values FAIL: " << std::dec << cmp_reslt << std::endl;
                        #if (defined(VERBOSE) && VERBOSE >= 1)
                            print_decoded_instructions(decoded_inst.vector_instr);
                            print_decoded_instructions(dut_inst.vector_instr);
                        #endif
                        failed_instr++;
                    } else {
                        passed_instr++;
                    }
                    break;
                
                default:
                    // std::cout << "Unreachable code" << std::endl;
                    passed_instr++;
                    break;
            }
        }
    }

    std::cout << "Total Instructions tested: " << std::dec << (passed_instr+failed_instr) << std::endl;
    std::cout << "Total Instructions passed: " << std::dec << passed_instr << " (" << (passed_instr*100.0/(passed_instr+failed_instr)) << "%)" << std::endl;
    std::cout << "Total Instructions failed: " << std::dec << failed_instr << " (" << (failed_instr*100.0/(passed_instr+failed_instr)) << "%)" << std::endl;

    // for(int i=0; i<44; i++){
    //     if(vector_fails[i] != 0)
    //         std::cout << "error: " << std::dec << i << ", num: " << vector_fails[i] << std::endl;
    // }

    ilist.close();
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
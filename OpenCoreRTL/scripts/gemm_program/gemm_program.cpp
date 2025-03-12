#include <stdlib.h>
#include <iostream>
#include <fstream> 
#include <bitset>
#include <limits>
#include <cstdint>
#include <iomanip>



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

void print_decoded_instructions(struct Decoded_FLAT &out){
    std::cout << "-----------------------------------" << std::endl;
    std::cout << "opcode: " << out.opcode << std::endl;
    std::cout << "slc: " << out.slc << std::endl;
    std::cout << "glc: " << out.glc << std::endl;
    std::cout << "seg: " << out.seg << std::endl;
    std::cout << "lds: " << out.lds << std::endl;
    std::cout << "dlc: " << out.dlc << std::endl;
    std::cout << "offset: " << out.offset << std::endl;
    std::cout << "vdest: " << out.vdest << std::endl;
    std::cout << "saddr: " << out.saddr << std::endl;
    std::cout << "data: " << out.data << std::endl;
    std::cout << "addr: " << out.addr << std::endl;
    std::cout << "-----------------------------------" << std::endl;
}

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



// stoi but for unsigned
unsigned stou(std::string const & str, size_t * idx = 0, int base = 10) {
    unsigned long result = std::stoul(str, idx, base);
    if (result > std::numeric_limits<unsigned>::max()) {
        throw std::out_of_range("stou");
    }
    return result;
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


// AI generated based off decode_instructions function
int encode_instructions(Instruction_Type instruction_type, Decoded_Instruction &decoded_instr, uint32_t &instruction, uint32_t &instruction2, bool &instr2_used) {
    instruction = 0;
    instruction2 = 0;
    instr2_used = false;

    switch(instruction_type) {
        case VECTOR: {
            // Handle vector instructions
            switch(decoded_instr.vector_instr.type) {
                case VOP1: {
                    // Set instruction bits for VOP1 (0111111)
                    instruction = 0x7E000000;
                    instruction |= (decoded_instr.vector_instr.vdest & 0xFF) << 17;
                    instruction |= (decoded_instr.vector_instr.opcode & 0xFF) << 9;
                    instruction |= (decoded_instr.vector_instr.src0 & 0x1FF);
                    
                    if (decoded_instr.vector_instr.sdwa.sdwa_in_use) {
                        instruction |= 249; // Set src0 to 249 to indicate SDWA is in use
                    } else if (decoded_instr.vector_instr.literal_in_use) {
                        instruction2 = decoded_instr.vector_instr.literal;
                        instr2_used = true;
                    }
                    break;
                }

                case VOPC: {
                    // Set instruction bits for VOPC (0111110)
                    instruction = 0x7C000000;
                    instruction |= (decoded_instr.vector_instr.opcode & 0xFF) << 17;
                    instruction |= (decoded_instr.vector_instr.vsrc1 & 0xFF) << 9;
                    instruction |= (decoded_instr.vector_instr.src0 & 0x1FF);
                    
                    if (decoded_instr.vector_instr.sdwa.sdwab_in_use) {
                        instruction |= 249; // Set src0 to 249 to indicate SDWA is in use
                    } else if (decoded_instr.vector_instr.literal_in_use) {
                        instruction2 = decoded_instr.vector_instr.literal;
                        instr2_used = true;
                    }
                    break;
                }

                case VOP2: {
                    // Set instruction bits for VOP2
                    instruction = (decoded_instr.vector_instr.opcode & 0x3F) << 25;
                    instruction |= (decoded_instr.vector_instr.vdest & 0xFF) << 17;
                    instruction |= (decoded_instr.vector_instr.vsrc1 & 0xFF) << 9;
                    instruction |= (decoded_instr.vector_instr.src0 & 0x1FF);
                    
                    if (decoded_instr.vector_instr.sdwa.sdwa_in_use) {
                        instruction |= 249; // Set src0 to 249 to indicate SDWA is in use
                    } else if (decoded_instr.vector_instr.literal_in_use) {
                        instruction2 = decoded_instr.vector_instr.literal;
                        instr2_used = true;
                    }
                    break;
                }

                case VOP3A:
                case VOP3B: {
                    // Set instruction bits for VOP3A/VOP3B (110101)
                    instruction = 0xD4000000;
                    instruction |= (decoded_instr.vector_instr.opcode & 0x3FF) << 16;
                    instruction |= (decoded_instr.vector_instr.cimp & 0x1) << 15;
                    instruction |= (decoded_instr.vector_instr.op_sel & 0xF) << 11;
                    instruction |= (decoded_instr.vector_instr.abs & 0x7) << 8;
                    
                    if (decoded_instr.vector_instr.type == VOP3B) {
                        instruction |= (decoded_instr.vector_instr.sdest & 0x7F) << 8;
                    }
                    
                    instruction |= (decoded_instr.vector_instr.vdest & 0xFF);
                    
                    // Second instruction word
                    instruction2 = (decoded_instr.vector_instr.neg & 0x7) << 29;
                    instruction2 |= (decoded_instr.vector_instr.omod & 0x3) << 27;
                    instruction2 |= (decoded_instr.vector_instr.src2 & 0x1FF) << 18;
                    instruction2 |= (decoded_instr.vector_instr.src1 & 0x1FF) << 9;
                    instruction2 |= (decoded_instr.vector_instr.src0 & 0x1FF);
                    instr2_used = true;
                    break;
                }

                case VOP3P: {
                    // Set instruction bits for VOP3P (110011)
                    instruction = 0xCC000000;
                    instruction |= (decoded_instr.vector_instr.opcode & 0x7F) << 16;
                    instruction |= (decoded_instr.vector_instr.cimp & 0x1) << 15;
                    
                    // Split op_sel_hi across both instruction words
                    uint32_t op_sel_hi_part1 = (decoded_instr.vector_instr.op_sel_hi & 0x1) << 14;
                    uint32_t op_sel_hi_part2 = ((decoded_instr.vector_instr.op_sel_hi >> 1) & 0x3) << 27; // For instruction2
                    
                    instruction |= op_sel_hi_part1;
                    instruction |= (decoded_instr.vector_instr.op_sel & 0x7) << 11;
                    instruction |= (decoded_instr.vector_instr.neg_hi & 0x7) << 8;
                    instruction |= (decoded_instr.vector_instr.vdest & 0xFF);
                    
                    // Second instruction word
                    instruction2 = (decoded_instr.vector_instr.neg & 0x7) << 29;
                    instruction2 |= op_sel_hi_part2;
                    instruction2 |= (decoded_instr.vector_instr.src2 & 0x1FF) << 18;
                    instruction2 |= (decoded_instr.vector_instr.src1 & 0x1FF) << 9;
                    instruction2 |= (decoded_instr.vector_instr.src0 & 0x1FF);
                    instr2_used = true;
                    break;
                }
                
                default:
                    return 1; // Unknown vector instruction type
            }
            
            // Handle DDP8/DDP16 encoding
            if (decoded_instr.vector_instr.ddp8.ddp8_in_use) {
                instruction &= ~0x1FF; // Clear src0 field
                instruction |= 233; // Set src0 to 233 to indicate DDP8 is in use
            } else if (decoded_instr.vector_instr.ddp16.ddp16_in_use) {
                instruction &= ~0x1FF; // Clear src0 field
                instruction |= 234; // Set src0 to 234 to indicate DDP16 is in use
            }
            
            break;
        }

        case SCALAR: {
            // Handle scalar instructions
            switch(decoded_instr.scalar_instr.type) {
                case SOPP: {
                    // Set instruction bits for SOPP (101111111)
                    instruction = 0xBF800000;
                    instruction |= (decoded_instr.scalar_instr.opcode & 0x7F) << 16;
                    instruction |= (decoded_instr.scalar_instr.imm & 0xFFFF);
                    
                    if (decoded_instr.scalar_instr.literal_in_use) {
                        instruction2 = decoded_instr.scalar_instr.literal;
                        instr2_used = true;
                    }
                    break;
                }

                case SOPC: {
                    // Set instruction bits for SOPC (101111110)
                    instruction = 0xBF000000;
                    instruction |= (decoded_instr.scalar_instr.opcode & 0x7F) << 16;
                    instruction |= (decoded_instr.scalar_instr.src1 & 0xFF) << 8;
                    instruction |= (decoded_instr.scalar_instr.src0 & 0xFF);
                    
                    if (decoded_instr.scalar_instr.literal_in_use) {
                        instruction2 = decoded_instr.scalar_instr.literal;
                        instr2_used = true;
                    }
                    break;
                }

                case SOP1: {
                    // Set instruction bits for SOP1 (101111101)
                    instruction = 0xBE800000;
                    instruction |= (decoded_instr.scalar_instr.dest & 0x7F) << 16;
                    instruction |= (decoded_instr.scalar_instr.opcode & 0xFF) << 8;
                    instruction |= (decoded_instr.scalar_instr.src0 & 0xFF);
                    
                    if (decoded_instr.scalar_instr.literal_in_use) {
                        instruction2 = decoded_instr.scalar_instr.literal;
                        instr2_used = true;
                    }
                    break;
                }

                case SOPK: {
                    // Set instruction bits for SOPK (1011)
                    instruction = 0xB0000000;
                    instruction |= (decoded_instr.scalar_instr.opcode & 0x1F) << 23;
                    instruction |= (decoded_instr.scalar_instr.dest & 0x7F) << 16;
                    instruction |= (decoded_instr.scalar_instr.imm & 0xFFFF);
                    
                    if (decoded_instr.scalar_instr.literal_in_use) {
                        instruction2 = decoded_instr.scalar_instr.literal;
                        instr2_used = true;
                    }
                    break;
                }

                case SOP2: {
                    // Set instruction bits for SOP2 (10)
                    instruction = 0x80000000;
                    instruction |= (decoded_instr.scalar_instr.opcode & 0x7F) << 23;
                    instruction |= (decoded_instr.scalar_instr.dest & 0x7F) << 16;
                    instruction |= (decoded_instr.scalar_instr.src1 & 0xFF) << 8;
                    instruction |= (decoded_instr.scalar_instr.src0 & 0xFF);
                    
                    if (decoded_instr.scalar_instr.literal_in_use) {
                        instruction2 = decoded_instr.scalar_instr.literal;
                        instr2_used = true;
                    }
                    break;
                }
                
                default:
                    return 1; // Unknown scalar instruction type
            }
            break;
        }

        case SMEM: {
            // Set instruction bits for SMEM (111101)
            instruction = 0xF4000000;
            instruction |= (decoded_instr.smem_instr.opcode & 0xFF) << 18;
            instruction |= (decoded_instr.smem_instr.glc & 0x1) << 16;
            instruction |= (decoded_instr.smem_instr.dlc & 0x1) << 14;
            instruction |= (decoded_instr.smem_instr.sdata & 0x7F) << 6;
            instruction |= (decoded_instr.smem_instr.sbase & 0x3F);
            
            // Second instruction word
            instruction2 = (decoded_instr.smem_instr.soffset & 0x7F) << 25;
            instruction2 |= (decoded_instr.smem_instr.offset & 0x1FFFFF);
            instr2_used = true;
            break;
        }

        case DS: {
            // Set instruction bits for DS/GDS (110110)
            instruction = 0xD8000000;
            instruction |= (decoded_instr.ds_instr.opcode & 0xFF) << 18;
            instruction |= (decoded_instr.ds_instr.gds & 0x1) << 17;
            instruction |= (decoded_instr.ds_instr.offset1 & 0xFF) << 8;
            instruction |= (decoded_instr.ds_instr.offset0 & 0xFF);
            
            // Second instruction word
            instruction2 = (decoded_instr.ds_instr.vdest & 0xFF) << 24;
            instruction2 |= (decoded_instr.ds_instr.data1 & 0xFF) << 16;
            instruction2 |= (decoded_instr.ds_instr.data0 & 0xFF) << 8;
            instruction2 |= (decoded_instr.ds_instr.addr & 0xFF);
            instr2_used = true;
            break;
        }

        case MBUF: {
            if (decoded_instr.mbuf_instr.type == MTBUF) {
                // Set instruction bits for MTBUF (111010)
                instruction = 0xE8000000;
                instruction |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.format & 0x7F) << 19;
                instruction |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.opcode & 0x7) << 16;
                instruction |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.dlc & 0x1) << 15;
                instruction |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.glc & 0x1) << 14;
                instruction |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.idxen & 0x1) << 13;
                instruction |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.offen & 0x1) << 12;
                instruction |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.offset & 0xFFF);
                
                // Second instruction word
                instruction2 = (decoded_instr.mbuf_instr.instr.mtbuf_instr.soffset & 0xFF) << 24;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.tfe & 0x1) << 23;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.slc & 0x1) << 22;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.opm & 0x1) << 21;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.srsrc & 0x1F) << 16;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.vdata & 0xFF) << 8;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mtbuf_instr.vaddr & 0xFF);
                instr2_used = true;
            } else if (decoded_instr.mbuf_instr.type == MUBUF) {
                // Set instruction bits for MUBUF (111000)
                instruction = 0xE0000000;
                instruction |= (decoded_instr.mbuf_instr.instr.mubuf_instr.opm & 0x1) << 25;
                instruction |= (decoded_instr.mbuf_instr.instr.mubuf_instr.opcode & 0x7F) << 18;
                instruction |= (decoded_instr.mbuf_instr.instr.mubuf_instr.lds & 0x1) << 16;
                instruction |= (decoded_instr.mbuf_instr.instr.mubuf_instr.dlc & 0x1) << 15;
                instruction |= (decoded_instr.mbuf_instr.instr.mubuf_instr.glc & 0x1) << 14;
                instruction |= (decoded_instr.mbuf_instr.instr.mubuf_instr.idxen & 0x1) << 13;
                instruction |= (decoded_instr.mbuf_instr.instr.mubuf_instr.offen & 0x1) << 12;
                instruction |= (decoded_instr.mbuf_instr.instr.mubuf_instr.offset & 0xFFF);
                
                // Second instruction word
                instruction2 = (decoded_instr.mbuf_instr.instr.mubuf_instr.soffset & 0xFF) << 24;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mubuf_instr.tfe & 0x1) << 23;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mubuf_instr.slc & 0x1) << 22;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mubuf_instr.srsrc & 0x1F) << 16;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mubuf_instr.vdata & 0xFF) << 8;
                instruction2 |= (decoded_instr.mbuf_instr.instr.mubuf_instr.vaddr & 0xFF);
                instr2_used = true;
            } else {
                return 1; // Unknown MBUF instruction type
            }
            break;
        }

        case MIMG: {
            // Set instruction bits for MIMG (111100)
            instruction = 0xF0000000;
            // MIMG details not fully specified in the original decoder, would need more info
            instr2_used = true;
            break;
        }

        case FLAT: {
            // Set instruction bits for FLAT (110111)
            instruction = 0xDC000000;
            instruction |= (decoded_instr.flat_instr.opcode & 0x7F) << 18;
            instruction |= (decoded_instr.flat_instr.slc & 0x1) << 17;
            instruction |= (decoded_instr.flat_instr.glc & 0x1) << 16;
            instruction |= (decoded_instr.flat_instr.seg & 0x3) << 14;
            instruction |= (decoded_instr.flat_instr.lds & 0x1) << 13;
            instruction |= (decoded_instr.flat_instr.dlc & 0x1) << 12;
            instruction |= (decoded_instr.flat_instr.offset & 0xFFF);
            
            // Second instruction word
            instruction2 = (decoded_instr.flat_instr.vdest & 0xFF) << 24;
            instruction2 |= (decoded_instr.flat_instr.saddr & 0x7F) << 16;
            instruction2 |= (decoded_instr.flat_instr.data & 0xFF) << 8;
            instruction2 |= (decoded_instr.flat_instr.addr & 0xFF);
            instr2_used = true;
            break;
        }

        case EXPORT: {
            // Set instruction bits for EXPORT (111110)
            instruction = 0xF8000000;
            instruction |= (decoded_instr.export_instr.vm & 0x1) << 12;
            instruction |= (decoded_instr.export_instr.done & 0x1) << 11;
            instruction |= (decoded_instr.export_instr.compr & 0x1) << 10;
            instruction |= (decoded_instr.export_instr.target & 0x3F) << 4;
            instruction |= (decoded_instr.export_instr.en & 0xF);
            
            // Second instruction word
            instruction2 = (decoded_instr.export_instr.vsrc3 & 0xFF) << 24;
            instruction2 |= (decoded_instr.export_instr.vsrc2 & 0xFF) << 16;
            instruction2 |= (decoded_instr.export_instr.vsrc1 & 0xFF) << 8;
            instruction2 |= (decoded_instr.export_instr.vsrc0 & 0xFF);
            instr2_used = true;
            break;
        }

        default:
            return 1; // Unknown instruction type
    }

    return 0; // Success
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

void add_header(std::ofstream &out_file){
    std::ifstream  src("basic_amd_header.bin", std::ios::binary);

    out_file << src.rdbuf();
}

void print_instruction(Instruction_Type instruction_type, Decoded_Instruction &decoded_instr, std::ofstream &outfile1, std::ofstream &outfile2){
    uint32_t encoded_instruction_first_32bits;
    uint32_t encoded_instruction_second_32bits;
    bool is_64_instruction;

    if(encode_instructions(instruction_type, decoded_instr, encoded_instruction_first_32bits, encoded_instruction_second_32bits, is_64_instruction)){
        std::cerr << "Error encoding Instruction " << std::endl;
    }

    outfile1.write(reinterpret_cast<const char*>(&encoded_instruction_first_32bits), sizeof encoded_instruction_first_32bits);
    outfile2 << std::hex << std::setw(2) << std::setfill('0') << encoded_instruction_first_32bits << std::endl;
    if(is_64_instruction){
        outfile1.write(reinterpret_cast<const char*>(&encoded_instruction_second_32bits), sizeof encoded_instruction_second_32bits);
        outfile2 << std::hex << std::setw(2) << std::setfill('0') << encoded_instruction_second_32bits << std::endl;
    }
}

void make_sopp_instr(Decoded_Instruction &decoded_instr, uint32_t opcode, uint32_t imm){
    decoded_instr.scalar_instr.type = SOPC;
    decoded_instr.scalar_instr.opcode = opcode;
    decoded_instr.scalar_instr.dest_in_use = 0;
    decoded_instr.scalar_instr.src0_in_use = 0;
    decoded_instr.scalar_instr.src1_in_use = 0;
    decoded_instr.scalar_instr.imm = imm;
    decoded_instr.scalar_instr.imm_in_use = 1;
    decoded_instr.scalar_instr.literal_in_use = 0;
}

void make_sopc_instr(Decoded_Instruction &decoded_instr, uint32_t opcode, uint32_t src0, uint32_t src1){
    decoded_instr.scalar_instr.type = SOPC;
    decoded_instr.scalar_instr.opcode = opcode;
    decoded_instr.scalar_instr.dest_in_use = 0;
    decoded_instr.scalar_instr.src0 = src0;   
    decoded_instr.scalar_instr.src0_in_use = 1;
    decoded_instr.scalar_instr.src1 = src1;  
    decoded_instr.scalar_instr.src1_in_use = 1;
    decoded_instr.scalar_instr.imm_in_use = 0;
    decoded_instr.scalar_instr.literal_in_use = 0;
}

void make_sop1_instr(Decoded_Instruction &decoded_instr, uint32_t opcode, uint32_t sdest, uint32_t src0){
    decoded_instr.scalar_instr.type = SOP1;
    decoded_instr.scalar_instr.opcode = opcode;
    decoded_instr.scalar_instr.dest = sdest;
    decoded_instr.scalar_instr.dest_in_use = 1;
    decoded_instr.scalar_instr.src0 = src0;   
    decoded_instr.scalar_instr.src0_in_use = 1;
    decoded_instr.scalar_instr.src1_in_use = 0;
    decoded_instr.scalar_instr.imm_in_use = 0;
    decoded_instr.scalar_instr.literal_in_use = 0;
}

void make_sop2_instr(Decoded_Instruction &decoded_instr, uint32_t opcode, uint32_t sdest, uint32_t src0, uint32_t src1){
    decoded_instr.scalar_instr.type = SOP2;
    decoded_instr.scalar_instr.opcode = opcode;
    decoded_instr.scalar_instr.dest = sdest;
    decoded_instr.scalar_instr.dest_in_use = 1;
    decoded_instr.scalar_instr.src0 = src0;   
    decoded_instr.scalar_instr.src0_in_use = 1;
    decoded_instr.scalar_instr.src1 = src1;  
    decoded_instr.scalar_instr.src1_in_use = 1;
    decoded_instr.scalar_instr.imm_in_use = 0;
    decoded_instr.scalar_instr.literal_in_use = 0;
}

void make_vop1_instr(Decoded_Instruction &decoded_instr, uint32_t opcode, uint32_t vdest, uint32_t src0){
    decoded_instr.vector_instr.type = VOP1;
    decoded_instr.vector_instr.sdwa.sdwa_in_use = 0;
    decoded_instr.vector_instr.sdwa.sdwab_in_use = 0;
    decoded_instr.vector_instr.ddp8.ddp8_in_use = 0;
    decoded_instr.vector_instr.ddp16.ddp16_in_use = 0;
    decoded_instr.vector_instr.opcode = opcode;
    decoded_instr.vector_instr.vdest = vdest;
    decoded_instr.vector_instr.src0 = src0;
    decoded_instr.vector_instr.literal_in_use = 0;
}

void make_vop2_instr(Decoded_Instruction &decoded_instr, uint32_t opcode, uint32_t vdest, uint32_t src0, uint32_t vsrc1){
    decoded_instr.vector_instr.type = VOP2;
    decoded_instr.vector_instr.sdwa.sdwa_in_use = 0;
    decoded_instr.vector_instr.sdwa.sdwab_in_use = 0;
    decoded_instr.vector_instr.ddp8.ddp8_in_use = 0;
    decoded_instr.vector_instr.ddp16.ddp16_in_use = 0;
    decoded_instr.vector_instr.opcode = opcode;
    decoded_instr.vector_instr.vdest = vdest;
    decoded_instr.vector_instr.src0 = src0;
    decoded_instr.vector_instr.vsrc1 = vsrc1;
    decoded_instr.vector_instr.literal_in_use = 0;
}

void make_vop3_default_instr(Decoded_Instruction &decoded_instr, uint32_t opcode, uint32_t vdest, uint32_t src0, uint32_t src1, uint32_t src2){
    decoded_instr.vector_instr.type = VOP3A;
    decoded_instr.vector_instr.sdwa.sdwa_in_use = 0;
    decoded_instr.vector_instr.sdwa.sdwab_in_use = 0;
    decoded_instr.vector_instr.ddp8.ddp8_in_use = 0;
    decoded_instr.vector_instr.ddp16.ddp16_in_use = 0;
    decoded_instr.vector_instr.opcode = opcode;
    decoded_instr.vector_instr.vdest = vdest;
    decoded_instr.vector_instr.src0 = src0;
    decoded_instr.vector_instr.src1 = src1;
    decoded_instr.vector_instr.src2 = src2;
    decoded_instr.vector_instr.cimp = 0;
    decoded_instr.vector_instr.op_sel = 0;
    decoded_instr.vector_instr.abs = 0;
    decoded_instr.vector_instr.neg = 0;
    decoded_instr.vector_instr.omod = 0;
    decoded_instr.vector_instr.literal_in_use = 0;
}

void make_global_load_dword_instr(Decoded_Instruction &decoded_instr, uint32_t vdest, uint32_t saddr, uint32_t addr){
    decoded_instr.flat_instr.opcode = 12;   // GLOBAL_LOAD_DWORD
    decoded_instr.flat_instr.slc = 0;       // unused: cache
    decoded_instr.flat_instr.glc = 0;       // unused: cache
    decoded_instr.flat_instr.seg = 2;       // global
    decoded_instr.flat_instr.lds = 0;       // to VGPRs not LDS
    decoded_instr.flat_instr.dlc = 0;       // unused: cache
    decoded_instr.flat_instr.offset = 0;    // no offset
    decoded_instr.flat_instr.vdest = vdest;     // load to dest
    decoded_instr.flat_instr.saddr = saddr;      // load from address in 
    decoded_instr.flat_instr.data = 0;      // unused, is a load
    decoded_instr.flat_instr.addr = addr;
}



#define A_WIDTH 10        // output array width
#define A_HEIGHT 10       // output array height
#define B_WIDTH 10        // output array width
#define B_HEIGHT 10       // output array height
// A_HEIGHT x B_WIDTH
#define A_ADDR 0x0100
#define B_ADDR 0x0200
#define C_ADDR 0x0300
#define A_i_ADDR 0x0400
#define B_i_ADDR 0x0500

#define ALPHA 10.5
#define BETA 1.5

#define TOTAL_SIZE (A_HEIGHT * B_WIDTH)

int main(int argc, char** argv, char** env) {

    Instruction_Type my_itype;
    Decoded_Instruction my_instr;
    Instruction_Type my_itype2;
    Decoded_Instruction my_instr2;


    static_assert(A_WIDTH == B_HEIGHT);
    // C = alpha*AB + beta*C

    // load alpha int s2
    // load beta into s3
    // load A_ADDR into s4
    // load B_ADDR into s5
    // load C_ADDR into s6
    // load A_i_ADDR to s7
    // load B_i_ADDR to s8
    // load B_HEIGHT to v20         allows to easier calculations later

    // load 0..31 into v1
    // for (int i=0; i<32; i++){
        // scalar store to exec mask only i=1
        // move i into v1 
    // }
    // scalar store to exec mask set all F


    // for(int i=0; i<TOTAL_SIZE; i+=32){
        // load (i + v1) to v4              v4 = i  //v_add_nc_u32
        // load v7 = c[i] to v7             v7 = GLOBAL_LOAD_DWORD from s6+v4  
        // v7 = v7*s3                       C = C * beta    // V_MUL_F32
        // load A_i[i] to v5                v5 = GLOBAL_LOAD_DWORD from s7+v4
        // load B_i[i] to v6                v6 = GLOBAL_LOAD_DWORD from s8+v4
        // load 0 to s9                     s9 = j = 0
        // LABEL: L0
            // C[i] = A[A_i[i] * A_WIDTH + j] * B[B_i[i] + j*B_HEIGHT] * alpha + c[i]
            // v7 = A[v5 * A_WIDTH + s9] * B[s9*B_HEIGHT + v6] * s2 + v7

            // v5 = v5*A_WIDTH
            // v5 = v5 + s9
            // v21 = s9*v20
            // v6 = v21 + v6
            // v10 = v5 * v6
            // v7 = v10*s2 + v7         //use v_fmac_f32 with just v10*s2

            // j++  s9 = s9 + 1
            // SCC = s9 < A_WIDTH
            // branch to L0 if SCC
        // store C (v7) to s6+v4    //GLOBAL_STORE_DWORD(28)
    // }


    std::ofstream out_file("gemm_program.bin");
    std::ofstream out_file2("gemm_program.txt");
    // add_header(out_file);
    // out_file.close();
    // exit(EXIT_SUCCESS);

    // load alpha int s2
    my_itype = SCALAR;
    make_sop1_instr(my_instr, 3, 2, 255);   //opcode 3 (S_MOV_B32), dest 2, scr0 255 (literal)
    my_instr.scalar_instr.literal = ALPHA;
    my_instr.scalar_instr.literal_in_use = 1;
    print_instruction(my_itype, my_instr, out_file, out_file2);
    
    // load beta into s3
    my_instr.scalar_instr.dest = 3;
    my_instr.scalar_instr.literal = BETA;
    print_instruction(my_itype, my_instr, out_file, out_file2);

    // load A_ADDR into s4
    my_instr.scalar_instr.dest = 4;
    my_instr.scalar_instr.literal = A_ADDR;
    print_instruction(my_itype, my_instr, out_file, out_file2);

    // load B_ADDR into s5
    my_instr.scalar_instr.dest = 5;
    my_instr.scalar_instr.literal = B_ADDR;
    print_instruction(my_itype, my_instr, out_file, out_file2);

    // load C_ADDR into s6
    my_instr.scalar_instr.dest = 6;
    my_instr.scalar_instr.literal = C_ADDR;
    print_instruction(my_itype, my_instr, out_file, out_file2);

    // load A_i_ADDR to s7
    my_instr.scalar_instr.dest = 7;
    my_instr.scalar_instr.literal = A_i_ADDR;
    print_instruction(my_itype, my_instr, out_file, out_file2);

    // load B_i_ADDR to s8
    my_instr.scalar_instr.dest = 8;
    my_instr.scalar_instr.literal = B_i_ADDR;
    print_instruction(my_itype, my_instr, out_file, out_file2);

    // load B_HEIGHT to v20         allows to easier calculations later
    my_itype2 = VECTOR;
    make_vop1_instr(my_instr2, 1, 20, 255);  // opcode 1 (V_MOV_B32), dest v20, src0 255 (literal)
    my_instr2.vector_instr.literal_in_use = 1;
    my_instr2.vector_instr.literal = B_HEIGHT;
    print_instruction(my_itype2, my_instr2, out_file, out_file2);

    // load 0..31 into v1
    my_instr.scalar_instr.dest = 126;   // EXEC_LO
    my_itype2 = VECTOR;
    make_vop1_instr(my_instr2, 1, 1, 0);  // opcode 1 (V_MOV_B32), dest v1, src0 0 (placeholder)
    for (int i=0; i<32; i++){
        // scalar store to exec mask only i bit is high
        my_instr.scalar_instr.literal = 1 << i;
        print_instruction(my_itype, my_instr, out_file, out_file2);

        // move i into v1 
        my_instr2.vector_instr.src0 = 128+i;    // constant i
        print_instruction(my_itype2, my_instr2, out_file, out_file2);
    }

    // scalar store to exec mask set all F
    my_instr.scalar_instr.literal = 0xFFFFFFFF;
    print_instruction(my_itype, my_instr, out_file, out_file2);

    for(int i=0; i<32; i++){
        // load (i + v1) to v4              v4 = i + v1
        my_itype = VECTOR;
        make_vop2_instr(my_instr, 37, 4, 255, 1);   //opcode 37 (v_add_nc_u32), vdest v4, src0 literal, vsrc1 v1
        my_instr.vector_instr.literal_in_use = 1;
        my_instr.vector_instr.literal = i;
        print_instruction(my_itype, my_instr, out_file, out_file2);

        // load v7 = c[i] to v7             v7 = GLOBAL_LOAD_DWORD from s6+v4 
        my_itype2 = FLAT; 
        make_global_load_dword_instr(my_instr2, 7, 6, 4);   // v7 = MEM[s6 + v4]
        print_instruction(my_itype2, my_instr2, out_file, out_file2);

        // v7 = v7*s3                       C = C * beta
        my_itype = VECTOR;
        make_vop2_instr(my_instr, 8, 7, 3, 7);     //opcode 8 (V_MUL_F32), vdest v7, src0 s3, vsrc1 v7
        print_instruction(my_itype, my_instr, out_file, out_file2);

        // load A_i[i] to v5                v5 = GLOBAL_LOAD_DWORD from s7+v4
        my_itype2 = FLAT; 
        make_global_load_dword_instr(my_instr2, 5, 7, 4);   // v5 = MEM[s7 + v4]
        print_instruction(my_itype2, my_instr2, out_file, out_file2);

        // load B_i[i] to v6                v6 = GLOBAL_LOAD_DWORD from s8+v4
        my_itype2 = FLAT; 
        make_global_load_dword_instr(my_instr2, 6, 8, 4);   // v6 = MEM[s8 + v4]
        print_instruction(my_itype2, my_instr2, out_file, out_file2);

        // load 0 to s9                     s9 = j = 0
        my_itype = SCALAR;
        make_sop1_instr(my_instr, 3, 9, 128);   //opcode 3 (S_MOV_B32), dest 9, scr0 128 (constant 0)
        print_instruction(my_itype, my_instr, out_file, out_file2);

        // L0
        int offset = 0;

            // // v5 = v5*A_WIDTH + s9 
            // my_itype = VECTOR;
            // make_vop3_default_instr(my_instr, 44+0x100, 5, 256+5, 9, 0); // opcode 44 (V_FMAMK_F32), dest v5, src0 v5, src1 s9, src3 ignored
            // print_instruction(my_itype, my_instr, out_file, out_file2);
            // offset += 2;

            // // v6 = s9*B_HEIGHT + v6    //V_FMAMK_F32
            // my_itype = VECTOR;
            // make_vop3_default_instr(my_instr, 44+0x100, 6, 9, 256+6, 0); // opcode 44 (V_FMAMK_F32), dest v5, src0 s9, src1 v6, src3 ignored
            // print_instruction(my_itype, my_instr, out_file, out_file2);
            // offset += 2;

            // v5 = v5*A_WIDTH
            my_itype = VECTOR;
            make_vop2_instr(my_instr, 8, 5, 255, 5);     //opcode 8 (V_MUL_F32), vdest v5, src0 literal, vsrc1 v5
            my_instr.vector_instr.literal_in_use = 1;
            my_instr.vector_instr.literal = A_WIDTH;
            print_instruction(my_itype, my_instr, out_file, out_file2);
            
            // v5 = v5 + s9
            my_itype = VECTOR;
            make_vop2_instr(my_instr, 3, 5, 9, 5);   //opcode 3 (V_ADD_F32), vdest v5, src0 s9, vsrc1 v5
            print_instruction(my_itype, my_instr, out_file, out_file2);
            
            // v21 = s9*v20
            my_itype = VECTOR;
            make_vop2_instr(my_instr, 8, 21, 9, 20);     //opcode 8 (V_MUL_F32), vdest v5, src0 literal, vsrc1 v5
            print_instruction(my_itype, my_instr, out_file, out_file2);

            // v6 = v21 + v6
            my_itype = VECTOR;
            make_vop2_instr(my_instr, 3, 6, 256+21, 6);   //opcode 3 (V_ADD_F32), vdest v6, src0 v21, vsrc1 v6
            print_instruction(my_itype, my_instr, out_file, out_file2);

            // v10 = v5 * v6
            my_itype = VECTOR;
            make_vop2_instr(my_instr, 8, 10, 256+5, 6);     //opcode 8 (V_MUL_F32), vdest v10, src0 v5, vsrc1 v6
            print_instruction(my_itype, my_instr, out_file, out_file2);
            offset += 1;

            // v7 = v10*s2 + v7         //use v_fmac_f32 with just v10*s2
            my_itype = VECTOR;
            make_vop2_instr(my_instr, 43, 7, 2, 10);     //opcode 43 (V_FMAC_F32), vdest 7, src0 s2, vsrc1 v7
            print_instruction(my_itype, my_instr, out_file, out_file2);
            offset += 1;

            // j++  s9 = s9 + 1
            my_itype = SCALAR;
            make_sop2_instr(my_instr, 0, 9, 9, 128+1);   //opcode 3 (S_ADD_U32), dest s9, src0 s9, scr1 constant 1
            print_instruction(my_itype, my_instr, out_file, out_file2);
            offset += 1;

            // SCC = s9 < A_WIDTH
            my_itype = SCALAR;
            make_sopc_instr(my_instr, 4, 255, 9);   //opcode 4 (S_CMP_LT_I32), src0 literal, scr1 constant 9
            my_instr.scalar_instr.literal_in_use = 1;
            my_instr.scalar_instr.literal = A_WIDTH;
            print_instruction(my_itype, my_instr, out_file, out_file2);
            offset += 2;


            // branch to L0 if SCC
            my_itype = SCALAR;
            offset = offset * -1;
            make_sopp_instr(my_instr, 5, (offset & 0xFFFF));    // opcode 5 (S_CBRANCH_SCC1)
            print_instruction(my_itype, my_instr, out_file, out_file2);

        // store C (v7) to s6+v4
        my_itype2 = FLAT; 
        make_global_load_dword_instr(my_instr2, 7, 6, 4);   // v7 = MEM[s6 + v4]
        my_instr2.flat_instr.opcode = 28;   // GLOBAL_STORE_DWORD
        my_instr2.flat_instr.data = 7;      // store from v7
        print_instruction(my_itype2, my_instr2, out_file, out_file2);
    }



    out_file.close();
    out_file2.close();
    exit(EXIT_SUCCESS);
}
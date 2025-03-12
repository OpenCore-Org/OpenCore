#include <stdlib.h>
#include <iostream>
#include <fstream> 
#include <bitset>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vsimd32_top.h"
// #include "Vsimd32_top___024unit.h"

#pragma once

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





// stoi but for unsigned
unsigned stou(std::string const & str, size_t * idx = 0, int base = 10) {
    unsigned long result = std::stoul(str, idx, base);
    if (result > std::numeric_limits<unsigned>::max()) {
        throw std::out_of_range("stou");
    }
    return result;
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

void make_nop_instr(Instruction_Type &itype, Decoded_Instruction &decoded_instr){
    itype = SCALAR;
    make_sopp_instr(decoded_instr, 0, 0);
}

uint32_t get_nop_instr(){
    return 0b10111111100000000000000000000000;
}

// vdest = vdest + src0
void make_vadd_to_self_instr(Decoded_Instruction &decoded_instr, uint32_t vdest, uint32_t src0){
    make_vop3_default_instr(decoded_instr, 43, vdest, src0, 128+1, 0);  // opcode 43 (V_FMAC_F32), src1 = constant 1
}

// vdest = vdest - src0
void make_vsub_to_self_instr(Decoded_Instruction &decoded_instr, uint32_t vdest, uint32_t src0){
    make_vop3_default_instr(decoded_instr, 43, vdest, src0, 193, 0);  // opcode 43 (V_FMAC_F32), src1 = constant -1
}
#include <stdlib.h>
#include <iostream>
#include <fstream> 
#include <bitset>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vsimd32_ex2.h"
#include "Vsimd32_ex2___024unit.h"

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
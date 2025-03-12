#include <stdlib.h>
#include <iostream>
#include <fstream> 
#include <bitset>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vsimd32_ex2.h"
#include "Vsimd32_ex2___024unit.h"

#include "main.h"


uint64_t sim_time = 0;
Vsimd32_ex2 *dut;
VerilatedVcdC *m_trace;


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


// int check_flag(Instruction_Type itype){
//     // Flag order: vector, scalar, flat, ds, export, mimg, mbuf, smem
//     uint8_t all_flag;
    
//     switch (itype)
//     {
//         case SCALAR:
//             all_flag = 0b01000000;
//             break;

//         case VECTOR:
//             all_flag = 0b10000000;
//             break;

//         case FLAT:
//             all_flag = 0b00100000;
//             break;

//         case DS:
//             all_flag = 0b00010000;
//             break;

//         case EXPORT:
//             all_flag = 0b00001000;
//             break;

//         case MIMG:
//             all_flag = 0b00000100;
//             break;

//         case MBUF:
//             all_flag = 0b00000010;
//             break;

//         case SMEM:
//             all_flag = 0b00000001;
//             break;
        
//         default:
//             return -1;
//     }
//     return !(dut->dec_ex1_all_flags == all_flag);
// }

void debug_printout(const std::string in_line, bool is_64bit, Instruction_Type itype){
    std::cout << "---------------------" << std::endl << "Cycle: " << std::dec << sim_time << std::endl;
    // std::cout << in_line << std::endl;
    // if(is_64bit)
    //     std::cout << "64 bit sintruction, skipping cycle" << std::endl;

    // std::cout << "Expected: " << convert_enum_string(itype) << std::endl;
    // std::cout << "Got: " << convert_allflag_string(dut->dec_ex1_all_flags) << std::endl;
}

int convert_scalar(struct Decoded_SCALAR &scalar_struct, VlWide<3> &output){
    print_decoded_instructions(scalar_struct);
    switch (scalar_struct.type){
        case SOP2:
            output[2] = 0;
            break;
        case SOP1:
            output[2] = 1;
            break;
        case SOPK:
            output[2] = 2;
            break;
        case SOPP:
            output[2] = 3;
            break;
        case SOPC:
            output[2] = 4;
            break;
        
        default:
            return 1;
    }
    output[2] = output[2] << 8;
    output[2] += scalar_struct.opcode;
    output[2] = output[2] << 7;
    output[2] += (scalar_struct.src0 >> 1);
    output[1] = (scalar_struct.src0 & 1);
    output[1] = output[1] << 8;
    output[1] += scalar_struct.src1;
    output[1] = output[1] << 7;
    output[1] += scalar_struct.dest;
    output[1] = output[1] << 16;
    output[1] += scalar_struct.imm;
    output[0] = scalar_struct.literal;
    std::cout << "raw instruction: " << std::hex << output[0] << output[1] << output[2] << std::endl;
    return 0;
}


int main(int argc, char** argv, char** env) {
    dut = new Vsimd32_ex2;

    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);     // limit waveform dumping to 5 levels under DUT
    m_trace->open("waveform.vcd");

    // std::ifstream ilist("instruction_list.txt");
    // if (!ilist.is_open()) {
    //     std::cerr << "Error opening the instruction list file!  Does it exist?";
    //     return 1;
    // }
    // std::string s;

    
    Instruction_Type itype;
    Decoded_Instruction input_instruction;
    Decoded_SCALAR scalar_instruction;
    VlWide<3> raw_scalar_instruction;

    
    dut->reset = 1;

    nextCycle();

    // set all constant signals
    dut->reset = 0;
    dut->ex1_ex2_all_flag = 0b01000000;     // scalar flag
    dut->ex1_ex2_valid = 1;
    dut->wavefront_num_in = 0;
    dut->ls_ex2_ready = 1;
    dut->ex2_ex1_ready = 1;     // manual override for testing, should be removed when testing final version

    scalar_instruction.type = SOP2;
    scalar_instruction.opcode = 0; // unsigned 32bit add
    scalar_instruction.src0 = 1;
    scalar_instruction.src0_in_use = 1;
    scalar_instruction.src1 = 2;
    scalar_instruction.src1_in_use = 1;
    scalar_instruction.dest = 3;
    scalar_instruction.dest_in_use = 1;
    convert_scalar(scalar_instruction, raw_scalar_instruction);

    dut->ssrc_in[0] = 1;
    dut->ssrc_in[1] = 2;
    dut->scalar_inst_in = raw_scalar_instruction;

    nextCycle();
    nextCycle();
    nextCycle();

    // ilist.close();
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
#include <stdlib.h>
#include <iostream>
#include <fstream> 
#include <bitset>
#include <bit>
#include <math.h>
#include <chrono>
#include <thread>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vsimd32_top.h"
// #include "Vsimd32_top___024unit.h"
#include "Vsimd32_top___024root.h"
#include "Vsimd32_top_simd32_top.h"
#include "Vsimd32_top_reg_status.h"
#include "Vsimd32_top_main_mem.h"
#include "Vsimd32_top_dual_port_RAM__N9_D200_W40.h"

#include "main.h"


uint64_t sim_time = 0;
Vsimd32_top *dut;
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

    if(sim_time > MAX_SIM_TIME){
        printf("ERROR: sim time exceeded!\n");
        m_trace->close();
        delete dut;
        exit(EXIT_SUCCESS);
    }
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

void set_pc(uint64_t new_pc){
    dut->rootp->simd32_top->gen_statusgpr_blk__BRA__0__KET____DOT__u_reg_status->r_pc = new_pc;
}

uint64_t get_pc(){
    return dut->rootp->simd32_top->gen_statusgpr_blk__BRA__0__KET____DOT__u_reg_status->r_pc;
}

void set_main_mem(uint32_t addr, uint32_t val){
    dut->rootp->simd32_top->u_main_mem->gen_mem_bank__BRA__0__KET____DOT__ram_inst->mem[addr] = val;
}

uint32_t get_main_mem(uint32_t addr){
    return dut->rootp->simd32_top->u_main_mem->gen_mem_bank__BRA__0__KET____DOT__ram_inst->mem[addr];
}

void run_instruction(Instruction_Type &itype, Decoded_Instruction &instr){
    uint32_t encoded_instruction_first_32bits;
    uint32_t encoded_instruction_second_32bits;
    bool is_64_instruction;

    if(encode_instructions(itype, instr, encoded_instruction_first_32bits, encoded_instruction_second_32bits, is_64_instruction)){
        std::cerr << "Error encoding Instruction " << std::endl;
    }

    // uint64_t current_pc = get_pc();
    // set_main_mem(current_pc+4, encoded_instruction_first_32bits);
    // if(is_64_instruction){
    //     set_main_mem(current_pc+8, encoded_instruction_second_32bits);
    //     nextCycle();
    // }
    // nextCycle();
    dut->inst = encoded_instruction_first_32bits;
    nextCycle();
    while(dut->decoder_stall)
        nextCycle();
    if(is_64_instruction){
        dut->inst = encoded_instruction_second_32bits;
        nextCycle();
    }
    while(dut->decoder_stall)
        nextCycle();
}

void clear_pipeline(){
    dut->inst = get_nop_instr();
    nextCycle();
    nextCycle();
    nextCycle();
    nextCycle();
}

#define SCREEN_WIDTH 50
#define SCREEN_HEIGHT 50
#define THETA_SPACING 0.07
#define PHI_SPACING 0.02

#define R1 1
#define R2 2
#define K2 5

// Calculate K1 based on screen size: the maximum x-distance occurs
// roughly at the edge of the torus, which is at x=R1+R2, z=0.  we
// want that to be displaced 3/8ths of the width of the screen, which
// is 3/4th of the way from the center to the side of the screen.
// SCREEN_WIDTH*3/8 = K1*(R1+R2)/(K2+0)
// SCREEN_WIDTH*K2*3/(8*(R1+R2)) = K1
#define K1 SCREEN_WIDTH*K2*3/(8*(R1+R2))


void render_frame(float A, float B) {
    // precompute sines and cosines of A and B
    float cosA = cos(A), sinA = sin(A);
    float cosB = cos(B), sinB = sin(B);
    
    //   char output[0..SCREEN_WIDTH, 0..SCREEN_HEIGHT] = ' ';
    char output[SCREEN_WIDTH][SCREEN_HEIGHT];
    memset(output, ' ', SCREEN_WIDTH*SCREEN_HEIGHT);

    // float zbuffer[0..SCREEN_WIDTH, 0..SCREEN_HEIGHT] = 0;
    float zbuffer[SCREEN_WIDTH][SCREEN_HEIGHT] = { 0 };
    
    // theta goes around the cross-sectional circle of a torus
    for (float theta=0; theta < 2*M_PI; theta += THETA_SPACING) {
        // precompute sines and cosines of theta
        float costheta = cos(theta), sintheta = sin(theta);
    
        // phi goes around the center of revolution of a torus
        for(float phi=0; phi < 2*M_PI; phi += PHI_SPACING) {
            // precompute sines and cosines of phi
            float cosphi = cos(phi), sinphi = sin(phi);
            
            // the x,y coordinate of the circle, before revolving (factored
            // out of the above equations)
            float circlex = R2 + R1*costheta;
            float circley = R1*sintheta;
        
            // final 3D (x,y,z) coordinate after rotations, directly from
            // our math above
            float x = circlex*(cosB*cosphi + sinA*sinB*sinphi)
                - circley*cosA*sinB; 
            float y = circlex*(sinB*cosphi - sinA*cosB*sinphi)
                + circley*cosA*cosB;
            float z = K2 + cosA*circlex*sinphi + circley*sinA;
            float ooz = 1/z;  // "one over z"
            
            // x and y projection.  note that y is negated here, because y
            // goes up in 3D space but down on 2D displays.
            int xp = (int) (SCREEN_WIDTH/2 + K1*ooz*x);
            int yp = (int) (SCREEN_HEIGHT/2 - K1*ooz*y);
            
            // calculate luminance.  ugly, but correct.
            float L = cosphi*costheta*sinB - cosA*costheta*sinphi -
                sinA*sintheta + cosB*(cosA*sintheta - costheta*sinA*sinphi);
            // L ranges from -sqrt(2) to +sqrt(2).  If it's < 0, the surface
            // is pointing away from us, so we won't bother trying to plot it.
            if (L > 0) {
                // test against the z-buffer.  larger 1/z means the pixel is
                // closer to the viewer than what's already plotted.
                if(ooz > zbuffer[xp][yp]) {
                    zbuffer[xp][yp] = ooz;
                    int luminance_index = L*8;
                    // luminance_index is now in the range 0..11 (8*sqrt(2) = 11.3)
                    // now we lookup the character corresponding to the
                    // luminance and plot it in our output:
                    output[xp][yp] = ".,-~:;=!*#$@"[luminance_index];
                }
            }
        }
    }
    
    // now, dump output[] to the screen.
    // bring cursor to "home" location, in just about any currently-used
    // terminal emulation mode
    printf("\x1b[H");
    for (int j = 0; j < SCREEN_HEIGHT; j++) {
        for (int i = 0; i < SCREEN_WIDTH; i++) {
        putchar(output[i][j]);
        }
        putchar('\n');
    }
  
}

void setup_GPU_reg(){
    Instruction_Type my_itype;
    Decoded_Instruction my_instr;
    float temp;
    my_itype = SCALAR;
    make_sop1_instr(my_instr, 3, 1, 255);   //opcode 3 (S_MOV_B32), dest 1, scr0 255 (literal)
    my_instr.scalar_instr.literal_in_use = 1;


    // put SCREEN_WIDTH in s1
    my_instr.scalar_instr.dest = 1;
    my_instr.scalar_instr.literal = SCREEN_WIDTH;
    run_instruction(my_itype, my_instr);

    // put SCREEN_WIDTH/2 in s2
    my_instr.scalar_instr.dest = 2;
    temp = SCREEN_WIDTH/2.0; 
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&temp);
    run_instruction(my_itype, my_instr);

    // put SCREEN_HEIGHT in s3
    my_instr.scalar_instr.dest = 3;
    my_instr.scalar_instr.literal = SCREEN_HEIGHT;
    run_instruction(my_itype, my_instr);

    // put SCREEN_HEIGHT/2 in s4
    my_instr.scalar_instr.dest = 4;
    temp = SCREEN_HEIGHT/2.0;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&temp);
    run_instruction(my_itype, my_instr);

    // put THETA_SPACING in s5
    my_instr.scalar_instr.dest = 5;
    temp = THETA_SPACING;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&temp);
    run_instruction(my_itype, my_instr);

    // put PHI_SPACING in s6
    my_instr.scalar_instr.dest = 6;
    temp = PHI_SPACING;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&temp);
    run_instruction(my_itype, my_instr);

    // put R1 in s7
    my_instr.scalar_instr.dest = 7;
    my_instr.scalar_instr.literal = R1;
    run_instruction(my_itype, my_instr);

    // put R2 in s8
    my_instr.scalar_instr.dest = 8;
    my_instr.scalar_instr.literal = R2;
    run_instruction(my_itype, my_instr);

    // put K1 in s9
    my_instr.scalar_instr.dest = 9;
    temp = K1;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&temp);
    run_instruction(my_itype, my_instr);

    // put K2 in s10
    my_instr.scalar_instr.dest = 10;
    my_instr.scalar_instr.literal = K2;
    run_instruction(my_itype, my_instr);
}

void render_frame_GPU(float A, float B){
    Instruction_Type my_itype;
    Decoded_Instruction my_instr;
    Instruction_Type my_itype2;
    Decoded_Instruction my_instr2;
    float temp;
    // It is assumed that setup_GPU_reg has been run

    // precompute sines and cosines of A and B
    float cosA = cos(A), sinA = sin(A);
    float cosB = cos(B), sinB = sin(B);

    my_itype = SCALAR;
    make_sop1_instr(my_instr, 3, 1, 255);   //opcode 3 (S_MOV_B32), dest 1, scr0 255 (literal)
    my_instr.scalar_instr.literal_in_use = 1;

    // put cosA in s11
    my_instr.scalar_instr.dest = 11;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&cosA);
    run_instruction(my_itype, my_instr);

    // put cosB in s12
    my_instr.scalar_instr.dest = 12;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&cosB);
    run_instruction(my_itype, my_instr);

    // put sinA in s13
    my_instr.scalar_instr.dest = 13;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&sinA);
    run_instruction(my_itype, my_instr);

    // put sinB in s14
    my_instr.scalar_instr.dest = 14;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&sinB);
    run_instruction(my_itype, my_instr);

    // put sinA*sinB in s15
    my_instr.scalar_instr.dest = 15;
    temp = sinA*sinB;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&temp);
    run_instruction(my_itype, my_instr);

    // put sinA*cosB in s16
    my_instr.scalar_instr.dest = 16;
    temp = sinA*cosB;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&temp);
    run_instruction(my_itype, my_instr);

    // put cosA*sinB in s17
    my_instr.scalar_instr.dest = 17;
    temp = cosA*sinB;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&temp);
    run_instruction(my_itype, my_instr);

    // put cosA*cosB in s18
    my_instr.scalar_instr.dest = 18;
    temp = cosA*cosB;
    my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&temp);
    run_instruction(my_itype, my_instr);

    
    //   char output[0..SCREEN_WIDTH, 0..SCREEN_HEIGHT] = ' ';
    char output[SCREEN_WIDTH][SCREEN_HEIGHT];
    memset(output, ' ', SCREEN_WIDTH*SCREEN_HEIGHT);

    // float zbuffer[0..SCREEN_WIDTH, 0..SCREEN_HEIGHT] = 0;
    float zbuffer[SCREEN_WIDTH][SCREEN_HEIGHT] = { 0 };
    
    clear_pipeline();
    // theta goes around the cross-sectional circle of a torus
    for (float theta=0; theta < 2*M_PI; theta += THETA_SPACING) {
        // precompute sines and cosines of theta
        float costheta = cos(theta), sintheta = sin(theta);
        // s19 = costheta
        my_instr.scalar_instr.dest = 19;
        my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&costheta);
        run_instruction(my_itype, my_instr);

        // s20 = sintheta
        my_instr.scalar_instr.dest = 20;
        my_instr.scalar_instr.literal = *reinterpret_cast<uint32_t*>(&sintheta);
        run_instruction(my_itype, my_instr);

    
        // phi goes around the center of revolution of a torus
        for(float phi=0; phi < 2*M_PI; phi += PHI_SPACING*32) {
            int num_items = 0;  //number of valid items in current wave.  max 32

        
            my_instr.scalar_instr.dest = 126;   // EXEC_LO
            my_itype2 = VECTOR;
            make_vop1_instr(my_instr2, 1, 1, 255);  // opcode 1 (V_MOV_B32), dest v1, src0 255 (literal)
            my_instr2.vector_instr.literal_in_use = 1;
            for(int i=0; i<32; i++){
                if(i*PHI_SPACING + phi >= 2*M_PI)
                    break;
                num_items++;

                // precompute sines and cosines of phi
                float cosphi = cos(phi + i*PHI_SPACING);
                float sinphi = sin(phi + i*PHI_SPACING);

                // put cosphi into v1
                // put sinphi into v2

                // load 0..31 into v1
                // scalar store to exec mask only i bit is high
                my_instr.scalar_instr.literal = 1 << i;
                run_instruction(my_itype, my_instr);
                clear_pipeline();
                
                // move cosphi into v1 
                my_instr2.vector_instr.literal = *reinterpret_cast<uint32_t*>(&cosphi);
                my_instr2.vector_instr.vdest = 1;
                run_instruction(my_itype2, my_instr2);

                // move sinphi into v1 
                my_instr2.vector_instr.literal = *reinterpret_cast<uint32_t*>(&sinphi);
                my_instr2.vector_instr.vdest = 2;
                run_instruction(my_itype2, my_instr2);

            }
            // scalar store to exec mask set all F
            my_instr.scalar_instr.literal = 0xFFFFFFFF;
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // NOT USED, test
            float cosphi = cos(phi);
            float sinphi = sin(phi);
            

            float circlex = R2 + R1*costheta;
            // v3 = s19
            my_itype = VECTOR;
            make_vop1_instr(my_instr, 1, 3, 19);  // opcode 1 (V_MOV_B32), dest v3, src0 s19
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v3 = s7*v3
            make_vop2_instr(my_instr, 8, 3, 7, 3);  // opcode 8 (V_MUL_F32), dest v3, src0 s7, src1 v3
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v3 = v3 + s8
            make_vadd_to_self_instr(my_instr, 3, 8);
            run_instruction(my_itype, my_instr);


            float circley = R1*sintheta;
            // v4 = s20
            make_vop1_instr(my_instr, 1, 4, 20);  // opcode 1 (V_MOV_B32), dest v4, src0 s20
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v4 = s7*v4
            make_vop2_instr(my_instr, 8, 4, 7, 4);  // opcode 8 (V_MUL_F32), dest v4, src0 s7, src1 v4
            run_instruction(my_itype, my_instr);
            

            float x = circlex*(cosB*cosphi + sinA*sinB*sinphi) - circley*cosA*sinB; 
            // v5 = s15*v2
            make_vop2_instr(my_instr, 8, 5, 15, 2);  // opcode 8 (V_MUL_F32), dest v5, src0 s15, src1 v2
            run_instruction(my_itype, my_instr);

            // v21 = s12*v1
            make_vop2_instr(my_instr, 8, 21, 12, 1);  // opcode 8 (V_MUL_F32), dest v21, src0 s12, src1 v1
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v5 = v5+v21
            make_vadd_to_self_instr(my_instr, 5, 256+21);
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v5 = v3*v5
            make_vop2_instr(my_instr, 8, 5, 256+3, 5);  // opcode 8 (V_MUL_F32), dest v5, src0 v3, src1 v5
            run_instruction(my_itype, my_instr);

            // v21 = s17*v4
            make_vop2_instr(my_instr, 8, 21, 17, 4);  // opcode 8 (V_MUL_F32), dest v21, src0 s17, src1 v4
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v5 = v5-v21
            make_vsub_to_self_instr(my_instr, 5, 256+21);
            run_instruction(my_itype, my_instr);


            float y = circlex*(sinB*cosphi - sinA*cosB*sinphi) + circley*cosA*cosB;
            // v20 = s16*v2
            make_vop2_instr(my_instr, 8, 20, 16, 2);  // opcode 8 (V_MUL_F32), dest v20, src0 s16, src1 v2
            run_instruction(my_itype, my_instr);

            // v6 = s11*v1
            make_vop2_instr(my_instr, 8, 6, 11, 1);  // opcode 8 (V_MUL_F32), dest v6, src0 s11, src1 v1
            run_instruction(my_itype, my_instr);
            clear_pipeline();
            
            // v6 = v6-v20
            make_vsub_to_self_instr(my_instr, 6, 256+20);
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v6 = v3*v6
            make_vop2_instr(my_instr, 8, 6, 256+3, 6);  // opcode 8 (V_MUL_F32), dest v6, src0 v3, src1 v6
            run_instruction(my_itype, my_instr);

            // v20 = s18*v4
            make_vop2_instr(my_instr, 8, 20, 18, 4);  // opcode 8 (V_MUL_F32), dest v20, src0 s18, src1 v4
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v6 = v6+v20
            make_vadd_to_self_instr(my_instr, 6, 256+20);
            run_instruction(my_itype, my_instr);


            float z = K2 + cosA*circlex*sinphi + circley*sinA;
            // v7 = s11*v3
            make_vop2_instr(my_instr, 8, 7, 11, 3);  // opcode 8 (V_MUL_F32), dest v7, src0 s11, src1 v3
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v7 = v7*v2
            make_vop2_instr(my_instr, 8, 7, 256+7, 2);  // opcode 8 (V_MUL_F32), dest v7, src0 v7, src1 v2
            run_instruction(my_itype, my_instr);

            // v20 = s13*v4
            make_vop2_instr(my_instr, 8, 20, 13, 4);  // opcode 8 (V_MUL_F32), dest v20, src0 s13, src1 v4
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v7 = v7 + s10
            make_vadd_to_self_instr(my_instr, 7, 10);
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            // v7 = v7 + v20
            make_vadd_to_self_instr(my_instr, 7, 256+20);
            run_instruction(my_itype, my_instr);
            clear_pipeline();

            

            float ooz = 1/z;  // "one over z"
            // idk, somehow v8 = 1/v7
            
            float L = cosphi*costheta*sinB - cosA*costheta*sinphi - sinA*sintheta + cosB*(cosA*sintheta - costheta*sinA*sinphi);

            int xp = (int) (SCREEN_WIDTH/2 + K1*ooz*x);
            int yp = (int) (SCREEN_HEIGHT/2 - K1*ooz*y);
            
            if (L > 0) {
                if(ooz > zbuffer[xp][yp]) {
                    zbuffer[xp][yp] = ooz;
                    int luminance_index = L*8;
                    output[xp][yp] = ".,-~:;=!*#$@"[luminance_index];
                }
            }
        }
    }
    
    // now, dump output[] to the screen.
    // bring cursor to "home" location, in just about any currently-used
    // terminal emulation mode
    printf("\x1b[H");
    for (int j = 0; j < SCREEN_HEIGHT; j++) {
        for (int i = 0; i < SCREEN_WIDTH; i++) {
        putchar(output[i][j]);
        }
        putchar('\n');
    }
}


int main(int argc, char** argv, char** env) {
    dut = new Vsimd32_top;

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

    Instruction_Type my_itype;
    Decoded_Instruction my_instr;
    
    dut->reset = 1;
    dut->inst = get_nop_instr();
    nextCycle();
    dut->reset = 0;
    nextCycle();

    make_nop_instr(my_itype, my_instr);
    run_instruction(my_itype, my_instr);

    my_itype = SCALAR;
    make_sop1_instr(my_instr, 3, 2, 255);   //opcode 3 (S_MOV_B32), dest 2, scr0 255 (literal)
    my_instr.scalar_instr.literal = 69;
    my_instr.scalar_instr.literal_in_use = 1;
    run_instruction(my_itype, my_instr);

    make_nop_instr(my_itype, my_instr);
    run_instruction(my_itype, my_instr);
    run_instruction(my_itype, my_instr);

    clear_pipeline();
    // render_frame(0,0);
    // std::this_thread::sleep_for(std::chrono::seconds(1));
    // render_frame(1,1);

    // for (int idk=0; idk<2; idk++)
    //     for (float i=0; i<M_PI*2; i=i+0.01){
    //         render_frame(i,i);
    //         std::this_thread::sleep_for(std::chrono::milliseconds(10));
    //     }

    setup_GPU_reg();
    render_frame_GPU(0,0);

    clear_pipeline();
    // ilist.close();
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
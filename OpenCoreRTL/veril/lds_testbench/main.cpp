#include <stdlib.h>
#include <iostream>
#include <fstream> 
#include <bitset>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vlds_cu_only.h"
// #include "Vlds_cu_only___024unit.h"

#define MAX_SIM_TIME 10000
// VERBOSE: 0 = minimal messages, 1=detailed error messages, 2=all messages
#define VERBOSE 0

#define BANKS 32


uint64_t sim_time = 0;
Vlds_cu_only *dut;
VerilatedVcdC *m_trace;

// stoi but for unsigned
unsigned stou(std::string const & str, size_t * idx = 0, int base = 10) {
    unsigned long result = std::stoul(str, idx, base);
    if (result > std::numeric_limits<unsigned>::max()) {
        throw std::out_of_range("stou");
    }
    return result;
}


int set_addr_simd1(uint32_t bank_num, uint32_t addr){
    if (bank_num > BANKS)
        return -1;

    VlWide<14> all_addr = dut->simd32_1_addr;
    uint32_t word_offset = (bank_num*14) / 32;
    uint32_t bit_offset = (bank_num*14) % 32;
    
    if(bit_offset > (32-14)){
        // value spread across 2 words
        uint64_t blank_mask = 1;
        blank_mask = (0xFFFFFFFFFFFFC000 << bit_offset) + ((blank_mask<<bit_offset)-1); 
        uint64_t top_word = all_addr[word_offset+1];
        uint64_t active_word = (top_word << 32) + all_addr[word_offset];
        uint64_t trimmed_addr = addr & 0x2FFF;
        active_word = (active_word & blank_mask) + (trimmed_addr << bit_offset);
        all_addr[word_offset] = (active_word & 0xFFFFFFFF);
        all_addr[word_offset+1] = (active_word >> 32);
    } else {

        // 32 bits of 1s except for 14 0s where the value is
        uint32_t blank_mask = (0xFFFFC000 << bit_offset) + ((1<<bit_offset)-1);  

        uint32_t active_word = all_addr[word_offset];
        active_word = (active_word & blank_mask) + ((addr & 0x2FFF)<<bit_offset);
        all_addr[word_offset] = active_word;
    }
    dut->simd32_1_addr = all_addr;

    uint32_t current_en = dut->simd32_1_en;
    current_en = current_en | (1<<bank_num);
    dut->simd32_1_en = current_en;

    return 0;
}

int set_wdata_simd1(uint32_t bank_num, uint32_t data){
    if (bank_num > BANKS)
        return -1;
    
    VlWide<32> all_data = dut->simd32_1_wdata;
    all_data[bank_num] = data;
    dut->simd32_1_wdata = all_data;
    return 0;
}

void reset_input_simd1(){
    VlWide<14> all_addr;
    VlWide<BANKS> wdata;
    for (int i=0; i<14; i++){
        all_addr[i] = 0;
    }
    for (int i=0; i<BANKS; i++)
        wdata[i] = 0;
    dut->simd32_1_en = 0;
    dut->simd32_1_we = 0;
    dut->simd32_1_addr = all_addr;
    dut->simd32_1_wdata = wdata;
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

    if(sim_time > MAX_SIM_TIME){
        printf("ERROR: sim time exceeded!\n");
        m_trace->close();
        delete dut;
        exit(EXIT_SUCCESS);
    }
}

int main(int argc, char** argv, char** env) {
    dut = new Vlds_cu_only;

    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);     // limit waveform dumping to 5 levels under DUT
    m_trace->open("waveform.vcd");


    dut->reset = 1;
    nextCycle();

    dut->reset = 0;
    reset_input_simd1();
    nextCycle();
   

    dut->simd32_1_we = 1;
    for (int i=0; i<BANKS; i++)
        set_addr_simd1(i, 10);
    for (int i=0; i<BANKS; i++)
        set_wdata_simd1(i, 10);

    nextCycle();
    while(dut->simd32_1_done == 0)
        nextCycle();

    dut->simd32_1_we = 0;
    for (int i=0; i<BANKS; i++)
        set_addr_simd1(i, 10);

    nextCycle();
    while(dut->simd32_1_done == 0)
        nextCycle();

    for (int i=0; i<BANKS; i++)
        if(dut->simd32_1_rdata[i] != 10)
            printf("fail on bank %d, test 1\n", i);
    
    

    reset_input_simd1();
    dut->simd32_1_we = 1;
    for (int i=0; i<BANKS; i++)
        set_addr_simd1(i, i);
    for (int i=0; i<BANKS; i++)
        set_wdata_simd1(i, 2*i+10);
    
    nextCycle();
    while(dut->simd32_1_done == 0)
        nextCycle();
    
    dut->simd32_1_we = 0;
    for (int i=0; i<BANKS; i++)
        set_addr_simd1(i, i);
    
    nextCycle();
    while(dut->simd32_1_done == 0)
        nextCycle();

    for (int i=0; i<BANKS; i++)
        if(dut->simd32_1_rdata[i] != 2*i+10)
            printf("fail on bank %d, test 2\n", i);
    


    reset_input_simd1();
    dut->simd32_1_we = 1;
    for (int i=0; i<BANKS; i++)
        set_addr_simd1(i, i+16);
    for (int i=0; i<BANKS; i++)
        set_wdata_simd1(i, 2*i+20);
    
    nextCycle();
    while(dut->simd32_1_done == 0)
        nextCycle();
    
    dut->simd32_1_we = 0;
    for (int i=0; i<BANKS; i++)
        set_addr_simd1(i, i+16);
    
    nextCycle();
    while(dut->simd32_1_done == 0)
        nextCycle();

    for (int i=0; i<BANKS; i++)
        if(dut->simd32_1_rdata[i] != 2*i+20)
            printf("fail on bank %d, test 3\n", i);


    nextCycle();
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
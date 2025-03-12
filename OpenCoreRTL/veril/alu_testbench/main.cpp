#include <stdlib.h>
#include <iostream>
#include <fstream> 
#include <bitset>
#include <random>
#include <ctime> 
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtestbench.h"
// #include "Vlds_cu_only___024unit.h"

#define MAX_SIM_TIME 10000
// VERBOSE: 0 = minimal messages, 1=detailed error messages, 2=all messages
#define VERBOSE 0

#define BANKS 32


uint64_t sim_time = 0;
Vtestbench *dut;
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

    if(sim_time > MAX_SIM_TIME){
        printf("ERROR: sim time exceeded!\n");
        m_trace->close();
        delete dut;
        exit(EXIT_SUCCESS);
    }
}

int main(int argc, char** argv, char** env) {
    dut = new Vtestbench;

    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);     // limit waveform dumping to 5 levels under DUT
    m_trace->open("waveform.vcd");


    srand((unsigned)time(0)); 


    int op_a_signed;
    int op_b_signed;
    unsigned int op_a_unsigned;
    unsigned int op_b_unsigned;

    dut->rst = 1;
    nextCycle();

    dut->rst = 0;
    



    // Unsigned add without carry in
    dut->cin_add = 0;
    dut->add = 1;

    op_a_unsigned = 1;
    op_b_unsigned = 1;
    dut->a_add = op_a_unsigned;
    dut->b_add = op_b_unsigned;
    nextCycle();
    if(op_a_unsigned + op_b_unsigned != dut->out_add){
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned+op_b_unsigned << std::endl;
    }
    if (dut->cout_add != 0)
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " carry out bit got 1, expected 0" << std::endl;
    op_a_unsigned = 4294967295 - 10;    // max - 10
    op_b_unsigned = 4294967295 - 10;    // max - 10
    dut->a_add = op_a_unsigned;
    dut->b_add = op_b_unsigned;
    nextCycle();
    if(op_a_unsigned + op_b_unsigned != dut->out_add){
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned+op_b_unsigned << std::endl;
    }
    if (dut->cout_add != 1)
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " carry out bit got 0, expected 1" << std::endl;
    for (int i=0; i<1000; i++){
        op_a_unsigned = rand();
        op_b_unsigned = rand();
        dut->a_add = op_a_unsigned;
        dut->b_add = op_b_unsigned;
        nextCycle();
        if(op_a_unsigned + op_b_unsigned != dut->out_add){
            std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned+op_b_unsigned << std::endl;
        }
        if((op_a_unsigned + op_b_unsigned > 4294967295) ^ dut->cout_add){
            std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " carry out bit got " << dut->cout_add << ", expected " << (op_a_unsigned+op_b_unsigned>4294967295) << std::endl;
        }
    }



    // Unsigned add with carry in
    dut->cin_add = 1;
    dut->add = 1;

    op_a_unsigned = 1;
    op_b_unsigned = 1;
    dut->a_add = op_a_unsigned;
    dut->b_add = op_b_unsigned;
    nextCycle();
    if(op_a_unsigned + op_b_unsigned+1 != dut->out_add){
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned+op_b_unsigned+1 << std::endl;
    }
    if (dut->cout_add != 0)
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " carry out bit got 1, expected 0" << std::endl;
    op_a_unsigned = 4294967295 - 10;    // max - 10
    op_b_unsigned = 4294967295 - 10;    // max - 10
    dut->a_add = op_a_unsigned;
    dut->b_add = op_b_unsigned;
    nextCycle();
    if(op_a_unsigned + op_b_unsigned+1 != dut->out_add){
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned+op_b_unsigned+1 << std::endl;
    }
    if (dut->cout_add != 1)
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " carry out bit got 0, expected 1" << std::endl;
    for (int i=0; i<1000; i++){
        op_a_unsigned = rand();
        op_b_unsigned = rand();
        dut->a_add = op_a_unsigned;
        dut->b_add = op_b_unsigned;
        nextCycle();
        if(op_a_unsigned + op_b_unsigned+1 != dut->out_add){
            std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned+op_b_unsigned+1 << std::endl;
        }
        if((op_a_unsigned + op_b_unsigned > 4294967295) ^ dut->cout_add){
            std::cout << std::dec << "ERROR (" << sim_time << ") unsigned add: Adding 0x" << std::hex << op_a_unsigned << " + 0x" << op_b_unsigned << " carry out bit got " << dut->cout_add << ", expected " << (op_a_unsigned+op_b_unsigned>4294967295) << std::endl;
        }
    }


    // // Signed add without carry in
    // dut->cin_add = 0;
    // dut->add = 1;

    // op_a_signed = 1;
    // op_b_signed = 1;
    // dut->a_add = op_a_signed;
    // dut->b_add = op_b_signed;
    // nextCycle();
    // if(op_a_signed + op_b_signed != dut->out_add){
    //     std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " got 0x" << dut->out_add << ", expected 0x" << op_a_signed+op_b_signed << std::endl;
    // }
    // if (dut->cout_add != 0)
    //     std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " carry out bit got 1, expected 0" << std::endl;
    // op_a_signed = 2147483647 - 10;    // max - 10
    // op_b_signed = 2147483647 - 10;    // max - 10
    // dut->a_add = op_a_signed;
    // dut->b_add = op_a_signed;
    // nextCycle();
    // if(op_a_signed + op_b_signed != dut->out_add){
    //     std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " got 0x" << dut->out_add << ", expected 0x" << op_a_signed+op_b_signed << std::endl;
    // }
    // if (dut->cout_add != 1)
    //     std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " carry out bit got 0, expected 1.  (result: 0x" << dut->out_add << ")" << std::endl;
    // for (int i=0; i<1000; i++){
    //     op_a_signed = rand();
    //     op_b_signed = rand();
    //     dut->a_add = op_a_signed;
    //     dut->b_add = op_b_signed;
    //     nextCycle();
    //     if(op_a_signed + op_b_signed != dut->out_add){
    //         std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " got 0x" << dut->out_add << ", expected 0x" << op_a_signed+op_b_signed << std::endl;
    //     }
    //     if((op_a_signed + op_b_signed > 2147483647) ^ dut->cout_add){
    //         std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " carry out bit got " << dut->cout_add << ", expected " << (op_a_signed+op_b_signed>4294967295) << std::endl;
    //     }
    // }


    // // Signed add with carry in
    // dut->cin_add = 1;
    // dut->add = 1;

    // op_a_signed = 1;
    // op_b_signed = 1;
    // dut->a_add = op_a_signed;
    // dut->b_add = op_b_signed;
    // nextCycle();
    // if(op_a_signed + op_b_signed+1 != dut->out_add){
    //     std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " got 0x" << dut->out_add << ", expected 0x" << op_a_signed+op_b_signed+1 << std::endl;
    // }
    // if (dut->cout_add != 0)
    //     std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " carry out bit got 1, expected 0" << std::endl;
    // op_a_signed = 2147483647 - 10;    // max - 10
    // op_b_signed = 2147483647 - 10;    // max - 10
    // dut->a_add = op_a_signed;
    // dut->b_add = op_a_signed;
    // nextCycle();
    // if(op_a_signed + op_b_signed+1 != dut->out_add){
    //     std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " got 0x" << dut->out_add << ", expected 0x" << op_a_signed+op_b_signed+1 << std::endl;
    // }
    // if (dut->cout_add != 1)
    //     std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " carry out bit got 0, expected 1" << std::endl;
    // for (int i=0; i<1000; i++){
    //     op_a_signed = rand();
    //     op_b_signed = rand();
    //     dut->a_add = op_a_signed;
    //     dut->b_add = op_b_signed;
    //     nextCycle();
    //     if(op_a_signed + op_b_signed+1 != dut->out_add){
    //         std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " got 0x" << dut->out_add << ", expected 0x" << op_a_signed+op_b_signed+1 << std::endl;
    //     }
    //     if((op_a_signed + op_b_signed > 2147483647) ^ dut->cout_add){
    //         std::cout << std::dec << "ERROR (" << sim_time << ") signed add: Adding 0x" << std::hex << op_a_signed << " + 0x" << op_b_signed << " carry out bit got " << dut->cout_add << ", expected " << (op_a_signed+op_b_signed>4294967295) << std::endl;
    //     }
    // }


    // Unsigned subtract without carry in
    dut->cin_add = 0;
    dut->add = 0;

    op_a_unsigned = 1;
    op_b_unsigned = 1;
    dut->a_add = op_a_unsigned;
    dut->b_add = op_b_unsigned;
    nextCycle();
    if(op_a_unsigned - op_b_unsigned != dut->out_add){
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned-op_b_unsigned << std::endl;
    }
    // if (dut->cout_add != 0)
    //     std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " carry out bit got 1, expected 0" << std::endl;
    op_a_unsigned = 4294967295 - 10;    // max - 10
    op_b_unsigned = 4294967295 - 10;    // max - 10
    dut->a_add = op_a_unsigned;
    dut->b_add = op_b_unsigned;
    nextCycle();
    if(op_a_unsigned - op_b_unsigned != dut->out_add){
        std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned-op_b_unsigned << std::endl;
    }
    // if (dut->cout_add != 1)
    //     std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " carry out bit got 0, expected 1" << std::endl;
    for (int i=0; i<1000; i++){
        op_a_unsigned = rand();
        op_b_unsigned = rand();
        dut->a_add = op_a_unsigned;
        dut->b_add = op_b_unsigned;
        nextCycle();
        if(op_a_unsigned - op_b_unsigned != dut->out_add){
            std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned-op_b_unsigned << std::endl;
        }
        // if((op_a_unsigned - op_b_unsigned > 4294967295) ^ dut->cout_add){
        //     std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " carry out bit got " << dut->cout_add << ", expected " << (op_a_unsigned-op_b_unsigned>4294967295) << std::endl;
        // }
    }



    // // Unsigned subtract with carry in
    // dut->cin_add = 1;
    // dut->add = 0;

    // op_a_unsigned = 1;
    // op_b_unsigned = 1;
    // dut->a_add = op_a_unsigned;
    // dut->b_add = op_b_unsigned;
    // nextCycle();
    // if(op_a_unsigned - op_b_unsigned+1 != dut->out_add){
    //     std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned-op_b_unsigned+1 << std::endl;
    // }
    // // if (dut->cout_add != 0)
    // //     std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " carry out bit got 1, expected 0" << std::endl;
    // op_a_unsigned = 4294967295 - 10;    // max - 10
    // op_b_unsigned = 4294967295 - 10;    // max - 10
    // dut->a_add = op_a_unsigned;
    // dut->b_add = op_b_unsigned;
    // nextCycle();
    // if(op_a_unsigned - op_b_unsigned+1 != dut->out_add){
    //     std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned-op_b_unsigned+1 << std::endl;
    // }
    // // if (dut->cout_add != 1)
    // //     std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " carry out bit got 0, expected 1" << std::endl;
    // for (int i=0; i<1000; i++){
    //     op_a_unsigned = rand();
    //     op_b_unsigned = rand();
    //     dut->a_add = op_a_unsigned;
    //     dut->b_add = op_b_unsigned;
    //     nextCycle();
    //     if(op_a_unsigned - op_b_unsigned+1 != dut->out_add){
    //         std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " got 0x" << dut->out_add << ", expected 0x" << op_a_unsigned+op_b_unsigned-1 << std::endl;
    //     }
    //     // if((op_a_unsigned - op_b_unsigned > 4294967295) ^ dut->cout_add){
    //     //     std::cout << std::dec << "ERROR (" << sim_time << ") unsigned subtract: Adding 0x" << std::hex << op_a_unsigned << " - 0x" << op_b_unsigned << " carry out bit got " << dut->cout_add << ", expected " << (op_a_unsigned-op_b_unsigned>4294967295) << std::endl;
    //     // }
    // }
    
        


    nextCycle();
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
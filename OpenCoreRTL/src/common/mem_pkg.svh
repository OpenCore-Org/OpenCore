`timescale 1ps/1ps


package mem_pkg;

    // SGPR Registers
    localparam SGPR_NUM_REG = 106;

    // VCC Registers 
    localparam VCC_NUM_REG = 2;

    // TTMP Registers
    localparam TTMP_NUM_REG = 16;

    // M0 Memory Register
    localparam M0_NUM_REG = 1;

    // NULL 
    localparam NULL_NUM_REG = 1; // ADDR is NULL for SGPR

    // EXEC Registers
    localparam EXEC_NUM_REG = 2;

    // SGPR Register Module Parameters
    localparam SGPR_RD_PORTS = 2;
    localparam SGPR_WR_PORTS = 1;
    localparam SGPR_DATA_WIDTH = 32;
    localparam SGPR_BANKS = 16;
    localparam SGPR_DEPTH = SGPR_NUM_REG + VCC_NUM_REG + TTMP_NUM_REG + M0_NUM_REG + NULL_NUM_REG + EXEC_NUM_REG; // 128 
    localparam SGPR_ADDR_WIDTH = $clog2(SGPR_DEPTH); // 7

    localparam DWORD_WIDTH = 32;

    // VGPR Register
    localparam VGPR_NUM_REG = 256;

    // VGPR Register Module Parameters
    localparam VGPR_RD_PORTS = 4;
    localparam VGPR_WR_PORTS = 1;
    localparam VGPR_DATA_WIDTH = 32;
    localparam VGPR_DEPTH = VGPR_NUM_REG;
    localparam VGPR_ADDR_WIDTH = $clog2(VGPR_DEPTH); // 8
    localparam VGPR_BANKS = 4;

    // SRAM
    localparam SRAM_ADDR_WIDTH = 32;
    localparam SRAM_DATA_WIDTH = 64;

    // LDS 
    localparam LDS_ADDR_WIDTH = 14;
    localparam LDS_DATA_WIDTH = 32;


    // Buffer Resource
    typedef struct packed {
        logic [47:0] base_addr;
        logic [13:0] stride;
        logic cache_swizzle;
        logic swizzle_en;
        logic [31:0] num_records;
        logic [2:0] dst_sel_x;
        logic [2:0] dst_sel_y;
        logic [2:0] dst_sel_z;
        logic [2:0] dst_sel_w;
        logic [6:0] format;
        logic [1:0] idx_stride;
        logic add_tid_en;
        logic resource_lvl;
        logic [1:0] oob_sel;
        logic [1:0] r_type;
    } buf_resource_t;

endpackage

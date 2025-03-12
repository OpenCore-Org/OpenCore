module simd32_ls 
import common_pkg::*;
import mem_pkg::*;
(
    input logic clk,
    input logic reset,

    input  logic [WAVEFRONT_WIDTH-1:0] wavefront_num_in,
    output logic [WAVEFRONT_WIDTH-1:0] wavefront_num_out,

    /* EX2 - LS */
    output logic ls_ex2_ready,
    input  logic ex2_ls_valid,

    input  logic                        ex2_ls_mem_en,
    input  logic                        ex2_ls_mem_we,
    input  logic [1:0]                  ex2_ls_mem_wstrb,
    input  logic [SRAM_DATA_WIDTH-1:0]  ex2_ls_mem_wdata,
    input  logic [SRAM_ADDR_WIDTH-1:0]  ex2_ls_mem_addr,
    /*
        smem_op
        3'b000 - 1 DWORD
        3'b001 - 2 DWORD
        3'b010 - 4 DWORD
        3'b011 - 8 DWORD
        3'b100 - 16 DWORD
        otherwise - RSVD - unused

        For smem:  ex2_ls_mem_wstrb determines if we are doing 1 load or 2.   
    */

    input logic [THREADS_PER_WAVEFRONT-1:0]                       ex2_ls_vmem_en,
    input logic [THREADS_PER_WAVEFRONT-1:0]                       ex2_ls_vmem_we,
    input logic [THREADS_PER_WAVEFRONT-1:0][1:0]                  ex2_ls_vmem_wstrb,    
    input logic [THREADS_PER_WAVEFRONT-1:0][SRAM_DATA_WIDTH-1:0]  ex2_ls_vmem_wdata,
    input logic [THREADS_PER_WAVEFRONT-1:0][SRAM_ADDR_WIDTH-1:0]  ex2_ls_vmem_addr,
    input logic                                                   ex2_ls_vmem_lds,                      

    input logic [SGPR_ADDR_WIDTH-1:0]   ex2_ls_s_dest_reg,
    input logic [SGPR_DATA_WIDTH*2-1:0] ex2_ls_s_dest_val,
    input logic [1:0]                   ex2_ls_s_dest_strb, // For 32bit LSB and 32bit MSB
    input logic                         ex2_ls_s_dest_we,

    input logic                            [VGPR_ADDR_WIDTH-1:0]  ex2_ls_v_dest_reg,
    input logic [THREADS_PER_WAVEFRONT-1:0][2*VGPR_DATA_WIDTH-1:0]ex2_ls_v_dest_val,
    input logic [1:0]                                             ex2_ls_v_dest_strb, 
    input logic [THREADS_PER_WAVEFRONT-1:0]                       ex2_ls_v_dest_we,

    /* LS - WB */ 
    output  logic [SGPR_ADDR_WIDTH-1:0]   ls_wb_s_dest_reg,
    output  logic [SGPR_DATA_WIDTH*2-1:0] ls_wb_s_dest_val,
    output  logic [1:0]                   ls_wb_s_dest_strb,
    output  logic                         ls_wb_s_dest_we,

    output  logic                            [VGPR_ADDR_WIDTH-1:0]    ls_wb_v_dest_reg,
    output  logic [THREADS_PER_WAVEFRONT-1:0][2*VGPR_DATA_WIDTH-1:0]  ls_wb_v_dest_val,
    output  logic [THREADS_PER_WAVEFRONT-1:0]                         ls_wb_v_dest_we,
    output  logic [1:0]                                               ls_wb_v_dest_strb,

    // MEM INTF
    output logic [THREADS_PER_WAVEFRONT-1:0][SRAM_ADDR_WIDTH-1:0] mem_addr,
    output logic [THREADS_PER_WAVEFRONT-1:0][SRAM_DATA_WIDTH-1:0] mem_wdata,
    input  logic [THREADS_PER_WAVEFRONT-1:0][SRAM_DATA_WIDTH-1:0] mem_rdata,
    input  logic                                                  mem_done,
    output logic [THREADS_PER_WAVEFRONT-1:0]                      mem_en,
    output logic [THREADS_PER_WAVEFRONT-1:0]                      mem_we,
    output logic [THREADS_PER_WAVEFRONT-1:0][1:0]                 mem_wstrb,

    // LDS INTF
    output  logic [THREADS_PER_WAVEFRONT-1:0]                          lds_en,
    output  logic                                        lds_we,
    output  logic [THREADS_PER_WAVEFRONT-1:0][LDS_ADDR_WIDTH-1 : 0]    lds_addr,
    output  logic [THREADS_PER_WAVEFRONT-1:0][LDS_DATA_WIDTH-1 : 0]    lds_wdata,
    input   logic [THREADS_PER_WAVEFRONT-1:0][LDS_DATA_WIDTH-1 : 0]    lds_rdata,
    input   logic                                        lds_done 
);

    logic [SGPR_ADDR_WIDTH-1:0]   next_ls_wb_s_dest_reg;
    logic [SGPR_DATA_WIDTH*2-1:0] next_ls_wb_s_dest_val;
    logic [1:0]                   next_ls_wb_s_dest_strb;
    logic                         next_ls_wb_s_dest_we;

    logic                            [VGPR_ADDR_WIDTH-1:0]    next_ls_wb_v_dest_reg;
    logic [THREADS_PER_WAVEFRONT-1:0][2*VGPR_DATA_WIDTH-1:0]  next_ls_wb_v_dest_val;
    logic [THREADS_PER_WAVEFRONT-1:0]                         next_ls_wb_v_dest_we;
    logic [1:0]                                               next_ls_wb_v_dest_strb;


    typedef enum logic { 
        LS_IDLE,
        LS_BUSY
    } ls_state_e;

    ls_state_e curr_state, next_state;

    always_ff @(posedge clk) begin
        if (reset) begin
            curr_state <= LS_IDLE;
        end else begin
            curr_state <= next_state;
        end
    end

    always_comb begin
        // Default values
        mem_addr    =  ex2_ls_vmem_addr;
        mem_wdata   =  ex2_ls_vmem_wdata;
        mem_en      =  '0;
        mem_we      =  ex2_ls_vmem_we;
        mem_wstrb   =  ex2_ls_vmem_wstrb;

        if (ex2_ls_mem_en) begin
            mem_addr[0]    = ex2_ls_mem_addr;
            mem_wdata[0]   = ex2_ls_mem_wdata;
            mem_we[0]      = ex2_ls_mem_we;
            mem_wstrb[0]   = ex2_ls_mem_wstrb;
        end

        for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
            lds_addr[th]    =  ex2_ls_vmem_addr[th][LDS_ADDR_WIDTH-1:0];
            lds_wdata[th]   =  ex2_ls_vmem_wdata[th][LDS_DATA_WIDTH-1:0];
        end
        lds_en      = '0;
        lds_we      =  ex2_ls_vmem_we[0];

        next_ls_wb_s_dest_reg   = '0;
        next_ls_wb_s_dest_val   = '0;
        next_ls_wb_s_dest_strb  = '0;
        next_ls_wb_s_dest_we    = '0;
        next_ls_wb_v_dest_reg   = '0;
        next_ls_wb_v_dest_val   = '0;
        next_ls_wb_v_dest_we    = '0;
        next_ls_wb_v_dest_strb  = '0;


        next_state = curr_state;

        if (curr_state == LS_IDLE) begin
            if (ex2_ls_valid) begin
                if (ex2_ls_mem_en || (|ex2_ls_vmem_en)) begin // MEM/LDS TRANS                                
                    ls_ex2_ready = 1'b0;
                    next_state = LS_BUSY;
                    if (ex2_ls_mem_en) begin
                        mem_en[0]      =  1'b1;
                    end else begin
                        lds_en      =  {THREADS_PER_WAVEFRONT{ex2_ls_vmem_lds}} & ex2_ls_vmem_en;
                        mem_en      =  {THREADS_PER_WAVEFRONT{~ex2_ls_vmem_lds}} & ex2_ls_vmem_en;
                    end
                end else begin // Direct Rd/Wr 
                    ls_ex2_ready = 1'b1;
                    next_ls_wb_s_dest_reg  = ex2_ls_s_dest_reg;
                    next_ls_wb_s_dest_val  = ex2_ls_s_dest_val;
                    next_ls_wb_s_dest_strb = ex2_ls_s_dest_strb;
                    next_ls_wb_s_dest_we   = ex2_ls_s_dest_we;

                    next_ls_wb_v_dest_reg  = ex2_ls_v_dest_reg;
                    next_ls_wb_v_dest_val  = ex2_ls_v_dest_val;
                    next_ls_wb_v_dest_we   = ex2_ls_v_dest_we;
                    next_ls_wb_v_dest_strb = ex2_ls_v_dest_strb;
                end
            end else begin // Don't assert ready if no valid
                ls_ex2_ready = 1'b0;
            end
        end else begin // curr_state == LS_BUSY
            ls_ex2_ready = 1'b0;
            if (ex2_ls_vmem_lds) begin // LDS
                if (lds_done) begin
                    next_state = LS_IDLE;
                    ls_ex2_ready = 1'b1;
                    next_ls_wb_v_dest_reg  = ex2_ls_v_dest_reg;
                    for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                        next_ls_wb_v_dest_val[th] = {32'b0, lds_rdata[th]};
                    end
                    next_ls_wb_v_dest_we   = ex2_ls_vmem_en &  ex2_ls_vmem_we; 
                    next_ls_wb_v_dest_strb = ex2_ls_v_dest_strb;
                end
            end else begin
                if (mem_done) begin
                    next_state = LS_IDLE;
                    ls_ex2_ready = 1'b1;
                    if (ex2_ls_mem_en) begin // SCALAR
                        next_ls_wb_s_dest_reg  = ex2_ls_s_dest_reg;
                        next_ls_wb_s_dest_val  = mem_rdata[0];
                        next_ls_wb_s_dest_strb = ex2_ls_s_dest_strb;
                        next_ls_wb_s_dest_we   = ex2_ls_s_dest_we & ex2_ls_mem_en;
                    end else begin // VECTOR
                        next_ls_wb_v_dest_reg  = ex2_ls_v_dest_reg;
                        next_ls_wb_v_dest_val  = mem_rdata;
                        next_ls_wb_v_dest_we   = ex2_ls_vmem_en & ex2_ls_v_dest_we;
                        next_ls_wb_v_dest_strb = ex2_ls_v_dest_strb;
                    end
                end
            end
        end 
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            ls_wb_s_dest_reg    <= '0;
            ls_wb_s_dest_val    <= '0;
            ls_wb_s_dest_strb   <= '0;
            ls_wb_s_dest_we     <= '0;

            ls_wb_v_dest_reg    <= '0;
            ls_wb_v_dest_val    <= '0;
            ls_wb_v_dest_we     <= '0;
            ls_wb_v_dest_strb   <= '0;
            wavefront_num_out   <= '0;
        end else begin
            ls_wb_s_dest_reg    <= next_ls_wb_s_dest_reg;
            ls_wb_s_dest_val    <= next_ls_wb_s_dest_val;
            ls_wb_s_dest_strb   <= next_ls_wb_s_dest_strb;
            ls_wb_s_dest_we     <= next_ls_wb_s_dest_we;

            ls_wb_v_dest_reg    <= next_ls_wb_v_dest_reg;
            ls_wb_v_dest_val    <= next_ls_wb_v_dest_val;
            ls_wb_v_dest_we     <= next_ls_wb_v_dest_we;
            ls_wb_v_dest_strb   <= next_ls_wb_v_dest_strb;
            wavefront_num_out   <= wavefront_num_in;
        end
    end


endmodule

module simd32_top 
import common_pkg::*;
import ex_pkg::*;
import mem_pkg::*;
(
    input logic clk,
    input logic reset,
    input logic [31:0] inst,
    input [$clog2(MAX_WAVEFRONT_CNT)-1:0] wavefront_num,
    output logic decoder_stall
);
    logic [ALL_FLAG_WIDTH-1:0]   dec_ex1_all_flags;
    vector_inst_t dec_ex1_vector_inst;
    scalar_inst_t dec_ex1_scalar_inst;
    flat_inst_t   dec_ex1_flat_inst;
    ds_inst_t     dec_ex1_ds_inst;
    export_inst_t dec_ex1_export_inst;
    mimg_inst_t   dec_ex1_mimg_inst;
    mbuf_inst_t   dec_ex1_mbuf_inst;
    smem_inst_t   dec_ex1_smem_inst;

    logic [ALL_FLAG_WIDTH-1:0]   ex1_ex2_all_flags;
    vector_inst_t    ex1_ex2_vector_inst;
    scalar_inst_t    ex1_ex2_scalar_inst;
    flat_inst_t      ex1_ex2_flat_inst;
    ds_inst_t        ex1_ex2_ds_inst;
    export_inst_t    ex1_ex2_export_inst;
    mimg_inst_t      ex1_ex2_mimg_inst;
    mbuf_inst_t      ex1_ex2_mbuf_inst;
    smem_inst_t      ex1_ex2_smem_inst;
    logic [SSRC_REG_CNT-1:0][SGPR_DATA_WIDTH-1:0] ex1_ex2_ssrc;
    logic [THREADS_PER_WAVEFRONT-1:0][VSRC_REG_CNT-1:0][VGPR_DATA_WIDTH-1:0] ex1_ex2_vsrc;

    logic ex2_ls_mem_en;
    logic ex2_ls_mem_we;
    logic [SRAM_DATA_WIDTH-1:0]     ex2_ls_mem_wdata;
    logic [1:0]                     ex2_ls_mem_wstrb;
    logic [31:0]                    ex2_ls_mem_addr;
    logic [SGPR_ADDR_WIDTH-1:0]     ex2_ls_s_dest_reg;
    logic [SGPR_DATA_WIDTH*2-1:0]   ex2_ls_s_dest_val;
    logic [1:0]                     ex2_ls_s_dest_strb;
    logic                           ex2_ls_s_dest_we;
    logic                            [VGPR_ADDR_WIDTH-1:0] ex2_ls_v_dest_reg;
    logic [THREADS_PER_WAVEFRONT-1:0][VGPR_DATA_WIDTH*2-1:0] ex2_ls_v_dest_val; 
    logic [THREADS_PER_WAVEFRONT-1:0]                      ex2_ls_v_dest_we;
    logic [1:0]                                            ex2_ls_v_dest_strb;

    logic [THREADS_PER_WAVEFRONT-1:0]                       ex2_ls_vmem_en;
    logic [THREADS_PER_WAVEFRONT-1:0]                       ex2_ls_vmem_we;
    logic [THREADS_PER_WAVEFRONT-1:0][1:0]                  ex2_ls_vmem_wstrb;
    logic [THREADS_PER_WAVEFRONT-1:0][SRAM_DATA_WIDTH-1:0]  ex2_ls_vmem_wdata;
    logic [THREADS_PER_WAVEFRONT-1:0][SRAM_ADDR_WIDTH-1:0]  ex2_ls_vmem_addr;
    logic                                                   ex2_ls_vmem_lds;

    logic [SGPR_ADDR_WIDTH-1:0] ls_wb_s_dest_reg;
    logic [SGPR_DATA_WIDTH*2-1:0] ls_wb_s_dest_val;
    logic ls_wb_s_dest_we;
    logic [1:0] ls_wb_s_dest_strb;
    logic [VGPR_ADDR_WIDTH-1:0] ls_wb_v_dest_reg;
    logic [THREADS_PER_WAVEFRONT-1:0][2*VGPR_DATA_WIDTH-1:0] ls_wb_v_dest_val;
    logic [THREADS_PER_WAVEFRONT-1:0] ls_wb_v_dest_we;
    logic [1:0] ls_wb_v_dest_strb;

    // MEM INTF
    logic [THREADS_PER_WAVEFRONT-1:0][SRAM_ADDR_WIDTH-1:0] mem_addr;
    logic [THREADS_PER_WAVEFRONT-1:0][SRAM_DATA_WIDTH-1:0] mem_wdata;
    logic [THREADS_PER_WAVEFRONT-1:0][SRAM_DATA_WIDTH-1:0] mem_rdata;
    logic                                                  mem_done;
    logic [THREADS_PER_WAVEFRONT-1:0]                      mem_en;
    logic [THREADS_PER_WAVEFRONT-1:0]                      mem_we;
    logic [THREADS_PER_WAVEFRONT-1:0][1:0]                 mem_wstrb;

    // LDS INTF
    logic [THREADS_PER_WAVEFRONT-1:0]                          lds_en;
    logic                                        lds_we;
    logic [THREADS_PER_WAVEFRONT-1:0][LDS_ADDR_WIDTH-1 : 0]    lds_addr;
    logic [THREADS_PER_WAVEFRONT-1:0][LDS_DATA_WIDTH-1 : 0]    lds_wdata;
    logic [THREADS_PER_WAVEFRONT-1:0][LDS_DATA_WIDTH-1 : 0]    lds_rdata;
    logic                                        lds_done;

    logic [SGPR_RD_PORTS-1:0][SGPR_DATA_WIDTH-1:0] sgpr_rdata_lo;
    logic [SGPR_RD_PORTS-1:0][SGPR_DATA_WIDTH-1:0] sgpr_rdata_hi;
    logic [SGPR_RD_PORTS-1:0][SGPR_ADDR_WIDTH-1:0] sgpr_raddr;
    logic [THREADS_PER_WAVEFRONT-1:0][VGPR_RD_PORTS-1:0][VGPR_DATA_WIDTH-1:0] vgpr_rdata_hi;
    logic [THREADS_PER_WAVEFRONT-1:0][VGPR_RD_PORTS-1:0][VGPR_DATA_WIDTH-1:0] vgpr_rdata_lo;
    logic [THREADS_PER_WAVEFRONT-1:0][VGPR_RD_PORTS-1:0][VGPR_ADDR_WIDTH-1:0] vgpr_raddr;
    logic [THREADS_PER_WAVEFRONT-1:0][VGPR_RD_PORTS-1:0]                      vgpr_renable;
    logic [THREADS_PER_WAVEFRONT-1:0]                                         vgpr_rdone;

    logic [WAVEFRONT_WIDTH-1:0] dec_ex1_wavefront_num;
    logic [WAVEFRONT_WIDTH-1:0] ex1_ex2_wavefront_num;
    logic [WAVEFRONT_WIDTH-1:0] ex2_ls_wavefront_num;
    logic [WAVEFRONT_WIDTH-1:0] ls_wb_wavefront_num;

    logic dec_ex1_valid;
    logic ex1_dec_ready;
    logic ex1_ex2_valid;
    logic ex2_ex1_ready;
    logic ls_ex2_ready;
    logic ex2_ls_valid;


    logic [MAX_WAVEFRONT_CNT-1:0] execz;
    logic [MAX_WAVEFRONT_CNT-1:0][THREADS_PER_WAVEFRONT-1:0] exec;

    logic [MAX_WAVEFRONT_CNT-1:0] vccz;
    logic [MAX_WAVEFRONT_CNT-1:0][THREADS_PER_WAVEFRONT-1:0] vcc;
    logic [THREADS_PER_WAVEFRONT-1:0] vcc_data;
    logic                             vcc_en; 

    logic [MAX_WAVEFRONT_CNT-1:0] scc;
    logic [MAX_WAVEFRONT_CNT-1:0] scc_data;
    logic [MAX_WAVEFRONT_CNT-1:0] scc_we;
    logic [MAX_WAVEFRONT_CNT-1:0][47:0] pc;
    logic [MAX_WAVEFRONT_CNT-1:0][47:0] pc_data;
    logic [MAX_WAVEFRONT_CNT-1:0]       pc_we;
    logic [MAX_WAVEFRONT_CNT-1:0]       active;
    logic [MAX_WAVEFRONT_CNT-1:0]       active_data;
    logic [MAX_WAVEFRONT_CNT-1:0]       active_we;
    logic [MAX_WAVEFRONT_CNT-1:0]       active_data_new;
    logic [MAX_WAVEFRONT_CNT-1:0]       active_we_new;
    logic [MAX_WAVEFRONT_CNT-1:0]       barrier;
    logic [MAX_WAVEFRONT_CNT-1:0]       barrier_data;
    logic [MAX_WAVEFRONT_CNT-1:0]       barrier_we;
    logic [MAX_WAVEFRONT_CNT-1:0]       barrier_data_cl;
    logic [MAX_WAVEFRONT_CNT-1:0]       barrier_we_cl;

    logic [MAX_WAVEFRONT_CNT-1:0]       clause;
    logic [MAX_WAVEFRONT_CNT-1:0]       clause_data;
    logic [MAX_WAVEFRONT_CNT-1:0]       clause_we;


    `ifdef verilator
        function [47:0] get_pc;
            // verilator public
            get_pc = pc[0];
        endfunction // get_wb_insn
    `endif

    // FIXME: Scheduler or something needs to clear the barrier
    assign barrier_data_cl = '0;
    assign barrier_we_cl = '0;

    // FIXEME: Schedular or something needs to set wavefronts active
    assign active_data_new = '0;
    assign active_we_new = '0;

    // Currently unused
    assign clause_data = '0;
    assign clause_we = '0;


    simd32_decode u_decode (
        .clk                (clk),
        .reset              (reset),
        .inst               (inst),
        .wavefront_num_in   (wavefront_num),
        .wavefront_num_out  (dec_ex1_wavefront_num),
        .decoder_stall      (decoder_stall),
        .dec_ex1_all_flags  (dec_ex1_all_flags),
        .vector_inst_out    (dec_ex1_vector_inst),
        .scalar_inst_out    (dec_ex1_scalar_inst),
        .flat_inst_out      (dec_ex1_flat_inst),
        .ds_inst_out        (dec_ex1_ds_inst),
        .export_inst_out    (dec_ex1_export_inst),
        .mimg_inst_out      (dec_ex1_mimg_inst),
        .mbuf_inst_out      (dec_ex1_mbuf_inst),
        .smem_inst_out      (dec_ex1_smem_inst),
        .dec_ex1_valid      (dec_ex1_valid),
        .ex1_dec_ready      (ex1_dec_ready)
    );

    simd32_ex1 u_simd32_ex1 (
        .clk                (clk),
        .reset              (reset),
        
        // DEC - EX1 Interface
        .dec_ex1_all_flags  (dec_ex1_all_flags),
        .vector_inst_in     (dec_ex1_vector_inst),
        .scalar_inst_in     (dec_ex1_scalar_inst),
        .flat_inst_in       (dec_ex1_flat_inst),
        .ds_inst_in         (dec_ex1_ds_inst),
        .export_inst_in     (dec_ex1_export_inst),
        .mimg_inst_in       (dec_ex1_mimg_inst),
        .mbuf_inst_in       (dec_ex1_mbuf_inst),
        .smem_inst_in       (dec_ex1_smem_inst),
        
        .dec_ex1_valid      (dec_ex1_valid),
        .ex1_dec_ready      (ex1_dec_ready),
        .wavefront_num_in   (dec_ex1_wavefront_num),
        
        // EX1 - EX2 Interface
        .ex1_ex2_all_flags  (ex1_ex2_all_flags),
        .vector_inst_out    (ex1_ex2_vector_inst),
        .scalar_inst_out    (ex1_ex2_scalar_inst),
        .flat_inst_out      (ex1_ex2_flat_inst),
        .ds_inst_out        (ex1_ex2_ds_inst),
        .export_inst_out    (ex1_ex2_export_inst),
        .mimg_inst_out      (ex1_ex2_mimg_inst),
        .mbuf_inst_out      (ex1_ex2_mbuf_inst),
        .smem_inst_out      (ex1_ex2_smem_inst),
        
        .r_ssrc_out          (ex1_ex2_ssrc),
        .r_vsrc_out          (ex1_ex2_vsrc),
        
        .ex2_ex1_ready      (ex2_ex1_ready),
        .ex1_ex2_valid      (ex1_ex2_valid),
        .wavefront_num_out  (ex1_ex2_wavefront_num),

        .sgpr_rdata_lo      (sgpr_rdata_lo),
        .sgpr_rdata_hi      (sgpr_rdata_hi),
        .sgpr_raddr         (sgpr_raddr),
        .vgpr_rdata_hi      (vgpr_rdata_hi),
        .vgpr_rdata_lo      (vgpr_rdata_lo),
        .vgpr_raddr         (vgpr_raddr),
        .vgpr_renable       (vgpr_renable),
        .vgpr_rdone         (|vgpr_rdone), // realistically rdone should come back at same time so this should be okay
        .execz              (execz),
        .vccz               (vccz),
        .scc                (scc)
    );   

    simd32_ex2 u_simd32_ex2 (
        .clk                (clk),
        .reset              (reset),

        // EX1 - EX2 Interface
        .vector_inst_in     (ex1_ex2_vector_inst),
        .scalar_inst_in     (ex1_ex2_scalar_inst),
        .flat_inst_in       (ex1_ex2_flat_inst),
        .ds_inst_in         (ex1_ex2_ds_inst),
        .export_inst_in     (ex1_ex2_export_inst),
        .mimg_inst_in       (ex1_ex2_mimg_inst),
        .mbuf_inst_in       (ex1_ex2_mbuf_inst),
        .smem_inst_in       (ex1_ex2_smem_inst),

        .ssrc_in            (ex1_ex2_ssrc),
        .vsrc_in            (ex1_ex2_vsrc),

        .ex1_ex2_all_flags  (ex1_ex2_all_flags),

        .wavefront_num_in   (ex1_ex2_wavefront_num),

        .ex2_ex1_ready      (ex2_ex1_ready),
        .ex1_ex2_valid      (ex1_ex2_valid),

        // EX2 - LS Interface
        .ex2_ls_mem_en      (ex2_ls_mem_en),
        .ex2_ls_mem_we      (ex2_ls_mem_we),
        .ex2_ls_mem_wdata   (ex2_ls_mem_wdata),
        .ex2_ls_mem_wstrb   (ex2_ls_mem_wstrb),
        .ex2_ls_mem_addr    (ex2_ls_mem_addr),

        .ex2_ls_vmem_en     (ex2_ls_vmem_en),
        .ex2_ls_vmem_we     (ex2_ls_vmem_we),
        .ex2_ls_vmem_wstrb  (ex2_ls_vmem_wstrb),
        .ex2_ls_vmem_wdata  (ex2_ls_vmem_wdata),
        .ex2_ls_vmem_addr   (ex2_ls_vmem_addr),
        .ex2_ls_vmem_lds    (ex2_ls_vmem_lds),

        .ex2_ls_s_dest_reg  (ex2_ls_s_dest_reg),
        .ex2_ls_s_dest_val  (ex2_ls_s_dest_val),
        .ex2_ls_s_dest_strb (ex2_ls_s_dest_strb),
        .ex2_ls_s_dest_we   (ex2_ls_s_dest_we),

        .ex2_ls_v_dest_reg  (ex2_ls_v_dest_reg),
        .ex2_ls_v_dest_val  (ex2_ls_v_dest_val),
        .ex2_ls_v_dest_strb (ex2_ls_v_dest_strb),
        .ex2_ls_v_dest_we   (ex2_ls_v_dest_we),

        .wavefront_num_out  (ex2_ls_wavefront_num),
        
        .ls_ex2_ready       (ls_ex2_ready),
        .ex2_ls_valid       (ex2_ls_valid),

        // Register Interface
        .scc                (scc),
        .scc_data           (scc_data),
        .scc_we             (scc_we),

        .pc                 (pc),
        .pc_data            (pc_data),
        .pc_we              (pc_we),

        .barrier            (barrier),
        .barrier_data       (barrier_data),
        .barrier_we         (barrier_we),

        .active             (active),
        .active_data        (active_data),
        .active_we          (active_we),

        .execz              (execz),
        .vccz               (vccz),
        .vcc                (vcc),
        .exec               (exec),
        .vcc_we             (vcc_en),
        .vcc_data           (vcc_data)
    );

    simd32_ls u_simd32_ls (
        .clk(clk),
        .reset(reset),
        
        .wavefront_num_in(ex2_ls_wavefront_num),
        .wavefront_num_out(ls_wb_wavefront_num),
        
        .ls_ex2_ready(ls_ex2_ready),
        .ex2_ls_valid(ex2_ls_valid),
        
        .ex2_ls_mem_en(ex2_ls_mem_en),
        .ex2_ls_mem_we(ex2_ls_mem_we), 
        .ex2_ls_mem_wdata(ex2_ls_mem_wdata),
        .ex2_ls_mem_wstrb(ex2_ls_mem_wstrb),
        .ex2_ls_mem_addr(ex2_ls_mem_addr),

        .ex2_ls_vmem_en (ex2_ls_vmem_en),
        .ex2_ls_vmem_we(ex2_ls_vmem_we),
        .ex2_ls_vmem_wstrb(ex2_ls_vmem_wstrb),
        .ex2_ls_vmem_wdata(ex2_ls_vmem_wdata),
        .ex2_ls_vmem_addr(ex2_ls_vmem_addr),
        .ex2_ls_vmem_lds(ex2_ls_vmem_lds),
        
        .ex2_ls_s_dest_reg(ex2_ls_s_dest_reg),
        .ex2_ls_s_dest_val(ex2_ls_s_dest_val),
        .ex2_ls_s_dest_strb(ex2_ls_s_dest_strb),
        .ex2_ls_s_dest_we(ex2_ls_s_dest_we),
        
        .ex2_ls_v_dest_reg(ex2_ls_v_dest_reg),
        .ex2_ls_v_dest_val(ex2_ls_v_dest_val), 
        .ex2_ls_v_dest_we(ex2_ls_v_dest_we),
        .ex2_ls_v_dest_strb(ex2_ls_v_dest_strb),
        
        .ls_wb_s_dest_reg(ls_wb_s_dest_reg),
        .ls_wb_s_dest_val(ls_wb_s_dest_val),
        .ls_wb_s_dest_we(ls_wb_s_dest_we),
        .ls_wb_s_dest_strb(ls_wb_s_dest_strb),
        
        .ls_wb_v_dest_reg(ls_wb_v_dest_reg),
        .ls_wb_v_dest_val(ls_wb_v_dest_val),
        .ls_wb_v_dest_we(ls_wb_v_dest_we),
        .ls_wb_v_dest_strb(ls_wb_v_dest_strb),

        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_done(mem_done),
        .mem_en(mem_en),
        .mem_we(mem_we),
        .mem_wstrb(mem_wstrb),

        .lds_en(lds_en),
        .lds_we(lds_we),
        .lds_addr(lds_addr),
        .lds_wdata(lds_wdata),
        .lds_rdata(lds_rdata),
        .lds_done(lds_done)
    );

    // LDS and MEM (should realisitically be outside but for synth purposes, put here)
    main_mem #(
        .BANKS(1),
        .DATA_WIDTH(SRAM_DATA_WIDTH)
    ) u_main_mem (
        .clk        (clk),
        .reset      (reset),
        .ram_en     (mem_en),
        .ram_wstrb  (mem_wstrb),
        .ram_we     (|mem_we),
        .ram_addr   (mem_addr),
        .ram_wdata  (mem_wdata),
        .ram_rdata  (mem_rdata),
        .ram_done   (mem_done)
    );

    lds_cu_only #(
        .BANKS(16),
        .THREADS(THREADS_PER_WAVEFRONT)
    ) u_lds (
        .clk            (clk),
        .reset          (reset),

        // SIMD32 #1
        .simd32_1_en    (lds_en),
        .simd32_1_we    (lds_we),
        .simd32_1_addr  (lds_addr),
        .simd32_1_wdata (lds_wdata),
        .simd32_1_rdata (lds_rdata),
        .simd32_1_done  (lds_done),

/* verilator lint_off PINCONNECTEMPTY */
        // SIMD32 #2 - Not Used
        .simd32_2_en    ('0),
        .simd32_2_we    ('0),
        .simd32_2_addr  ('0),
        .simd32_2_wdata ('0),
        .simd32_2_rdata (),
        .simd32_2_done  ()
/* verilator lint_on PINCONNECTEMPTY */
    );
   
    for (genvar wv = 0; wv < MAX_WAVEFRONT_CNT; wv++) begin : gen_statusgpr_blk
        reg_status u_reg_status (
            .clk(clk),
            .reset(reset),
            .scc(scc[wv]),
            .pc(pc[wv]),
            .active(active[wv]),
            .barrier(barrier[wv]),
            .clause(clause[wv]),
            .scc_data(scc_data[wv]),
            .scc_we(scc_we[wv]),
            .pc_data(pc_data[wv]),
            .pc_we(pc_we[wv]),
            .active_data(active_data[wv] | active_data_new[wv]),
            .active_we(active_we[wv] | active_we_new[wv]),
            .barrier_data(barrier_data[wv] & ~barrier_data_cl[wv]),
            .barrier_we(barrier_we[wv] | barrier_we_cl[wv]),
            .clause_data(clause_data[wv]),
            .clause_we(clause_we[wv])
        );
    end

    // 16 Banks of 128 32-bit Registers Each 
    reg_sgpr u_reg_sgpr (
        /*
        Reads and Writes are 64bits - Here how to read/write to these registers

        For Reads: 
        64bit reads MUST be 64bit aligned. I.e. read to reg 4 & 5 or 10 & 11 are allowed. 11 and 12 is not.
        32bit reads are allowed to any address. 

        If an ODD address is selected, it is assumed to be a 32 bit READ, RADDR will appear in radata_lo, rdata_hi will be zeroed out
        If an EVEN address is selected, it is assumed to be a 64 bit READ, RADDR will appear in rdata_lo, and RADDR+1 will appear in rdata_hi

        For Writes:
        64bit writes MUST be 64bit aligned. I.e. write to reg 4 & 5 or 10 & 11 are allowed. 11 and 12 is not.
        32bit writes are allowed to any address - ensure LSB of STRB is set. 
        */
        .clk(clk),
        .reset(reset),
        .rd_bank_sel(dec_ex1_wavefront_num), // Bank Selection
        .raddr(sgpr_raddr),
        .rdata_hi(sgpr_rdata_hi),
        .rdata_lo(sgpr_rdata_lo),
        .wr_bank_sel(ls_wb_wavefront_num),
        .wstrb(ls_wb_s_dest_strb), 
        .waddr(ls_wb_s_dest_reg), 
        .wdata(ls_wb_s_dest_val), 
        .wenable(ls_wb_s_dest_we), 
        .wave64_mode('0),
        .execz(execz),
        .exec(exec),
        .vcc(vcc),
        .vccz(vccz),
        .vcc_en(vcc_en),
        .vcc_bank_sel(ex2_ls_wavefront_num),
        .vcc_data(vcc_data)
    );

    for (genvar th = 0; th < THREADS_PER_WAVEFRONT; th++) begin : gen_vgpr_blk // Each thread needs their own vgpr_module
        // 1 Banks of 256 Register Each
        /*
            Bank 0: 0, 4, 8, 12
            Bank 1: 1, 5, 9, 13 
            Bank 2: 2, 6, 10, 14
            Bank 3; 3, 7, 11, 15
        */
        reg_vgpr u_reg_vgpr (
            .clk(clk),
            .reset(reset),
            .raddr(vgpr_raddr[th]),
            .rdata_hi(vgpr_rdata_hi[th]),
            .rdata_lo(vgpr_rdata_lo[th]),
            .renable(vgpr_renable[th]),
            .waddr(ls_wb_v_dest_reg),
            .wdata(ls_wb_v_dest_val[th]), 
            .wstrb(ls_wb_v_dest_strb),
            .wenable(ls_wb_v_dest_we[th]),
            .vgpr_done(vgpr_rdone[th])
        );
    end


endmodule

module simd32_ex1
import common_pkg::*;
import mem_pkg::*;
import ex_pkg::*;
(
    input logic clk,
    input logic reset,

    /* DEC - EX1  Interface */
    input logic [ALL_FLAG_WIDTH-1:0] dec_ex1_all_flags,
    input vector_inst_t vector_inst_in,
    input scalar_inst_t scalar_inst_in,
    input flat_inst_t   flat_inst_in,
    input ds_inst_t     ds_inst_in,
    input export_inst_t export_inst_in,
    input mimg_inst_t   mimg_inst_in,
    input mbuf_inst_t   mbuf_inst_in,
    input smem_inst_t   smem_inst_in,

    input  logic dec_ex1_valid,
    output logic ex1_dec_ready,
    input  logic [WAVEFRONT_WIDTH-1:0] wavefront_num_in,

    /* EX1 - EX2 */
    output logic [ALL_FLAG_WIDTH-1:0] ex1_ex2_all_flags,
    output vector_inst_t    vector_inst_out,
    output scalar_inst_t    scalar_inst_out,
    output flat_inst_t      flat_inst_out,
    output ds_inst_t        ds_inst_out,
    output export_inst_t    export_inst_out,
    output mimg_inst_t      mimg_inst_out,
    output mbuf_inst_t      mbuf_inst_out,
    output smem_inst_t      smem_inst_out,

    output logic [SSRC_REG_CNT-1:0][SGPR_DATA_WIDTH-1:0] r_ssrc_out,
    output logic [THREADS_PER_WAVEFRONT-1:0][VSRC_REG_CNT-1:0][VGPR_DATA_WIDTH-1:0] r_vsrc_out,

    input  logic ex2_ex1_ready,
    output logic ex1_ex2_valid,
    output logic [WAVEFRONT_WIDTH-1:0] wavefront_num_out,

    /* From Reg */
    input  logic [SGPR_RD_PORTS-1:0][SGPR_DATA_WIDTH-1:0]     sgpr_rdata_lo,
    input  logic [SGPR_RD_PORTS-1:0][SGPR_DATA_WIDTH-1:0]     sgpr_rdata_hi,
    output logic [SGPR_RD_PORTS-1:0][SGPR_ADDR_WIDTH-1:0]     sgpr_raddr,
    input  logic [THREADS_PER_WAVEFRONT-1:0][VGPR_RD_PORTS-1:0][VGPR_DATA_WIDTH-1:0] vgpr_rdata_hi,
    input  logic [THREADS_PER_WAVEFRONT-1:0][VGPR_RD_PORTS-1:0][VGPR_DATA_WIDTH-1:0] vgpr_rdata_lo,
    output logic [THREADS_PER_WAVEFRONT-1:0][VGPR_RD_PORTS-1:0][VGPR_ADDR_WIDTH-1:0] vgpr_raddr,
    output logic [THREADS_PER_WAVEFRONT-1:0][VGPR_RD_PORTS-1:0]                      vgpr_renable,
    input  logic                                                                     vgpr_rdone,
    // usage: vgpr_raddr[thread #][read port #][addr width]

    input logic [MAX_WAVEFRONT_CNT-1:0] execz,
    input logic [MAX_WAVEFRONT_CNT-1:0] vccz,
    input logic [MAX_WAVEFRONT_CNT-1:0] scc
);

    // Internal Signals
    typedef enum logic { 
        EX1_IDLE,
        EX1_BUSY
    } ex1_state_e;

    ex1_state_e      curr_ex1_state, next_ex1_state;
    logic            next_ex1_ex2_valid;

    vector_inst_t    r_vector_inst_in;
    scalar_inst_t    r_scalar_inst_in;
    flat_inst_t      r_flat_inst_in;
    ds_inst_t        r_ds_inst_in;
    export_inst_t    r_export_inst_in;
    mimg_inst_t      r_mimg_inst_in;
    mbuf_inst_t      r_mbuf_inst_in;
    smem_inst_t      r_smem_inst_in;

    logic [ALL_FLAG_WIDTH-1:0] r_all_flag;

    // Misc. Status Registers
    logic [$clog2(MAX_WAVEFRONT_CNT)-1:0] r_curr_wavefront;

    // Execution Signals
    buf_resource_t r_buf_resource;

    assign vector_inst_out = r_vector_inst_in;
    assign scalar_inst_out = r_scalar_inst_in;
    assign flat_inst_out   = r_flat_inst_in;
    assign ds_inst_out     = r_ds_inst_in;
    assign export_inst_out = r_export_inst_in;
    assign mimg_inst_out   = r_mimg_inst_in;
    assign mbuf_inst_out   = r_mbuf_inst_in;
    assign smem_inst_out   = r_smem_inst_in;

    assign ex1_ex2_all_flags = r_all_flag;

    always_comb begin
        next_ex1_state = curr_ex1_state;
        next_ex1_ex2_valid = 1'b0;

        if (curr_ex1_state == EX1_IDLE) begin
            if (dec_ex1_valid) begin
                case (dec_ex1_all_flags)
                    VECTOR_FLAG, EXPORT_FLAG: begin
                        next_ex1_state = EX1_BUSY;
                        ex1_dec_ready = 1'b0;
                    end
                    DS_FLAG, FLAT_FLAG: begin
                        next_ex1_state = EX1_BUSY;
                        ex1_dec_ready = 1'b0;
                    end
                    MBUF_FLAG: begin 
                        next_ex1_state = EX1_BUSY;
                        ex1_dec_ready = 1'b0;
                    end
                    default: begin
                        ex1_dec_ready = ex2_ex1_ready;
                        next_ex1_ex2_valid = 1'b1;
                    end
                endcase
            end else begin
                ex1_dec_ready = ex2_ex1_ready;
            end
        end else begin
            if (vgpr_rdone) begin
                next_ex1_ex2_valid = 1'b1;
                ex1_dec_ready = ex2_ex1_ready;
                if (ex2_ex1_ready) begin
                    next_ex1_state = EX1_IDLE;
                end
            end else begin
                ex1_dec_ready = 1'b0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            curr_ex1_state <= EX1_IDLE;
            ex1_ex2_valid <= 1'b0;
        end else begin
            curr_ex1_state <= next_ex1_state;
            ex1_ex2_valid <= next_ex1_ex2_valid;
        end
    end


    always_comb begin // Register Load Combinational Logic
        // Set defaults:
        sgpr_raddr = '0;
        vgpr_raddr = '0;
        vgpr_renable  = '0;

        case (dec_ex1_all_flags)
            VECTOR_FLAG: begin
                for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                    vgpr_raddr[th][0] = vector_inst_in.src0[VGPR_ADDR_WIDTH-1:0];
                    vgpr_raddr[th][1] = vector_inst_in.src1[VGPR_ADDR_WIDTH-1:0];
                    vgpr_raddr[th][2] = vector_inst_in.src2[VGPR_ADDR_WIDTH-1:0];
                    vgpr_raddr[th][3] = vector_inst_in.vdst[VGPR_ADDR_WIDTH-1:0];
                    vgpr_renable[th]  = '1;
                end

                case (vector_inst_in.format)
                    VOP2, VOP1, VOPC, VINTRP: begin
                        sgpr_raddr[0] = vector_inst_in.src0[SGPR_ADDR_WIDTH-1:0];
                    end
                    VOP3, VOP3P: begin
                        if (vector_inst_in.src0[8:7] == 2'b00) begin
                            sgpr_raddr[0] = vector_inst_in.src0[SGPR_ADDR_WIDTH-1:0];
                            if ((vector_inst_in.src0 != vector_inst_in.src1) && (vector_inst_in.src1[8:7] == 2'b00)) begin
                                sgpr_raddr[1] = vector_inst_in.src1[SGPR_ADDR_WIDTH-1:0];
                            end else begin
                                sgpr_raddr[1] = vector_inst_in.src2[SGPR_ADDR_WIDTH-1:0];
                            end
                        end else begin
                            sgpr_raddr[0] = vector_inst_in.src1[SGPR_ADDR_WIDTH-1:0];
                            sgpr_raddr[1] = vector_inst_in.src2[SGPR_ADDR_WIDTH-1:0];
                        end
                    end
                    default:;
                endcase
            end
            SCALAR_FLAG: begin
                sgpr_raddr[0] = scalar_inst_in.src0[SGPR_ADDR_WIDTH-1:0];

                case (scalar_inst_in.format)
                    SOP2, SOPC, SOP1, SOPP: begin
                        sgpr_raddr[1] = scalar_inst_in.src1[SGPR_ADDR_WIDTH-1:0];
                    end 
                    SOPK: begin
                        sgpr_raddr[1] = scalar_inst_in.dst[SGPR_ADDR_WIDTH-1:0]; // Some OPs use DEST as SRC, pull from sgpr_rdata_lo[1] if needed
                    end
                    default:;
                endcase
            end
            FLAT_FLAG: begin
                sgpr_raddr[0] = flat_inst_in.saddr;
                for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin

                    vgpr_raddr[th][0] = flat_inst_in.addr; // For 32-bit addressing 
                    vgpr_raddr[th][1] = flat_inst_in.data;
                    vgpr_raddr[th][2] = flat_inst_in.data + 1;
                    vgpr_renable[th] = 4'b0111;
                    //vgpr_raddr[th][3] = flat_inst_in.vdst;
                end
            end
            DS_FLAG: begin
                for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                    vgpr_raddr[th][0] = ds_inst_in.data0; // DATA0
                    vgpr_raddr[th][1] = ds_inst_in.data1; // DATA1
                    vgpr_raddr[th][2] = ds_inst_in.addr; // ADDR
                    vgpr_renable[th] = 4'b0111;
                end
            end
            EXPORT_FLAG: begin
                sgpr_raddr[0] = EXEC_LO[6:0];
                for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                    vgpr_raddr[th][0] = export_inst_in.vsrc0;
                    vgpr_raddr[th][1] = export_inst_in.vsrc1;
                    vgpr_raddr[th][2] = export_inst_in.vsrc2;
                    vgpr_raddr[th][3] = export_inst_in.vsrc3;
                    vgpr_renable[th] = 4'b1111;
                end
            end
            MIMG_FLAG: begin // FIXME: Not doing this instr.
            end
            MBUF_FLAG: begin // Requires 2 cycles for all data reads (CYCLE 1)
                sgpr_raddr[0] = mbuf_inst_in.soffset[SGPR_ADDR_WIDTH-1:0];

                for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                    vgpr_raddr[th][0] = mbuf_inst_in.vaddr;
                    vgpr_raddr[th][1] = mbuf_inst_in.vaddr + 1;
                    vgpr_renable[th] = 4'b0011;
                end
            end
            SMEM_FLAG: begin
                sgpr_raddr[0] = ({1'b0, smem_inst_in.sbase} << 1);
                sgpr_raddr[1] = smem_inst_in.soffset;
                // will load from memory address SGPR[sbase] + offset + SGPR[soffset], into 
                // therefore sbase and soffeset reg need to be read
            end
            default:;
        endcase
    end

    always_ff @(posedge clk) begin // First Stage - Register Load Stage
        if (reset) begin
            r_ssrc_out[0] <= '0;
            r_ssrc_out[1] <= '0;
            r_ssrc_out[2] <= '0;
            r_ssrc_out[3] <= '0;

            r_vector_inst_in <= '0;
            r_scalar_inst_in <= '0;
            r_flat_inst_in <= '0;
            r_ds_inst_in <= '0;
            r_export_inst_in <= '0;
            r_mimg_inst_in <= '0;
            r_mbuf_inst_in <= '0;
            r_smem_inst_in <= '0;
        end else begin
            r_ssrc_out[0] <= 'x;
            r_ssrc_out[1] <= 'x;
            r_ssrc_out[2] <= 'x;
            r_ssrc_out[3] <= 'x;

            r_buf_resource <= '0;
            r_vector_inst_in <= vector_inst_in;
            r_scalar_inst_in <= scalar_inst_in;
            r_flat_inst_in <= flat_inst_in;
            r_ds_inst_in <= ds_inst_in;
            r_export_inst_in <= export_inst_in;
            r_mimg_inst_in <= mimg_inst_in;
            r_mbuf_inst_in <= mbuf_inst_in;
            r_smem_inst_in <= smem_inst_in;

            case (dec_ex1_all_flags)
                VECTOR_FLAG: begin
                    for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                        case (vector_inst_in.format)
                            VOP2, VOP1, VOPC: begin
                                // SRC0
                                r_vsrc_out[th][0] <= vector_src_decode(.src(vector_inst_in.src0), .ssrc_data(sgpr_rdata_lo[0]), .vsrc_data(vgpr_rdata_lo[th][0]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                r_vsrc_out[th][1] <= vector_src_decode(.src(vector_inst_in.src0), .ssrc_data(sgpr_rdata_hi[0]), .vsrc_data(vgpr_rdata_hi[th][0]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                // SRC1
                                r_vsrc_out[th][2] <= vgpr_rdata_lo[th][1];
                                r_vsrc_out[th][3] <= vgpr_rdata_hi[th][1];
                                // VDST
                                r_vsrc_out[th][4] <= vgpr_rdata_lo[th][3]; // This is VDST for the MAC VOP2 instructions
                                r_vsrc_out[th][5] <= vgpr_rdata_hi[th][3]; // This is VDST for the MAC VOP2 instructions
                            end
                            VINTRP: begin
                                // VSRC
                                r_vsrc_out[th][0] <= vgpr_rdata_lo[th][0];
                                r_vsrc_out[th][1] <= vgpr_rdata_hi[th][0];
                                r_vsrc_out[th][2] <= vgpr_rdata_lo[th][1]; // Not needed, but simplifies logic
                                r_vsrc_out[th][3] <= vgpr_rdata_hi[th][1]; // Not needed, but simplifies logic
                            end
                            VOP3, VOP3P: begin
                                if (vector_inst_in.src0[8:7] == 2'b00) begin // Is a scaler reg.
                                    // SRC0
                                    r_vsrc_out[th][0] <= sgpr_rdata_lo[0];
                                    r_vsrc_out[th][1] <= sgpr_rdata_hi[0];

                                    // SRC1
                                    if (vector_inst_in.src0 == vector_inst_in.src1) begin
                                        r_vsrc_out[th][2] <= sgpr_rdata_lo[0];
                                        r_vsrc_out[th][3] <= sgpr_rdata_hi[0];
                                    end else begin
                                        r_vsrc_out[th][2] <= vector_src_decode(.src(vector_inst_in.src1), .ssrc_data(sgpr_rdata_lo[1]), .vsrc_data(vgpr_rdata_lo[th][1]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                        r_vsrc_out[th][3] <= vector_src_decode(.src(vector_inst_in.src1), .ssrc_data(sgpr_rdata_hi[1]), .vsrc_data(vgpr_rdata_hi[th][1]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                    end

                                    // SRC2
                                    if (vector_inst_in.src0 == vector_inst_in.src2) begin
                                        r_vsrc_out[th][4] <= sgpr_rdata_lo[0];
                                        r_vsrc_out[th][5] <= sgpr_rdata_hi[0];
                                    end else begin
                                        r_vsrc_out[th][4] <= vector_src_decode(.src(vector_inst_in.src2), .ssrc_data(sgpr_rdata_lo[1]), .vsrc_data(vgpr_rdata_lo[th][2]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                        r_vsrc_out[th][5] <= vector_src_decode(.src(vector_inst_in.src2), .ssrc_data(sgpr_rdata_hi[1]), .vsrc_data(vgpr_rdata_hi[th][2]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                    end

                                end else begin
                                    // SRC0
                                    r_vsrc_out[th][0] <= vector_src_decode(.src(vector_inst_in.src0), .ssrc_data('x), .vsrc_data(vgpr_rdata_lo[th][0]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                    r_vsrc_out[th][1] <= vector_src_decode(.src(vector_inst_in.src0), .ssrc_data('x), .vsrc_data(vgpr_rdata_hi[th][0]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                    // SRC1
                                    r_vsrc_out[th][2] <= vector_src_decode(.src(vector_inst_in.src1), .ssrc_data(sgpr_rdata_lo[0]), .vsrc_data(vgpr_rdata_lo[th][1]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                    r_vsrc_out[th][3] <= vector_src_decode(.src(vector_inst_in.src1), .ssrc_data(sgpr_rdata_hi[0]), .vsrc_data(vgpr_rdata_hi[th][1]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                    // SRC2
                                    r_vsrc_out[th][4] <= vector_src_decode(.src(vector_inst_in.src2), .ssrc_data(sgpr_rdata_lo[1]), .vsrc_data(vgpr_rdata_lo[th][2]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                    r_vsrc_out[th][5] <= vector_src_decode(.src(vector_inst_in.src2), .ssrc_data(sgpr_rdata_hi[1]), .vsrc_data(vgpr_rdata_hi[th][2]), .literal(vector_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                                end
                            end
                            default;
                        endcase
                    end
                end
                SCALAR_FLAG: begin
                    case (scalar_inst_in.format)
                        SOP2, SOP1, SOPC: begin
                            r_ssrc_out[0] <= scalar_src_decode(.src(scalar_inst_in.src0), .reg_rdata(sgpr_rdata_lo[0]), .literal(scalar_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                            r_ssrc_out[1] <= scalar_src_decode(.src(scalar_inst_in.src1), .reg_rdata(sgpr_rdata_lo[1]), .literal(scalar_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                            r_ssrc_out[2] <= scalar_src_decode(.src(scalar_inst_in.src0), .reg_rdata(sgpr_rdata_hi[0]), .literal(scalar_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                            r_ssrc_out[3] <= scalar_src_decode(.src(scalar_inst_in.src1), .reg_rdata(sgpr_rdata_hi[1]), .literal(scalar_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));
                        end
                        SOPK, SOPP: begin
                            r_ssrc_out[0] <= {{16{scalar_inst_in.imm16[15]}},scalar_inst_in.imm16}; 
                            r_ssrc_out[1] <= scalar_src_decode(.src({1'b0, scalar_inst_in.dst}), .reg_rdata(sgpr_rdata_lo[1]), .literal('x), .vccz('x), .scc('x), .execz('x)); // If DEST used by OP as SRC
                        end
                        default:;
                    endcase
                end
                FLAT_FLAG: begin
                    r_ssrc_out[0] <= sgpr_rdata_lo[0];
                    r_ssrc_out[1] <= sgpr_rdata_hi[1];
                    for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                        r_vsrc_out[th][0] <= vgpr_rdata_lo[th][0];
                        r_vsrc_out[th][1] <= vgpr_rdata_lo[th][1];
                        r_vsrc_out[th][2] <= vgpr_rdata_lo[th][2];
                        // r_vsrc_out[th][3] <= vgpr_rdata_lo[th][3]; // Unused
                    end
                end
                DS_FLAG: begin
                    for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                        r_vsrc_out[th][0] <= vgpr_rdata_lo[th][0]; // DATA
                        r_vsrc_out[th][1] <= vgpr_rdata_lo[th][1]; // DATA2
                        r_vsrc_out[th][2] <= vgpr_rdata_lo[th][2]; // ADDR 
                    end
                end
                EXPORT_FLAG: begin
                    // vector data is put in 4 vector src.  scalar exec value put in ssrc0 if needed (x otherwise)
                    // if export_inst_in.vm is 1, use scalar exec reg as mask.
                    if (export_inst_in.vm) begin
                        for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                            for (int gen_src_num=0; gen_src_num<VSRC_REG_CNT; gen_src_num++) begin
                                for (int i=0; i<VGPR_DATA_WIDTH; i++) begin
                                    if (sgpr_rdata_lo[0][i]) begin
                                        r_vsrc_out[th][gen_src_num][i] <= vgpr_rdata_lo[th][gen_src_num][i];
                                    end else begin
                                        r_vsrc_out[th][gen_src_num][i] <= 'x;
                                    end
                                end
                            end
                        end
                        r_ssrc_out[0] <= sgpr_rdata_lo[0];
                    end else begin
                        for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                            r_vsrc_out[th][0] <= vgpr_rdata_lo[th][0];
                            r_vsrc_out[th][1] <= vgpr_rdata_lo[th][1];
                            r_vsrc_out[th][2] <= vgpr_rdata_lo[th][2];
                            r_vsrc_out[th][3] <= vgpr_rdata_lo[th][3];
                        end
                        r_ssrc_out[0] <= 'x;
                    end
                end
                MIMG_FLAG: begin // FIXME: Will not be doing
                end
                MBUF_FLAG: begin
                    r_ssrc_out[0] <= scalar_src_decode(.src(mbuf_inst_in.soffset), .reg_rdata(sgpr_rdata_lo[0]), .literal(scalar_inst_in.literal), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));;
                    r_ssrc_out[1] <= '0; // Can use to convey other info
                    r_ssrc_out[2] <= '0; // Can use to convey other info
                    r_ssrc_out[3] <= '0;  // Can use to convey other info

                    for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin // Voffset and Vindex
                        r_vsrc_out[th][4] <= vgpr_rdata_lo[th][0];
                        r_vsrc_out[th][5] <= vgpr_rdata_lo[th][1];
                    end
                end
                SMEM_FLAG: begin
                    r_ssrc_out[0] <= scalar_src_decode(.src({2'b00, smem_inst_in.sbase}<<1), .reg_rdata(sgpr_rdata_lo[0]), .literal(0), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));;
                    // r_ssrc_out[0] <= sgpr_rdata_lo[0];
                    // r_ssrc_out[1] <= {11'b0, smem_inst_in.offset};
                    r_ssrc_out[2] <= scalar_src_decode(.src({1'b0, smem_inst_in.soffset}), .reg_rdata(sgpr_rdata_lo[1]), .literal(0), .vccz(vccz[wavefront_num_in]), .scc(scc[wavefront_num_in]), .execz(execz[wavefront_num_in]));;
                    // r_ssrc_out[2] <= sgpr_rdata_lo[1];
                    // r_ssrc_out[3] <= {25'b0, smem_inst_in.sdata};
                end
                default:;
            endcase
        end
    end

    // Misc Signals
    always_ff @(posedge clk) begin
        if (reset) begin
            r_all_flag <= '0;
        end else begin
            r_all_flag <= dec_ex1_all_flags;
        end
    end

    assign wavefront_num_out = r_curr_wavefront;
    always_ff @(posedge clk) begin
        if (reset) begin
            r_curr_wavefront <= '0;
        end else begin
            r_curr_wavefront <= wavefront_num_in;
        end
    end

    always_comb begin
        assert($onehot0(dec_ex1_all_flags)) else $error("More than 1 flag is being set by decoder, ERROR");
    end

endmodule

module simd32_ex2
import common_pkg::*;
import mem_pkg::*;
import ex_pkg::*;
import scalar_op_pkg::SOP2_LSHL_B64;
import flat_op_pkg::*;
import ds_op_pkg::*;
import vector_op_pkg::*;
(
    input  logic clk,
    input  logic reset,

    // EX1 - EX2 Interface
    input  vector_inst_t    vector_inst_in,
    input  scalar_inst_t    scalar_inst_in,
    input  flat_inst_t      flat_inst_in,
    input  ds_inst_t        ds_inst_in,
    input  export_inst_t    export_inst_in,
    input  mimg_inst_t      mimg_inst_in,
    input  mbuf_inst_t      mbuf_inst_in,
    input  smem_inst_t      smem_inst_in,

    input  logic [SSRC_REG_CNT-1:0][SGPR_DATA_WIDTH-1:0] ssrc_in,
    input  logic [THREADS_PER_WAVEFRONT-1:0][VSRC_REG_CNT-1:0][VGPR_DATA_WIDTH-1:0] vsrc_in,

    input  logic [ALL_FLAG_WIDTH-1:0] ex1_ex2_all_flags,

    input  logic [WAVEFRONT_WIDTH-1:0] wavefront_num_in,

    output logic ex2_ex1_ready,
    input  logic ex1_ex2_valid,

    // EX2 - LS Interface
    input  logic ls_ex2_ready,
    output logic ex2_ls_valid,

    output logic                        ex2_ls_mem_en,
    output logic                        ex2_ls_mem_we,
    output logic [1:0]                  ex2_ls_mem_wstrb,
    output logic [SRAM_DATA_WIDTH-1:0]  ex2_ls_mem_wdata,
    output logic [SRAM_ADDR_WIDTH-1:0]  ex2_ls_mem_addr,

    output logic [THREADS_PER_WAVEFRONT-1:0]                       ex2_ls_vmem_en,
    output logic [THREADS_PER_WAVEFRONT-1:0]                       ex2_ls_vmem_we,
    output logic [THREADS_PER_WAVEFRONT-1:0][1:0]                  ex2_ls_vmem_wstrb,
    output logic [THREADS_PER_WAVEFRONT-1:0][SRAM_DATA_WIDTH-1:0]  ex2_ls_vmem_wdata,
    output logic [THREADS_PER_WAVEFRONT-1:0][SRAM_ADDR_WIDTH-1:0]  ex2_ls_vmem_addr,
    output logic                                                   ex2_ls_vmem_lds,

    output logic [WAVEFRONT_WIDTH-1:0]  wavefront_num_out,

    output logic [SGPR_ADDR_WIDTH-1:0]   ex2_ls_s_dest_reg,
    output logic [SGPR_DATA_WIDTH*2-1:0] ex2_ls_s_dest_val,
    output logic [1:0]                   ex2_ls_s_dest_strb, // For 32bit LSB and 32bit MSB
    output logic                         ex2_ls_s_dest_we,

    output logic [VGPR_ADDR_WIDTH-1:0]                             ex2_ls_v_dest_reg,
    output logic [THREADS_PER_WAVEFRONT-1:0][VGPR_DATA_WIDTH*2-1:0]ex2_ls_v_dest_val,
    output logic [1:0]                                             ex2_ls_v_dest_strb,
    output logic [THREADS_PER_WAVEFRONT-1:0]                       ex2_ls_v_dest_we,

    // REG Interface
    input   logic [MAX_WAVEFRONT_CNT-1:0]       scc,
    output  logic [MAX_WAVEFRONT_CNT-1:0]       scc_data,
    output  logic [MAX_WAVEFRONT_CNT-1:0]       scc_we,

    input   logic [MAX_WAVEFRONT_CNT-1:0][47:0] pc,
    output  logic [MAX_WAVEFRONT_CNT-1:0][47:0] pc_data,
    output  logic [MAX_WAVEFRONT_CNT-1:0]       pc_we,

    input   logic [MAX_WAVEFRONT_CNT-1:0]       active,
    output  logic [MAX_WAVEFRONT_CNT-1:0]       active_data,
    output  logic [MAX_WAVEFRONT_CNT-1:0]       active_we,

    input   logic [MAX_WAVEFRONT_CNT-1:0]       barrier,
    output  logic [MAX_WAVEFRONT_CNT-1:0]       barrier_data,
    output  logic [MAX_WAVEFRONT_CNT-1:0]       barrier_we,

    input   logic [MAX_WAVEFRONT_CNT-1:0]       vccz,
    input   logic [MAX_WAVEFRONT_CNT-1:0][THREADS_PER_WAVEFRONT-1:0] vcc,
    output  logic                               vcc_we,
    output  logic [THREADS_PER_WAVEFRONT-1:0]   vcc_data,

    input   logic [MAX_WAVEFRONT_CNT-1:0][THREADS_PER_WAVEFRONT-1:0] exec,
    input   logic [MAX_WAVEFRONT_CNT-1:0]       execz
);

    // Execute Localparams
    // localparam ROUND_DOWN_TWO_BIT = 32'hFFFFFFFC;

    // Misc. Signals
    logic [ALL_FLAG_WIDTH-1:0] all_flag;
    logic [WAVEFRONT_WIDTH-1:0] r_wavefront_num;

    // Memory Intermediate Signals
    logic                        r_mem_en;
    logic                        r_mem_we;
    logic [SRAM_DATA_WIDTH-1:0]  r_mem_wdata;
    logic [1:0]                  r_mem_wstrb;
    logic [SRAM_ADDR_WIDTH-1:0]  r_mem_addr;
    logic [4:0]                  r_smem_already_sent;

    logic [THREADS_PER_WAVEFRONT-1:0]                       r_vmem_en;
    logic [THREADS_PER_WAVEFRONT-1:0]                       r_vmem_we;
    logic [THREADS_PER_WAVEFRONT-1:0][SRAM_DATA_WIDTH-1:0]  r_vmem_wdata;
    logic [THREADS_PER_WAVEFRONT-1:0][1:0]                  r_vmem_wstrb;
    logic [THREADS_PER_WAVEFRONT-1:0][SRAM_ADDR_WIDTH-1:0]  r_vmem_addr;
    logic                                                   r_vmem_lds;

    // SGPR/VGPR Intermediate Signals
    logic [SGPR_ADDR_WIDTH-1:0]   r_s_dest_reg;
    logic [SGPR_DATA_WIDTH*2-1:0] r_s_dest_val, s_dest_val;
    logic [1:0]                   r_s_dest_strb;
    logic                         r_s_dest_we;

    logic [SGPR_DATA_WIDTH*2-1:0] r_v_s_dest_val;
    logic                         r_v_s_dest_we;

    logic [VGPR_ADDR_WIDTH-1:0]                                 r_v_dest_reg;
    logic [THREADS_PER_WAVEFRONT-1:0][VGPR_DATA_WIDTH*2-1:0]    r_v_dest_val;
    logic [THREADS_PER_WAVEFRONT-1:0]                           r_v_dest_we;
    logic [1:0]                                                 r_v_dest_strb;

    // Status Intermediate Signals
    logic r_scc, next_scc;
    logic r_scc_we, next_scc_we;

    logic [47:0] r_pc, next_pc;
    logic r_pc_we, next_pc_we;

    logic r_barrier, next_barrier;
    logic r_barrier_we, next_barrier_we;

    logic r_active, next_active;
    logic r_active_we, next_active_we;

    // MISC
    logic next_vec_busy, r_vec_busy;
    logic next_smem_stall, r_smem_stall;
    logic next_ds_stall, r_ds_stall;
    logic stall;

    logic r_ex2_ls_valid;
    logic r_v_data_valid;

    // Execution Logic
    assign all_flag = ex1_ex2_all_flags;

    assign ex2_ls_mem_en    = r_mem_en;
    assign ex2_ls_mem_we    = r_mem_we;
    assign ex2_ls_mem_wdata = r_mem_wdata;
    assign ex2_ls_mem_addr  = r_mem_addr;
    assign ex2_ls_mem_wstrb = r_mem_wstrb;

    assign ex2_ls_vmem_en    = r_vmem_en;
    assign ex2_ls_vmem_we    = r_vmem_we;
    assign ex2_ls_vmem_wdata = r_vmem_wdata;
    assign ex2_ls_vmem_addr  = r_vmem_addr;
    assign ex2_ls_vmem_wstrb = r_vmem_wstrb;
    assign ex2_ls_vmem_lds   = r_vmem_lds;

    assign ex2_ls_s_dest_reg = r_s_dest_reg;
    assign ex2_ls_s_dest_val = r_v_data_valid ? r_v_s_dest_val : r_s_dest_val;
    assign ex2_ls_s_dest_strb= r_s_dest_strb;
    assign ex2_ls_s_dest_we  = r_s_dest_we | r_v_s_dest_we;

    assign ex2_ls_v_dest_reg = r_v_dest_reg;
    assign ex2_ls_v_dest_val = r_v_dest_val;
    assign ex2_ls_v_dest_we  = r_v_dest_we;
    assign ex2_ls_v_dest_strb = r_v_dest_strb;

    assign stall = r_ds_stall || r_smem_stall || r_vec_busy || (ex2_ls_valid && ~ls_ex2_ready);
    assign ex2_ls_valid = r_ex2_ls_valid || r_v_data_valid;

    always_ff @(posedge clk) begin // 2nd Stage - Execution Stage
        if (reset) begin
            r_mem_en        <= '0;
            r_mem_we        <= '0;
            r_mem_wdata     <= '0;
            r_mem_wstrb     <= '0;
            r_mem_addr      <= '0;
            r_smem_already_sent <= 0;
            r_vmem_en       <= '0;
            r_vmem_we       <= '0;
            r_vmem_wdata    <= '0;
            r_vmem_wstrb    <= '0;
            r_vmem_addr     <= '0;
            r_vmem_lds      <= '0;
            r_s_dest_reg    <= '0;
            r_s_dest_reg    <= '0;
            r_s_dest_val    <= '0;
            r_s_dest_we     <= '0;
            r_s_dest_strb   <= '0;
            r_v_dest_reg    <= '0;
            r_v_dest_strb   <= '0;
            r_ds_stall      <= '0;
            r_smem_stall    <= '0;
            r_ex2_ls_valid  <= '0;
        end else begin
            r_ex2_ls_valid <= ex1_ex2_valid && ex2_ex1_ready;

            if (~stall) begin
                r_mem_en        <= '0;
                r_mem_we        <= '0;
                r_mem_wdata     <= '0;
                r_mem_wstrb     <= '0;
                r_mem_addr      <= '0;
                r_smem_already_sent <= 0;
                r_vmem_en       <= '0;
                r_vmem_we       <= '0;
                r_vmem_wdata    <= '0;
                r_vmem_wstrb    <= '0;
                r_vmem_addr     <= '0;
                r_vmem_lds      <= '0;
                r_s_dest_reg    <= '0;
                r_s_dest_reg    <= '0;
                r_s_dest_val    <= '0;
                r_s_dest_we     <= '0;
                r_s_dest_strb   <= '0;
                r_v_dest_reg    <= '0;
                r_ds_stall      <= '0;
                r_smem_stall    <= '0;
                r_v_dest_strb   <= '0;

                case (all_flag)
                    SCALAR_FLAG: begin
                        case (scalar_inst_in.format)
                            SOP2, SOP1, SOPK: begin
                                r_s_dest_reg    <= scalar_inst_in.dst;
                                r_s_dest_val    <= s_dest_val ;
                                r_s_dest_we     <= 1'b1;
                                r_s_dest_strb   <= 2'b01;

                                if (scalar_inst_in.op == SOP2_LSHL_B64) begin // Clashes with S_GETPC_B64 but is fine since both are 64bit
                                    r_s_dest_strb     <= 2'b11;
                                end
                            end
                            SOPC: begin
                                // Nothing here, SOPC only affects SCC
                            end
                            SOPP: begin
                                // S_NOP/S_ENDPRG fairly straightforward Do nothing, maybe add a halt for S_ENDPRG - DONE

                                // S_WAITCNT - We need to have global counts for outstandings LDS, VMEM, and EXPORT instructions - FIXME: To be implemented

                                // S_CLAUSE - We need a global reg that indicates a clause is active and we cannot change wavefronts - Needs to be done by scheduler
                            end
                            default:;
                        endcase
                    end
                    SMEM_FLAG: begin
                        //  Spec says "All components of the address (base, offset, inst_offset, M0) are in bytes, but the two LSBs areignored and treated as if they were zero."
                        //  Unsure if that means all components are rounded down or result is rounded down?
                        // Assuming components are rounded, not result.
                        // ADDR = SGPR[base << 1] + inst_offset + { M0 or SGPR[soffset] or zero }
                        // src[0] contains SGPR[base << 1], src[2] contains SGPR[soffset]

                        // r_mem_addr <= (ssrc_in[0] + ssrc_in[1] + ssrc_in[2]) & (ROUND_DOWN_TWO_BIT);
                        // r_s_dest_reg <= ssrc_in[3];

                        r_mem_addr <= ssrc_in[0] + { {11{smem_inst_in.offset[20]}}, smem_inst_in.offset} + ssrc_in[2];
                        r_s_dest_reg <= smem_inst_in.sdata;
                        r_mem_we <= 0;      // we currently only support load instructions
                        r_mem_en <= 1;

                        if (smem_inst_in.op[2:0] > 1) begin
                            r_mem_wstrb <= 2'b11;;
                            r_smem_already_sent <= 2;
                        end else begin
                            if (smem_inst_in.op == 0) begin
                                r_mem_wstrb <= 2'b01;
                            end else begin
                                r_mem_wstrb <= 2'b11;
                            end
                        end

                        r_smem_stall <= next_smem_stall;
                    end
                    VECTOR_FLAG: begin
                        case (vector_inst_in.format)
                            VOP2, VOP1: begin
                                r_v_dest_reg    <= vector_inst_in.vdst;
                                r_v_dest_strb   <= 2'b01;
                            end
                            VOPC: begin
                                // Nothing here, VOPC only affects VCC
                            end
                            VOP3: begin
                                r_v_dest_reg    <= vector_inst_in.vdst;
                                r_v_dest_strb   <= 2'b01;
                                // Change write strobe if 64-bit instruction
                                if (vector_inst_in.op == V_MAD_U64_U32 || vector_inst_in.op == V_LSHLREV_B64) begin
                                    r_v_dest_strb   <= 2'b11;
                                end

                                // Write to SGPR for VOP3B instructions
                                r_s_dest_reg    <= vector_inst_in.sdst;
                                r_s_dest_strb   <= 2'b01;
                            end
                            VINTRP, VOP3P: begin
                                // Not currently implemented
                            end
                            default:;
                        endcase
                    end
                    FLAT_FLAG: begin
                        // • FLAT
                        //  a. VGPR (32 or 64 bit) supplies the complete address. SADDR must be NULL.
                        // • Global
                        //  a. VGPR (32 or 64 bit) supplies the address. Indicated by: SADDR == NULL.
                        //  b. SGPR (64 bit) supplies an address, and a VGPR (32 bit) supplies an offset
                        // • SCRATCH
                        //  a. VGPR (32 bit) supplies an offset. Indicated by SADDR==NULL.
                        for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                            case (flat_inst_in.seg)
                                2'b00: begin // FLAT
                                end
                                2'b01: begin // SCRATCH
                                end
                                2'b10: begin // GLOBAL
                                    if (flat_inst_in.saddr == NULL_ADDR[6:0]) begin
                                        r_vmem_addr[th] <= vsrc_in[th][0] + {{20{flat_inst_in.offset[11]}}, flat_inst_in.offset};
                                    end else begin
                                        r_vmem_addr[th] <= ssrc_in[0] + vsrc_in[th][0] + {{20{flat_inst_in.offset[11]}}, flat_inst_in.offset}; // We are supposed to use 64bit from SGPRs, but our SRAM is 32bit addressed.
                                    end

                                    r_vmem_wdata[th] <= {vsrc_in[th][2], vsrc_in[th][1]};

                                    case (flat_inst_in.op)
                                        GLOBAL_LOAD_DWORD: begin
                                            r_vmem_wstrb[th] <= 2'b01;
                                            r_vmem_en[th] <= 1'b1;
                                        end
                                        GLOBAL_LOAD_DWORDX2: begin
                                            r_vmem_wstrb[th] <= 2'b11;
                                            r_vmem_en[th] <= 1'b1;
                                        end
                                        GLOBAL_STORE_DWORD: begin
                                            r_vmem_wstrb[th] <= 2'b01;
                                            r_vmem_en[th] <= 1'b1;
                                            r_vmem_we[th] <= 1'b1;
                                        end
                                        default:;
                                    endcase
                                end
                                2'b11: begin // RSVD
                                end
                                default:;
                            endcase
                        end
                    end
                    DS_FLAG: begin
                        r_vmem_lds <= ~ds_inst_in.gds;

                        for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                                case (ds_inst_in.op) 
                                    DS_WRITE_B32: begin
                                        r_vmem_en[th] <= 1'b1;
                                        r_vmem_we[th] <= 1'b1;
                                        r_vmem_wstrb[th] <= 2'b01;
                                        r_vmem_addr[th] <= vsrc_in[th][2];
                                        r_vmem_wdata[th] <= {32'h0, vsrc_in[th][0]};
                                    end
                                    DS_WRITE2_B32: begin
                                        r_vmem_en[th] <= 1'b1;
                                        r_vmem_we[th] <= 1'b1;
                                        r_vmem_wstrb[th] <= 2'b01;
                                        r_vmem_addr[th] <= vsrc_in[th][2] + (ds_inst_in.offset0 * 4);
                                        r_vmem_wdata[th] <= {32'h0, vsrc_in[th][0]};
                                        r_ds_stall <= next_ds_stall;
                                    end
                                    DS_READ_B32: begin
                                        r_vmem_en[th] <= 1'b1;
                                        r_vmem_we[th] <= 1'b0;
                                        r_vmem_wstrb[th] <= 2'b01;
                                        r_vmem_addr[th] <= vsrc_in[th][2];
                                    end 
                                    DS_READ2_B32: begin
                                        r_vmem_en[th] <= 1'b1;
                                        r_vmem_we[th] <= 1'b0;
                                        r_vmem_wstrb[th] <= 2'b01;
                                        r_vmem_addr[th] <= vsrc_in[th][2] + (ds_inst_in.offset0 * 4);
                                        r_ds_stall <= next_ds_stall;
                                    end
                                    default:;
                                endcase
                        end
                    end
                    EXPORT_FLAG: begin

                    end
                    MIMG_FLAG: begin // FIXME: Not doing this instr.
                    end
                    MBUF_FLAG: begin

                    end
                default: ;
                endcase
            end else begin
                if (r_ds_stall) begin
                    r_ds_stall <= 1'b0;
                    r_vmem_lds <= ~ds_inst_in.gds;
                    for (int th = 0; th < THREADS_PER_WAVEFRONT; th++) begin
                        case (ds_inst_in.op)
                            DS_READ2_B32: begin
                                r_vmem_en[th] <= 1'b1;
                                r_vmem_we[th] <= 1'b0;
                                r_vmem_wstrb[th] <= 2'b00;
                                r_vmem_addr[th] <= vsrc_in[th][2] + (ds_inst_in.offset1 * 4);
                            end
                            DS_WRITE2_B32: begin
                                r_vmem_en[th] <= 1'b1;
                                r_vmem_we[th] <= 1'b1;
                                r_vmem_wstrb[th] <= 2'b01;
                                r_vmem_addr[th] <= vsrc_in[th][2] + (ds_inst_in.offset1 * 4);
                                r_vmem_wdata[th] <= {32'h0, vsrc_in[th][1]};
                            end
                            default:;
                        endcase
                    end
                end else if (r_smem_stall) begin
                    r_mem_addr <= ssrc_in[0] + { {11{smem_inst_in.offset[20]}}, smem_inst_in.offset} + ssrc_in[2] + ({27'b0, r_smem_already_sent} << $clog2(DWORD_WIDTH));
                    r_s_dest_reg <= smem_inst_in.sdata;
                    r_mem_we <= 0;      // we currently only support load instructions
                    r_mem_en <= 1;
                    r_mem_wstrb <= 2'b11;;

                    if (r_smem_already_sent + 2 == (1 << smem_inst_in.op[2:0])) begin   // is there only 2 dwords left in this instruction, we are done and reseting the counter
                        r_smem_already_sent <= 0;
                    end else begin
                        r_smem_already_sent <= r_smem_already_sent + 2;
                    end

                    r_smem_stall <= next_smem_stall;
                end
            end
        end
    end

    (* use_dsp = "yes" *) execute_scalar u_execute_scalar (
        .scalar_inst_in(scalar_inst_in),
        .src0(ssrc_in[0]),
        .src1(ssrc_in[1]),
        .src2(ssrc_in[2]), // MSB of src0
        .src3(ssrc_in[3]), // MSB of src1
        .scc_in(scc[wavefront_num_in]),
        .pc_in(pc[wavefront_num_in]),
        .vccz_in(vccz[wavefront_num_in]),
        .execz_in(execz[wavefront_num_in]),
        .dest_value(s_dest_val[SGPR_DATA_WIDTH-1:0]),
        .dest_value_upper_32(s_dest_val[SGPR_DATA_WIDTH*2-1:SGPR_DATA_WIDTH]),
        .scc(next_scc),
        .scc_we(next_scc_we),
        .pc(next_pc),
        .pc_we(next_pc_we),
        .active(next_active),
        .active_we(next_active_we),
        .barrier(next_barrier),
        .barrier_we(next_barrier_we)
    );

    execute_vector_core32 u_execute_vector (
        .clk(clk),
        .rst(reset),
        .vector_inst_in(vector_inst_in & {$bits(vector_inst_t){ex1_ex2_valid}} & {$bits(vector_inst_t){all_flag == VECTOR_FLAG}}),
        .vsrc(vsrc_in),
        .vcc(vcc[wavefront_num_in]),
        .exec(exec[wavefront_num_in]),
        .vdst(r_v_dest_val),
        .vdst_wb(r_v_dest_we),
        .sdst_lo(r_v_s_dest_val[SGPR_DATA_WIDTH-1:0]),
        .sdst_hi(r_v_s_dest_val[SGPR_DATA_WIDTH*2-1:SGPR_DATA_WIDTH]),
        .sdst_wb(r_v_s_dest_we),
        .vcc_data(vcc_data),
        .vcc_wb(vcc_we),

        .out_ready(ls_ex2_ready),
        .out_valid(r_v_data_valid),
        .busy(r_vec_busy),
        .next_busy(next_vec_busy)
    );


    // SCC + VCC + Wavefront
    assign wavefront_num_out = r_wavefront_num;
    always_ff @(posedge clk) begin
        if (reset) begin
            r_scc <= '0;
            r_scc_we <= '0;
            r_pc <= '0;
            r_pc_we <= '0;
            r_active <= '0;
            r_active_we <= '0;
            r_barrier <= '0;
            r_barrier_we <= '0;
            r_wavefront_num <= '0;
        end else begin
            r_scc <= next_scc;
            r_scc_we <= next_scc_we;
            r_pc <= next_pc;
            r_pc_we <= next_pc_we;
            r_active <= next_active;
            r_active_we <= next_active_we;
            r_wavefront_num <= wavefront_num_in;
        end
    end

    always_comb begin
        scc_we = '0;
        scc_data = '0;
        pc_we = '0;
        pc_data = '0;
        active_we = '0;
        active_data = '0;
        barrier_we = '0;
        barrier_data = '0;

        scc_we[r_wavefront_num] = r_scc_we;
        scc_data[r_wavefront_num] = r_scc;
        pc_we[r_wavefront_num] = r_pc_we;
        pc_data[r_wavefront_num] = r_pc;
        active_we[r_wavefront_num] = r_active_we;
        active_data[r_wavefront_num] = r_active;
        barrier_we[r_wavefront_num] = r_barrier_we;
        barrier_data[r_wavefront_num] = r_barrier;
    end


    always_comb begin
        next_ds_stall = 1'b0;
        next_smem_stall = 1'b0;

        if (~r_ds_stall) begin
            if (all_flag == DS_FLAG) begin
                case (ds_inst_in.op) 
                    DS_WRITE2_B32, DS_READ2_B32: next_ds_stall = 1'b1;
                    default:;
                endcase
            end
        end

        if (all_flag == SMEM_FLAG) begin
            if (r_smem_already_sent + 2 < (1 << smem_inst_in.op[2:0])) begin   // is there more than 2 dwords left in this instruction
                next_smem_stall = 1'b1;
            end else begin
                next_smem_stall = 1'b0;
            end
        end else begin
            next_smem_stall = 1'b0;
        end
    end

    // Ready - Valid
    always_comb begin
        if (next_ds_stall || next_smem_stall || next_vec_busy) begin
            ex2_ex1_ready = 1'b0;
        end else begin
            ex2_ex1_ready = 1'b1;
        end
    end
    
endmodule

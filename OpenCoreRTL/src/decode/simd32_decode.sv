module simd32_decode
import common_pkg::*;
import ex_pkg::*;
(
    input logic clk,
    input logic reset,

    // Instruction
    input logic [31:0] inst,

    // Current_wavefront
    input  logic [WAVEFRONT_WIDTH-1:0] wavefront_num_in,
    output logic [WAVEFRONT_WIDTH-1:0] wavefront_num_out,

    // Decoder Stall (Backpressures Fetch)
    output logic         decoder_stall,

    // Output to Instruction Controller (vector)
    output logic [ALL_FLAG_WIDTH-1:0]   dec_ex1_all_flags,
    output vector_inst_t vector_inst_out,
    output scalar_inst_t scalar_inst_out,
    output flat_inst_t   flat_inst_out,
    output ds_inst_t     ds_inst_out,
    output export_inst_t export_inst_out,
    output mimg_inst_t   mimg_inst_out,
    output mbuf_inst_t   mbuf_inst_out,
    output smem_inst_t   smem_inst_out,

    // Ready - Valid Interface to Instruction Controller
    output logic dec_ex1_valid,
    input  logic ex1_dec_ready
);

    // Signal Instantiations
    logic scalar_reset;
    logic vector_reset;
    logic flat_reset;
    logic ds_reset;
    logic export_reset;
    logic mimg_reset;
    logic mbuf_reset;
    logic smem_reset;

    logic scalar_busy;
    logic vector_busy;
    logic flat_busy;
    logic ds_busy;
    logic export_busy;
    logic mimg_busy;
    logic mbuf_busy;
    logic smem_busy;

    logic scalar_flag;
    logic vector_flag;
    logic flat_flag;
    logic ds_flag;
    logic export_flag;
    logic mimg_flag;
    logic mbuf_flag;
    logic smem_flag;

    logic busy_broadcast;

    logic [$clog2(MAX_WAVEFRONT_CNT)-1:0] r_wavefront_num;

    // Decode modules
    assign dec_ex1_all_flags = {vector_flag, scalar_flag, flat_flag, ds_flag, export_flag, mimg_flag, mbuf_flag, smem_flag};
    assign busy_broadcast = scalar_busy || vector_busy || flat_busy || ds_busy || export_busy || mimg_busy || mbuf_busy || smem_busy; 

    assign scalar_reset = reset || (busy_broadcast && !scalar_busy);
    assign vector_reset = reset || (busy_broadcast && !vector_busy);
    assign flat_reset   = reset || (busy_broadcast && !flat_busy);
    assign ds_reset     = reset || (busy_broadcast && !ds_busy);
    assign export_reset = reset || (busy_broadcast && !export_busy);
    assign mimg_reset   = reset || (busy_broadcast && !mimg_busy);
    assign mbuf_reset   = reset || (busy_broadcast && !mbuf_busy);
    assign smem_reset   = reset || (busy_broadcast && !smem_busy);

    decode_scalar scalar_decode (
        .clk(clk),
        .reset(scalar_reset),
        .inst(inst),
        .stall(decoder_stall),
        .scalar_inst_out(scalar_inst_out),
        .valid(scalar_flag),
        .busy(scalar_busy)
    );

    decode_vector vector_decode (
        .clk(clk),
        .reset(vector_reset),
        .inst(inst),
        .stall(decoder_stall),
        .vector_inst_out(vector_inst_out),
        .valid(vector_flag),
        .busy(vector_busy)
    );

    decode_flat flat_decode (
        .clk(clk),
        .reset(flat_reset),
        .inst(inst),
        .stall(decoder_stall),
        .flat_inst_out(flat_inst_out),
        .valid(flat_flag),
        .busy(flat_busy)
    );

    decode_ds ds_decode (
        .clk(clk),
        .reset(ds_reset),
        .inst(inst),
        .stall(decoder_stall),
        .ds_inst_out(ds_inst_out),
        .valid(ds_flag),
        .busy(ds_busy)
    );

    decode_export export_decode (
        .clk(clk),
        .reset(export_reset),
        .inst(inst),
        .stall(decoder_stall),
        .export_inst_out(export_inst_out),
        .valid(export_flag),
        .busy(export_busy)
    );

    decode_mimg mimg_decode (
        .clk(clk),
        .reset(mimg_reset),
        .inst(inst),
        .stall(decoder_stall),
        .mimg_inst_out(mimg_inst_out),
        .valid(mimg_flag),
        .busy(mimg_busy)
    );

    decode_mbuf mbuf_decode (
        .clk(clk),
        .reset(mbuf_reset),
        .inst(inst),
        .stall(decoder_stall),
        .mbuf_inst_out(mbuf_inst_out),
        .valid(mbuf_flag),
        .busy(mbuf_busy)
    );

    decode_smem smem_decode (
        .clk(clk),
        .reset(smem_reset),
        .inst(inst),
        .stall(decoder_stall),
        .smem_inst_out(smem_inst_out),
        .valid(smem_flag),
        .busy(smem_busy)
    );


    // Set valid flag
    assign dec_ex1_valid = vector_flag | scalar_flag | flat_flag | ds_flag | export_flag | mbuf_flag | mimg_flag | smem_flag;

    always_comb begin : instr_cntrl_handshake
        decoder_stall = 1'b0;

        if (dec_ex1_valid && !ex1_dec_ready) begin
            // Handshake not complete, instruction controller backpressures decoders
            decoder_stall = 1'b1;
        end
    end

    assign wavefront_num_out = r_wavefront_num;
    always_ff @( posedge clk ) begin
        if (reset) begin
            r_wavefront_num <= '0;
        end else begin
            r_wavefront_num <= wavefront_num_in;
        end
    end

endmodule

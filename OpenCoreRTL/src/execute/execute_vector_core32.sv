module execute_vector_core32
import common_pkg::*;
import mem_pkg::*;
(
    input clk,
    input rst,

    // Interface from next stage
    input logic                             out_ready,

    // Interface to previous stage
    output logic                            out_valid,
    output logic                            busy,
    output logic                            next_busy,

    // Inputs
    input vector_inst_t vector_inst_in,
    input logic [THREADS_PER_WAVEFRONT-1:0][VSRC_REG_CNT-1:0][VGPR_DATA_WIDTH-1:0] vsrc,
    input logic [THREADS_PER_WAVEFRONT-1:0] vcc,
    input logic [THREADS_PER_WAVEFRONT-1:0] exec,

    // Outputs
    output logic [THREADS_PER_WAVEFRONT-1:0][VGPR_DATA_WIDTH*2-1:0] vdst,
    output logic [THREADS_PER_WAVEFRONT-1:0] vdst_wb,
    output logic [SGPR_DATA_WIDTH-1:0] sdst_lo,
    output logic [SGPR_DATA_WIDTH-1:0] sdst_hi,
    output logic sdst_wb,

    output logic [THREADS_PER_WAVEFRONT-1:0] vcc_data,
    output logic                             vcc_wb
);

logic [THREADS_PER_WAVEFRONT-1:0] vcc_out;
logic [THREADS_PER_WAVEFRONT-1:0] vcc_we;
logic [THREADS_PER_WAVEFRONT-1:0] vdst_wb_local;
logic [THREADS_PER_WAVEFRONT-1:0] sdst_wb_local;
logic [THREADS_PER_WAVEFRONT-1:0][SGPR_DATA_WIDTH-1:0] sdst_data_lo;
logic [THREADS_PER_WAVEFRONT-1:0][SGPR_DATA_WIDTH-1:0] sdst_data_hi;
logic [THREADS_PER_WAVEFRONT-1:0] out_valid_local;
logic [THREADS_PER_WAVEFRONT-1:0] busy_local, next_busy_local;

// Connect the outputs and ensure only using data for enabled vector units
assign vcc_data = exec & vcc_out;
assign vcc_wb = |(exec & vcc_we);
assign vdst_wb = exec & vdst_wb_local;
assign sdst_wb = |(exec & sdst_wb_local);
assign out_valid = |(exec & out_valid_local);
assign busy = |(exec & busy_local);
assign next_busy = |(exec & next_busy_local);

always_comb begin
    sdst_lo = '0;
    sdst_hi = '0;
    for (int j = 0; j < THREADS_PER_WAVEFRONT; j++) begin
        sdst_lo[j] = exec[j] & sdst_data_lo[j][0];
    end
end

// Generate all the vector cores
genvar i;
generate
    for (i = 0; i < THREADS_PER_WAVEFRONT; i++) begin : gen_VCORES
        execute_vector_core vec_core (
            .clk(clk),
            .rst(rst),

            // Inputs
            .vector_inst_in(vector_inst_in),
            .ssrc0({vsrc[i][1], vsrc[i][0]}), // SSRC0 = {vsrc[1], vsrc[0]}
            .ssrc1({vsrc[i][3], vsrc[i][2]}), // SSRC1 = {vsrc[3], vsrc[2]}
            .ssrc2({vsrc[i][5], vsrc[i][4]}), // SSRC2 = {vsrc[5], vsrc[4]}
            .vsrc(vsrc[i][2]),                // For VOP2: VSRC1 = {vsrc[2]} as only 32-bit
            .dst_data(vsrc[i][4]),            // For MAC Instructions: DST_DATA = SSRC2[31:0] = {vsrc[4]}
            .vcc_in(vcc[i]),

            // Outputs
            .vcc_out(vcc_out[i]),
            .vcc_we(vcc_we[i]),
            .vdest_out(vdst[i]),
            .vdest_wb(vdst_wb_local[i]),
            .sdest_out({sdst_data_hi[i], sdst_data_lo[i]}),
            .sdest_wb(sdst_wb_local[i]),

            // Busy/Valid/Ready Signals
            .out_valid(out_valid_local[i]),
            .busy(busy_local[i]),
            .next_busy(next_busy_local[i]),
            .out_ready(out_ready)
        );
    end
endgenerate

endmodule

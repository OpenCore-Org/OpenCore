/*

Decoder for Data Share Instructions (LDS and GDS)

Local data share (LDS) is a very low-latency, RAM scratchpad for temporary data with at least
one order of magnitude higher effective bandwidth than direct, uncached global memory. It
permits sharing of data between work-items in a work-group, as well as holding parameters for
pixel shader parameter interpolation. Unlike read-only caches, the LDS permits high-speed
write-to-read re-use of the memory space (gather/read/load and scatter/write/store operations).

Global data share is similar to LDS, but is a single memory accessible by all waves on the GPU.
Global Data share uses the same instruction format as local data share (indexed operations
only – no interpolation or direct reads). Instructions increment the LGKM_cnt for all reads, writes
and atomics, and decrement LGKM_cnt when the instruction completes.

!! FIXME (Joey): Confirm with the decompiled RDNA code to confirm where the "blank" bit is located

*/

module decode_ds 
import common_pkg::*;
(
    input clk,
    input reset,

    // Instruction
    input  [31:0] inst,

    // Decoder Stall
    input         stall,

    // Output to Instruction Controller
    output ds_inst_t ds_inst_out,

    // Ready - Valid Interface to Instruction Controller
    output valid,

    // Busy Interface to Main Decode Module
    output busy
);

localparam DS_BUSY = 1'b1;
localparam DS_REST = 1'b0;

// Signal Instantiations
logic       is_ds_inst;
logic       next_state;
logic       r_curr_state;
logic       r_valid;
ds_inst_t r_ds_inst_out;

assign ds_inst_out = r_ds_inst_out;
assign is_ds_inst = (inst[31:26] == 6'b110110);
assign busy = (r_curr_state == DS_BUSY);
assign valid = r_valid;

always_ff @(posedge clk) begin
    if (reset) begin
        r_ds_inst_out <= '0;
        r_valid <= '0;
    end else begin
        if (!stall) begin
            unique case (r_curr_state)
                DS_REST: begin
                    r_valid <= 1'b0;
                    if (is_ds_inst) begin // First 4-byte chunk
                        r_ds_inst_out.offset0 <= inst[7:0];
                        r_ds_inst_out.offset1 <= inst[15:8];
                        r_ds_inst_out.gds <= inst[17];
                        r_ds_inst_out.op <= inst[25:18];
                    end
                end
                DS_BUSY: begin // Second 4-byte chunk
                    r_valid <= 1'b1;
                    r_ds_inst_out.addr <= inst[7:0];
                    r_ds_inst_out.data0 <= inst[15:8];
                    r_ds_inst_out.data1 <= inst[23:16];
                    r_ds_inst_out.vdst <= inst[31:24];
                end
            endcase
        end
    end
end

// SM for tracking which portion of instruction
always_comb begin
    unique case (r_curr_state)
        DS_REST: begin
            next_state = DS_REST;
            if (is_ds_inst) begin
                next_state = DS_BUSY;
            end
        end
        DS_BUSY: begin
            next_state = DS_REST;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        r_curr_state <= DS_REST;
    end else begin
        if (!stall) begin
            r_curr_state <= next_state;
        end
    end
end

endmodule

/*
    Decoder for FLAT Instructions

    Flat memory instruction come in three versions: FLAT:: memory address (per work-item) may be
    in global memory, scratch (private) memory or shared memory (LDS) GLOBAL:: same as FLAT,
    but assumes all memory addresses are global memory. SCRATCH:: same as FLAT, but
    assumes all memory addresses are scratch (private) memory.
    The microcode format is identical for each, and only the value of the SEG (segment) field differs
*/

module decode_flat
import common_pkg::*;
(
    input clk,
    input reset,

    // Instruction
    input  [31:0] inst,

    // Decoder Stall
    input         stall,

    // Output to Instruction Controller
    output flat_inst_t flat_inst_out,

    // Ready - Valid Interface to Instruction Controller 
    output valid,

    // Busy Interface to Main Decode Module
    output busy
);

localparam FLAT_BUSY = 1'b1;
localparam FLAT_REST = 1'b0;

// Signal Instantiations
logic       is_flat_inst;
logic       next_state;
logic       r_curr_state;
logic       r_valid;
flat_inst_t r_flat_inst_out;

assign is_flat_inst = (inst[31:26] == 6'b110111);
assign flat_inst_out = r_flat_inst_out;
assign busy = (r_curr_state == FLAT_BUSY);
assign valid = r_valid;

always_ff @(posedge clk) begin
    if (reset) begin
        r_flat_inst_out <= '0;
        r_valid <= '0;
    end else begin
        if (!stall) begin
            unique case (r_curr_state)
                FLAT_REST: begin
                    r_valid <= 1'b0;
                    if (is_flat_inst) begin 
                        r_flat_inst_out.offset <= inst[11:0];
                        r_flat_inst_out.dlc <= inst[12];
                        r_flat_inst_out.lds <= inst[13];
                        r_flat_inst_out.seg <= inst[15:14];
                        r_flat_inst_out.glc <= inst[16];
                        r_flat_inst_out.slc <= inst[17];
                        r_flat_inst_out.op <= inst[24:18];
                    end
                end
                FLAT_BUSY: begin
                    r_valid <= 1'b1;
                    r_flat_inst_out.addr <= inst[7:0];
                    r_flat_inst_out.data <= inst[15:8];
                    r_flat_inst_out.saddr <= inst[22:16];
                    r_flat_inst_out.vdst <= inst[31:24];
                end
            endcase
        end
    end
end 

// SM for tracking which portion of instruction
always_comb begin
    unique case (r_curr_state)
        FLAT_REST: begin
            next_state = FLAT_REST;
            if (is_flat_inst) begin
                next_state = FLAT_BUSY;
            end
        end
        FLAT_BUSY: begin
            next_state = FLAT_REST;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        r_curr_state <= FLAT_REST;
    end else begin
        if (!stall) begin
            r_curr_state <= next_state;
        end
    end
end

endmodule

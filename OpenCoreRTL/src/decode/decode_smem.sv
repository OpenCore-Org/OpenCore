
/*
    Decoder for Scalar Memory Instructions 

    Scalar Memory Read (SMEM) instructions allow a shader program to load data from memory
    into SGPRs through the Scalar Data Cache. Instructions can read from 1 to 16 Dwords. Data is
    read directly into SGPRs without any format conversion.
    The scalar unit reads consecutive Dwords from memory to the SGPRs. This is intended
    primarily for loading ALU constants and for indirect T#/S# lookup. No data formatting is
    supported, nor is byte or short data.
*/

module decode_smem
import common_pkg::*;
(
    input clk,
    input reset,

    // Instruction
    input  [31:0] inst,

    // Decoder Stall
    input         stall,

    // Output to Instruction Controller
    output smem_inst_t smem_inst_out,

    // Ready - Valid Interface to Instruction Controller 
    output valid,

    // Busy Interface to Main Decode Module
    output busy
);

localparam SMEM_BUSY = 1'b1;
localparam SMEM_REST = 1'b0;

// Signal Instantiations
logic       is_smem_inst;
logic       next_state;
logic       r_curr_state;
logic       r_valid;
smem_inst_t r_smem_inst_out;

assign is_smem_inst = (inst[31:26] == 6'b111101);
assign smem_inst_out = r_smem_inst_out;
assign busy = (r_curr_state == SMEM_BUSY);
assign valid = r_valid;

always_ff @(posedge clk) begin
    if (reset) begin
        r_smem_inst_out <= '0;
        r_valid <= '0;
    end else begin
        if (!stall) begin
            unique case (r_curr_state)
                SMEM_REST: begin
                    r_valid <= 1'b0;
                    if (is_smem_inst) begin 
                        r_smem_inst_out.sbase <= inst[5:0];
                        r_smem_inst_out.sdata <= inst[12:6];
                        r_smem_inst_out.dlc <= inst[14];
                        r_smem_inst_out.glc <= inst[16];
                        r_smem_inst_out.op <= inst[25:18];
                    end
                end
                SMEM_BUSY: begin
                    r_valid <= 1'b1;
                    r_smem_inst_out.offset <= inst[20:0];
                    r_smem_inst_out.soffset <= inst[31:25];
                end
            endcase
        end
    end
end 

// SM for tracking which portion of instruction
always_comb begin
    unique case (r_curr_state)
        SMEM_REST: begin
            next_state = SMEM_REST;
            if (is_smem_inst) begin
                next_state = SMEM_BUSY;
            end
        end
        SMEM_BUSY: begin
            next_state = SMEM_REST;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        r_curr_state <= SMEM_REST;
    end else begin
        if (!stall) begin
            r_curr_state <= next_state;
        end
    end
end

endmodule

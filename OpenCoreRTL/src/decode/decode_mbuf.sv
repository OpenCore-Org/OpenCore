/*
    Decoder for Vector Memory Buffer Format Instructions

    There are two memory buffer instruction formats:
    MTBUF
        typed buffer access (data type is defined by the instruction)
    MUBUF
        untyped buffer access (data type is defined by the buffer / resource-constant)


*/

module decode_mbuf
import common_pkg::*;
(
    input clk,
    input reset,

    // Instruction
    input  [31:0] inst,

    // Decoder Stall
    input         stall,

    // Output to Instruction Controller
    output mbuf_inst_t mbuf_inst_out,

    // Ready - Valid Interface to Instruction Controller 
    output valid,

    // Busy Interface to Main Decode Module
    output busy
);

localparam MBUF_BUSY = 1'b1;
localparam MBUF_REST = 1'b0;

// Signal Instantiations
logic       is_mubuf_inst;
logic       is_mtbuf_inst;

logic       next_state;
logic       r_curr_state;
logic       r_valid;
mbuf_inst_t r_mbuf_inst_out;

assign is_mubuf_inst = (inst[31:26] == 6'b111000);
assign is_mtbuf_inst = (inst[31:26] == 6'b111010);

assign mbuf_inst_out = r_mbuf_inst_out;
assign busy = (r_curr_state == MBUF_BUSY);
assign valid = r_valid;

always_ff @(posedge clk) begin
    if (reset) begin
        r_mbuf_inst_out <= '0;
        r_valid <= '0;
    end else begin
        if (!stall) begin
            unique case (r_curr_state)
                MBUF_REST: begin
                    r_valid <= 1'b0;
                    if (is_mubuf_inst) begin 
                        r_mbuf_inst_out.mbuf_type <= MUBUF;
                        r_mbuf_inst_out.offset <= inst[11:0];
                        r_mbuf_inst_out.offen <= inst[12];
                        r_mbuf_inst_out.idxen <= inst[13];
                        r_mbuf_inst_out.glc <= inst[14];
                        r_mbuf_inst_out.dlc <= inst[15];
                        r_mbuf_inst_out.lds <= inst[16];
                        r_mbuf_inst_out.op  <= inst[25:18];
                    end else if (is_mtbuf_inst) begin
                        r_mbuf_inst_out.mbuf_type <= MTBUF;
                        r_mbuf_inst_out.offset <= inst[11:0];
                        r_mbuf_inst_out.offen <= inst[12];
                        r_mbuf_inst_out.idxen <= inst[13];
                        r_mbuf_inst_out.glc <= inst[14];
                        r_mbuf_inst_out.dlc <= inst[15];
                        r_mbuf_inst_out.op[2:0] <= inst[18:16];
                        r_mbuf_inst_out.dfmt <= inst[25:19];
                    end
                end
                MBUF_BUSY: begin
                    r_valid <= 1'b1;

                    r_mbuf_inst_out.vaddr <= inst[7:0];
                    r_mbuf_inst_out.vdata <= inst[15:8];
                    r_mbuf_inst_out.srsrc <= inst[20:16];
                    r_mbuf_inst_out.slc <= inst[22];
                    r_mbuf_inst_out.tfe <= inst[23];
                    r_mbuf_inst_out.soffset <= inst[31:24];

                    if (mbuf_inst_out.mbuf_type == MUBUF) begin
                        r_mbuf_inst_out.op[3] <= inst[21];
                    end
                end
            endcase
        end
    end
end

// SM for tracking which portion of instruction
always_comb begin
    unique case (r_curr_state)
        MBUF_REST: begin
            next_state = MBUF_REST;
            if (is_mubuf_inst || is_mtbuf_inst) begin
                next_state = MBUF_BUSY;
            end
        end
        MBUF_BUSY: begin
            next_state = MBUF_REST;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        r_curr_state <= MBUF_REST;
    end else begin
        if (!stall) begin
            r_curr_state <= next_state;
        end
    end
end

endmodule

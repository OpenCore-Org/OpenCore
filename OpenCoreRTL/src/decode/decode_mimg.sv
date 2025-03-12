
/*
    Decoder for Vector Image Memory Instructions 

    The mimg instruction copies pixel or vertex shader data from VGPRs into a dedicated output
    buffer. The mimg instruction outputs the following types of data.
        • Vertex Position
        • Vertex Parameter
        • Pixel color
        • Pixel depth (Z)
        • Primitive Data
*/

module decode_mimg
import common_pkg::*;
(
    input clk,
    input reset,

    // Instruction 
    input  [31:0] inst,

    // Decoder Stall
    input         stall,

    // Output to Instruction Controller
    output mimg_inst_t mimg_inst_out,

    // Ready - Valid Interface to Instruction Controller 
    output valid,

    // Busy Interface to Main Decode Module
    output busy
);

localparam MIMG_NSA3 = 5'b10000;
localparam MIMG_NSA2 = 5'b01000;
localparam MIMG_NSA1 = 5'b00100;
localparam MIMG_BUSY = 5'b00010;
localparam MIMG_REST = 5'b00001;

// Signal Instantiations
logic       is_mimg_inst;
logic [4:0] next_state;
logic [4:0] r_curr_state;
logic       r_valid;
mimg_inst_t r_mimg_inst_out;

assign is_mimg_inst = (inst[31:26] == 6'b111100);
assign mimg_inst_out = r_mimg_inst_out;
assign busy = |(r_curr_state & ~MIMG_REST); // All states other than rest will incur busy broadcast
assign valid = r_valid;

always_ff @(posedge clk) begin
    if (reset) begin
        r_mimg_inst_out <= '0;
        r_valid <= '0;
    end else begin
        if (!stall) begin
            unique case (r_curr_state)
                MIMG_REST: begin
                    r_valid <= 1'b0;
                    if (is_mimg_inst) begin // First 4-byte chunk
                        r_mimg_inst_out.nsa <= inst[2:1];
                        r_mimg_inst_out.dim <= inst[5:3];
                        r_mimg_inst_out.dlc <= inst[7];
                        r_mimg_inst_out.dmask <= inst[11:8];
                        r_mimg_inst_out.unrm <= inst[12];
                        r_mimg_inst_out.glc <= inst[13];
                        r_mimg_inst_out.r128 <= inst[15];
                        r_mimg_inst_out.tfe <= inst[16];
                        r_mimg_inst_out.lwe <= inst[17];
                        r_mimg_inst_out.op <= {inst[0], inst[24:18]};
                        r_mimg_inst_out.slc <= inst[25];
                    end
                end
                MIMG_BUSY: begin // Second 4-byte chunk
                    r_mimg_inst_out.vaddr <= inst[7:0];
                    r_mimg_inst_out.vdata <= inst[15:8];
                    r_mimg_inst_out.srsrc <= inst[20:16];
                    r_mimg_inst_out.ssamp <= inst[25:21];
                    r_mimg_inst_out.a16 <= inst[30];
                    r_mimg_inst_out.d16 <= inst[31];

                    if (mimg_inst_out.nsa == 0) begin
                        r_valid <= 1'b1;
                    end else begin
                        r_valid <= 1'b0;
                    end
                end
                MIMG_NSA3: begin // Always refers to addr1-4
                    r_valid <= 1'b0;
                    r_mimg_inst_out.addr1 <= inst[7:0];
                    r_mimg_inst_out.addr2 <= inst[15:8];
                    r_mimg_inst_out.addr3 <= inst[23:16];
                    r_mimg_inst_out.addr4 <= inst[31:24];
                end
                MIMG_NSA2: begin // Could refer to addr1-4 OR addr5-8
                    r_valid <= 1'b0;
                    if (mimg_inst_out.nsa == 2) begin
                        r_mimg_inst_out.addr1 <= inst[7:0];
                        r_mimg_inst_out.addr2 <= inst[15:8];
                        r_mimg_inst_out.addr3 <= inst[23:16];
                        r_mimg_inst_out.addr4 <= inst[31:24];
                    end else begin // (mimg_inst_out.nsa == 3)
                        r_mimg_inst_out.addr5 <= inst[7:0];
                        r_mimg_inst_out.addr6 <= inst[15:8];
                        r_mimg_inst_out.addr7 <= inst[23:16];
                        r_mimg_inst_out.addr8 <= inst[31:24];
                    end
                end
                MIMG_NSA1: begin // Could refer to addr1-4 OR addr5-8 OR addr9-12
                    r_valid <= 1'b1;
                    if (mimg_inst_out.nsa == 1) begin
                        r_mimg_inst_out.addr1 <= inst[7:0];
                        r_mimg_inst_out.addr2 <= inst[15:8];
                        r_mimg_inst_out.addr3 <= inst[23:16];
                        r_mimg_inst_out.addr4 <= inst[31:24];
                    end else if (mimg_inst_out.nsa == 2) begin
                        r_mimg_inst_out.addr5 <= inst[7:0];
                        r_mimg_inst_out.addr6 <= inst[15:8];
                        r_mimg_inst_out.addr7 <= inst[23:16];
                        r_mimg_inst_out.addr8 <= inst[31:24]; 
                    end else begin // (mimg_inst_out.nsa == 3)
                        r_mimg_inst_out.addr9  <= inst[7:0];
                        r_mimg_inst_out.addr10 <= inst[15:8];
                        r_mimg_inst_out.addr11 <= inst[23:16];
                        r_mimg_inst_out.addr12 <= inst[31:24];
                    end
                end
                default: begin
                    r_mimg_inst_out <= '0;
                    r_valid <= '0;
                end
            endcase
        end
    end
end 

// SM for tracking which portion of instruction
always_comb begin
    unique case (r_curr_state)
        MIMG_REST: begin
            next_state = MIMG_REST;
            if (is_mimg_inst) begin
                next_state = MIMG_BUSY;
            end
        end
        MIMG_BUSY: begin
            unique case (mimg_inst_out.nsa)
                2'd0: next_state = MIMG_REST;
                2'd1: next_state = MIMG_NSA1;
                2'd2: next_state = MIMG_NSA2;
                2'd3: next_state = MIMG_NSA3;
            endcase
        end
        MIMG_NSA1: begin
            next_state = MIMG_REST;
        end
        MIMG_NSA2: begin
            next_state = MIMG_NSA1;
        end
        MIMG_NSA3: begin
            next_state = MIMG_NSA2;
        end
        default: next_state = MIMG_REST;
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        r_curr_state <= MIMG_REST;
    end else begin
        if (!stall) begin
            r_curr_state <= next_state;
        end
    end
end

endmodule

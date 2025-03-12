
/*
    Decoder for Export Instructions 

    The export instruction copies pixel or vertex shader data from VGPRs into a dedicated output
    buffer. The export instruction outputs the following types of data.
        • Vertex Position
        • Vertex Parameter
        • Pixel color
        • Pixel depth (Z)
        • Primitive Data
*/

module decode_export
import common_pkg::*;
(
    input clk,
    input reset,

    // Instruction 
    input  [31:0] inst,

    // Decoder Stall
    input         stall,

    // Output to Instruction Controller
    output export_inst_t export_inst_out,

    // Ready - Valid Interface to Instruction Controller
    output valid,

    // Busy Interface to Main Decode Module
    output busy
);

localparam EXPORT_BUSY = 1'b1;
localparam EXPORT_REST = 1'b0;

// Signal Instantiations
logic       is_export_inst;
logic       next_state;
logic       r_curr_state;
logic       r_valid;
export_inst_t r_export_inst_out;

assign is_export_inst = (inst[31:26] == 6'b111110);
assign export_inst_out = r_export_inst_out;
assign busy = (r_curr_state == EXPORT_BUSY);
assign valid = r_valid;

always_ff @(posedge clk) begin
    if (reset) begin
        r_export_inst_out <= '0;
        r_valid <= '0;
    end else begin
        if (!stall) begin
            unique case (r_curr_state)
                EXPORT_REST: begin
                    r_valid <= 1'b0;
                    if (is_export_inst) begin // First 4-byte chunk
                        r_export_inst_out.en     <= inst[3:0];
                        r_export_inst_out.target <= inst[9:4];
                        r_export_inst_out.compr  <= inst[10];
                        r_export_inst_out.done   <= inst[11];
                        r_export_inst_out.vm     <= inst[12];
                    end
                end
                EXPORT_BUSY: begin // Second 4-byte chunk
                    r_valid <= 1'b1;
                    r_export_inst_out.vsrc0 <= inst[7:0];
                    r_export_inst_out.vsrc1 <= inst[15:8];
                    r_export_inst_out.vsrc2 <= inst[23:16];
                    r_export_inst_out.vsrc3 <= inst[31:24];
                end
            endcase
        end
    end
end 

// SM for tracking which portion of instruction
always_comb begin
    unique case (r_curr_state)
        EXPORT_REST: begin
            next_state = EXPORT_REST;
            if (is_export_inst) begin
                next_state = EXPORT_BUSY;
            end
        end
        EXPORT_BUSY: begin
            next_state = EXPORT_REST;
        end
    endcase    
end

always_ff @(posedge clk) begin
    if (reset) begin
        r_curr_state <= EXPORT_REST;
    end else begin
        if (!stall) begin
            r_curr_state <= next_state;
        end
    end
end

endmodule

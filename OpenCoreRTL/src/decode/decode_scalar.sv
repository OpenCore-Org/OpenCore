module decode_scalar
import common_pkg::*;
(
    input clk,
    input reset,

    // Instruction
    input  [31:0] inst,

    // Decoder Stall
    input         stall,

    // Output to Instruction Controller (scalar)
    output scalar_inst_t scalar_inst_out,

    // Ready - Valid Interface to Instruction Controller 
    output valid,

    // Busy - Busy Interface to Main Decode Module
    output busy
);

// State Definition
typedef enum {
    S_REST,
    S_BUSY_LITERAL
} state_e;

// Signal Instantiations
logic                       is_scalar_inst;
scalar_inst_format_e        s_inst_format;
logic [7:0]                 src0;
logic [7:0]                 src1;
state_e                     next_state;
state_e                     r_curr_state;
logic                       r_valid;
scalar_inst_t               r_scalar_inst_out;

// Signal Assignments
assign busy = (r_curr_state != S_REST);
assign valid = r_valid;
assign scalar_inst_out = r_scalar_inst_out;

assign is_scalar_inst = (inst[31:30] == 2'b10);
assign src0 = inst[7:0];
assign src1 = inst[15:8];

// Main output assignments
always_ff @(posedge clk) begin
    if (reset) begin
        r_scalar_inst_out <= '0;
        r_valid <= '0;
    end else begin
        if (!stall) begin
            unique case (r_curr_state)
                S_REST: begin
                    r_valid <= 1'b0;
                    if (is_scalar_inst) begin
                        r_scalar_inst_out.dst <= inst[22:16];
                        r_scalar_inst_out.src0 <= src0;
                        r_scalar_inst_out.src1 <= src1;
                        r_scalar_inst_out.imm16 <= inst[15:0];
                        r_scalar_inst_out.literal <= '0;
                        r_scalar_inst_out.format <= s_inst_format;

                        unique case (s_inst_format)
                            SOP2: begin
                                r_scalar_inst_out.op <= {1'b0, inst[29:23]};
                            end
                            SOP1: begin
                                r_scalar_inst_out.op <= inst[15:8];
                            end
                            SOPK: begin
                                r_scalar_inst_out.op <= {3'b000, inst[27:23]};
                            end
                            SOPP: begin
                                r_scalar_inst_out.op <= {1'b0, inst[22:16]};
                            end
                            SOPC: begin
                                r_scalar_inst_out.op <= {1'b0, inst[22:16]};
                            end
                        endcase

                        r_valid <= 1'b1;
                        if (next_state == S_BUSY_LITERAL) begin
                            r_valid <= 1'b0;
                        end
                    end
                end
                S_BUSY_LITERAL: begin
                    r_scalar_inst_out.literal <= inst;
                    r_valid <= 1'b1;
                end
            endcase
        end
    end
end

// Decode Scalar Instruction Type
always_comb begin
    s_inst_format = SOPK;
    if (is_scalar_inst) begin
        if (inst[29:23] == 7'b1111111) begin // SOPP Instruction
            s_inst_format = SOPP;
        end else if (inst[29:23] == 7'b1111110) begin // SOPC
            s_inst_format = SOPC;
        end else if (inst[29:23] == 7'b1111101) begin // SOP1
            s_inst_format = SOP1;
        end else if (inst[29:28] == 2'b11) begin // SOPK
            s_inst_format = SOPK;
        end else begin // SOP2
            s_inst_format = SOP2;
        end
    end
end

// State machine for tracking which portion of the instruction we're at
always_comb begin
    unique case (r_curr_state)
        S_REST: begin
            next_state = S_REST;
            if (is_scalar_inst) begin
                if (s_inst_format == SOP1 || s_inst_format == SOP2 || s_inst_format == SOPC) begin
                    if (src0 == LITERAL_CONSTANT) begin
                        next_state = S_BUSY_LITERAL;
                    end
                end
                if (s_inst_format == SOP2 || s_inst_format == SOPC) begin
                    if (src1 == LITERAL_CONSTANT) begin
                        next_state = S_BUSY_LITERAL;
                    end
                end
            end
        end
        S_BUSY_LITERAL: begin
            next_state = S_REST;
        end
        default: next_state = S_REST;
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        r_curr_state <= S_REST;
    end else begin
        if (!stall) begin
            r_curr_state <= next_state;
        end
    end
end

endmodule

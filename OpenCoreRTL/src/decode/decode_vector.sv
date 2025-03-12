module decode_vector
import common_pkg::*;
import vector_op_pkg::*;
(
    input clk,
    input reset,

    // Instruction
    input  [31:0] inst,

    // Decoder Stall
    input         stall,

    // Output to Instruction Controller (vector)
    output vector_inst_t vector_inst_out,

    // Ready - Valid Interface to Instruction Controller 
    output valid,

    // Busy Interface to Main Decode Module
    output busy
);

// State Definition
typedef enum {
    V_REST,
    V_BUSY_INSTRUCTION,
    V_BUSY_LITERAL,
    V_BUSY_SDWA,
    V_BUSY_DPP
} state_e;

// Signal Instantiations
vector_inst_format_e    v_inst_format;
logic [9:0]             v_op;
logic                   is_vector_inst;
logic                   is_vop_c_1_2;
logic                   is_vintrp;
logic                   is_vop3;
logic                   is_vop3p;
logic                   is_special_inst; // Special instruction that implicitly expects a literal afterward
state_e                 next_state;
logic [8:0]             src0;
logic [8:0]             src1;
logic [8:0]             src2;

state_e                 r_curr_state;
vector_inst_t           r_vector_inst_out;
logic                   r_valid;

// Signal Assignments
assign is_vector_inst = (is_vop_c_1_2 | is_vintrp | is_vop3 | is_vop3p);
assign is_vop_c_1_2 = (inst[31] == 1'b0);
assign is_vintrp = (inst[31:26] == 6'b110010);
assign is_vop3 = (inst[31:26] == 6'b110101);
assign is_vop3p = (inst[31:26] == 6'b110011);
assign src0 = inst[8:0];
assign src1 = inst[17:9];
assign src2 = inst[26:18];
assign busy = (r_curr_state != V_REST);
assign valid = r_valid;
assign vector_inst_out = r_vector_inst_out;

// Main output assignments
always_ff @(posedge clk) begin
    if (reset) begin
        r_vector_inst_out <= '0;
        r_valid <= '0;
    end else begin
        unique case (r_curr_state)
            V_REST: begin
                if (!stall) begin
                    r_valid <= '0;
                    if (is_vector_inst) begin
                        unique case (v_inst_format)
                            VOPC, VOP1, VOP2: begin
                                r_vector_inst_out.format <= v_inst_format;
                                r_vector_inst_out.op <= v_op;
                                r_vector_inst_out.src0 <= src0;
                                r_vector_inst_out.src1 <= {1'b0, src1[7:0]};
                                r_vector_inst_out.vdst <= inst[24:17];

                                // Verify if not having extra data
                                if (next_state == V_REST) begin
                                    r_valid <= '1;
                                end
                            end
                            VINTRP: begin
                                r_vector_inst_out.src0 <= {1'b0, src0[7:0]};
                                r_vector_inst_out.attr_chan <= inst[9:8];
                                r_vector_inst_out.attr <= inst[15:10];
                                r_vector_inst_out.op <= v_op;
                                r_vector_inst_out.vdst <= inst[25:18];
                                r_vector_inst_out.format <= v_inst_format;

                                r_valid <= '1;
                            end
                            VOP3: begin
                                // Common fields
                                r_vector_inst_out.format <= v_inst_format;
                                r_vector_inst_out.op <= v_op;
                                r_vector_inst_out.clmp <= inst[15];
                                r_vector_inst_out.vdst <= inst[7:0];

                                // VOP3A Exclusive Fields
                                r_vector_inst_out.op_sel <= inst[14:11];
                                r_vector_inst_out.abs<= inst[10:8];

                                // VOP3B Exclusive Fields
                                r_vector_inst_out.sdst <= inst[14:8]; // Interpreted as SDST
                            end
                            VOP3P: begin
                                r_vector_inst_out.format <= v_inst_format;
                                r_vector_inst_out.op <= v_op;
                                r_vector_inst_out.clmp <= inst[15];
                                r_vector_inst_out.op_sel_hi[2] <= inst[14];
                                r_vector_inst_out.op_sel <= {1'b0, inst[13:11]};
                                r_vector_inst_out.neg_hi <= inst[10:8];
                                r_vector_inst_out.vdst <= inst[7:0];
                            end
                        endcase
                    end
                end
            end
            V_BUSY_INSTRUCTION: begin
                r_vector_inst_out.src0 <= src0;
                r_vector_inst_out.src1 <= src1;
                r_vector_inst_out.src2 <= src2;
                r_vector_inst_out.omod <= inst[28:27];
                r_vector_inst_out.op_sel_hi[1:0] <= inst[28:27];
                r_vector_inst_out.neg <= inst[31:29];

                // Verify if not having extra data
                if (next_state == V_REST) begin
                    r_valid <= '1;
                end
            end
            V_BUSY_LITERAL: begin
                r_vector_inst_out.literal <= inst;
                r_valid <= '1;
            end
            V_BUSY_SDWA: begin
                // Fill SDWA values
                r_vector_inst_out.sdwa.src0 <= src0[7:0];
                r_vector_inst_out.sdwa.src0_sel <= inst[18:16];
                r_vector_inst_out.sdwa.src0_sext <= inst[19];
                r_vector_inst_out.sdwa.src0_neg <= inst[20];
                r_vector_inst_out.sdwa.src0_abs <= inst[21];
                r_vector_inst_out.sdwa.s0 <= inst[23];
                r_vector_inst_out.sdwa.src1_sel <= inst[26:24];
                r_vector_inst_out.sdwa.src1_sext <= inst[27];
                r_vector_inst_out.sdwa.src1_neg <= inst[28];
                r_vector_inst_out.sdwa.src1_abs <= inst[29];
                r_vector_inst_out.sdwa.s1 <= inst[31];

                // Fill SDWAB exclusive values
                r_vector_inst_out.sdwa.sdst <= inst[14:8];
                r_vector_inst_out.sdwa.sd <= inst[15];

                // Fill SDWA exclusive values
                r_vector_inst_out.sdwa.dst_sel <= inst[10:8];
                r_vector_inst_out.sdwa.dst_u <=inst[12:11];
                r_vector_inst_out.sdwa.clmp <= inst[13];
                r_vector_inst_out.sdwa.omod <= inst[15:14];

                r_valid <= '1;
            end
            V_BUSY_DPP: begin
                r_vector_inst_out.dpp.src0 <= src0[7:0];

                // Fill DPP16 values
                r_vector_inst_out.dpp.dpp16.dpp_ctrl <= inst[16:8];
                r_vector_inst_out.dpp.dpp16.fi <= inst[18];
                r_vector_inst_out.dpp.dpp16.bc <= inst[19];
                r_vector_inst_out.dpp.dpp16.src0_neg <= inst[20];
                r_vector_inst_out.dpp.dpp16.src0_abs <= inst[21];
                r_vector_inst_out.dpp.dpp16.src1_neg <= inst[22];
                r_vector_inst_out.dpp.dpp16.src1_abs <= inst[23];
                r_vector_inst_out.dpp.dpp16.bank_mask <= inst[27:24];
                r_vector_inst_out.dpp.dpp16.row_mask <= inst[31:28];

                // Fill DPP8 values
                r_vector_inst_out.dpp.dpp8.lane_sel0 <= inst[10:8];
                r_vector_inst_out.dpp.dpp8.lane_sel1 <= inst[13:11];
                r_vector_inst_out.dpp.dpp8.lane_sel2 <= inst[16:14];
                r_vector_inst_out.dpp.dpp8.lane_sel3 <= inst[19:17];
                r_vector_inst_out.dpp.dpp8.lane_sel4 <= inst[22:20];
                r_vector_inst_out.dpp.dpp8.lane_sel5 <= inst[25:23];
                r_vector_inst_out.dpp.dpp8.lane_sel6 <= inst[28:26];
                r_vector_inst_out.dpp.dpp8.lane_sel7 <= inst[31:29];

                r_valid <= '1;
            end
        endcase
    end
end

// Decode Vector Instruction Type and Opcode
always_comb begin
    v_inst_format = VOP1;
    v_op = '0;
    if (is_vector_inst) begin
        if (is_vop_c_1_2) begin
            if (inst[30:25] == 6'b111111) begin
                v_inst_format = VOP1;
                v_op = {2'b00, inst[16:9]};
            end else if (inst[30:25] == 6'b111110) begin
                v_inst_format = VOPC;
                v_op = {2'b00, inst[24:17]};
            end else begin
                v_inst_format = VOP2;
                v_op = {4'b0000, inst[30:25]};
            end
        end else if (is_vintrp) begin
            v_inst_format = VINTRP;
            v_op = {8'b00000000, inst[17:16]};
        end else if (is_vop3) begin
            v_inst_format = VOP3;
            v_op = inst[25:16];
        end else if (is_vop3p) begin
            v_inst_format = VOP3P;
            v_op = {3'b000 , inst[22:16]};
        end
    end
end

// Decode if Special Instruction - Instruction that implicitly expects a literal afterward
always_comb begin
    is_special_inst = 1'b0;
    if (v_inst_format == VOP2) begin
        if (v_op == V_FMAMK_F32) begin
            is_special_inst = 1'b1;
        end
    end
end

// State machine for tracking which portion of the instruction we're at
always_comb begin
    unique case (r_curr_state)
        V_REST: begin
            next_state = V_REST;
            if (is_vector_inst) begin
                if (is_special_inst) begin // Assuming specials are only a 32-bit vector instructions for now
                    next_state = V_BUSY_LITERAL;
                end else if (is_vop3 || is_vop3p) begin
                    next_state = V_BUSY_INSTRUCTION;
                end else if (is_vop_c_1_2) begin
                    if (src0 == {1'b0, LITERAL_CONSTANT}) begin
                        next_state = V_BUSY_LITERAL;
                    end if (src0 == {1'b0, DPP16} || src0 == {1'b0, DPP8} || src0 == {1'b0, DPP8FI}) begin
                        next_state = V_BUSY_DPP;
                    end if (src0 == {1'b0, SDWA}) begin
                        next_state = V_BUSY_SDWA;
                    end
                end
            end
        end
        V_BUSY_INSTRUCTION: begin // Only VOP3 instructions will get here
            next_state = V_REST;
            if (src0 == {1'b0, LITERAL_CONSTANT} || src1 == {1'b0, LITERAL_CONSTANT} || src2 == {1'b0, LITERAL_CONSTANT}) begin
                next_state = V_BUSY_LITERAL;
            end
        end
        V_BUSY_LITERAL: begin
            next_state = V_REST;
        end
        V_BUSY_SDWA: begin
            next_state = V_REST;
        end
        V_BUSY_DPP: begin
            next_state = V_REST;
        end
        default: next_state = V_REST;
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        r_curr_state <= V_REST;
    end else begin
        if (!stall) begin
            r_curr_state <= next_state;
        end
    end
end

endmodule

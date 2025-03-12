/*
    Execute stage p2 for Vector ALU Instructions
*/

module execute_vector_core
import common_pkg::*;
import mem_pkg::*;
import vector_op_pkg::*;
import arithmetic_pkg::*;
(
    input logic clk,
    input logic rst,

    input vector_inst_t vector_inst_in,
    input logic [1:0][SGPR_DATA_WIDTH-1:0] ssrc0, ssrc1, ssrc2,
    input logic [VGPR_DATA_WIDTH-1:0] vsrc, // VOP2 = VSRC1
    input logic [VGPR_DATA_WIDTH-1:0] dst_data,
    input logic vcc_in,

    output logic vcc_out,
    output logic vcc_we,
    output logic [1:0][VGPR_DATA_WIDTH-1:0] vdest_out,
    output logic vdest_wb,
    output logic [1:0][SGPR_DATA_WIDTH-1:0] sdest_out,
    output logic sdest_wb,

    output logic out_valid,
    input logic out_ready,
    output logic next_busy,
    output logic busy
);

/*
    Output Notes:
        - EXEC:
            - Only write if EXEC set to 1
            - V_CMPX: Write result to EXEC
        - VCC:
            Arithmetic operations (VOP2): 1 = carry out
        - CLAMP Bit:
            - V_CMP: 1 indicates if a floating point exception occurs
            - Integer Ops: clamps to the largest and smallest representable value
            - Floating Point Ops: clamps the result to the range [0.0, 1.0]
        - VOP3:
            - Arithmetic Carryout to arbitrary SGPR-pair
            - Output modifiers
                - Ignored if the IEEE mode bit is set to 1
                - If output denormals are enabled, then output modifiers are ignored
                - OMOD (Output Modifer): if floating point result, multiplies the result by: 0.5, 1.0, 2.0 or 4.0
*/

// --- Utility Functions ---
function logic [63:0] sign_extend_to_64(logic [31:0] data);
    sign_extend_to_64 = {{(32){data[31]}}, data};
endfunction

// Clamp uint32 to [0, max_uint32]
function logic [31:0] clamp_uint32(logic [32:0] data);
    if (data[32]) begin
        clamp_uint32 = '1;
    end else begin
        clamp_uint32 = data[31:0];
    end
endfunction

// Clamp uint64 to [0, max_uint64]
function logic [63:0] clamp_uint64(logic [64:0] data);
    if (data[64]) begin
        clamp_uint64 = '1;
    end else begin
        clamp_uint64 = data[63:0];
    end
endfunction

// Clamp int32 to [min_int32, max_int32]
function logic signed [31:0] clamp_int32(logic signed [32:0] data);
    if (data > 33'd2147483647) begin
        clamp_int32 = 32'd2147483647;
    end if (data < -33'd2147483648) begin
        clamp_int32 = -32'd2147483648;
    end else begin
        clamp_int32 = data[31:0];
    end
endfunction

// Clamp int64 to [min_int64, max_int64]
function logic signed [63:0] clamp_int64(logic signed [64:0] data);
    if (data > 65'd9223372036854775807) begin
        clamp_int64 = 64'd9223372036854775807;
    end if (data < -65'd9223372036854775808) begin
        clamp_int64 = -64'd9223372036854775808;
    end else begin
        clamp_int64 = data[63:0];
    end
endfunction

// Clamp fp32 to [0, 1.0]
function logic signed [31:0] clamp_fp32(logic [31:0] data);
    // IEEE-754: Single-Precision Floating-Point fields
    // data[31] is the sign bit
    // data[30:23] is the exponent
    // data[22:0] is the fraction

    // If sign is negative, clamp to 0.0
    if (data[31] == 1'b1) begin
        clamp_fp32 = '0;
    // If over 1.0, clamp to 1.0
    end else if ((data[30:23] == 127 && data[22:0] > 0) || (data[30:23] > 127)) begin
        clamp_fp32 = 32'h3f800000; // Represents 1.0 fp32 in hex
    // If within range, keep unchanged
    end else begin
        clamp_fp32 = data[31:0];
    end
endfunction

function logic [31:0] neg_fp32(logic neg, logic [31:0] data);
    if (neg) begin
        neg_fp32 = {~data[31], data[30:0]};
    end else begin
        neg_fp32 = data;
    end
endfunction

function logic [31:0] abs_fp32(logic abs, logic [31:0] data);
    if (abs) begin
        abs_fp32 = {1'b0, data[30:0]};
    end else begin
        abs_fp32 = data;
    end
endfunction

function logic [31:0] omod_fp32(logic [1:0] omod, logic [31:0] data);
    // IEEE-754: Single-Precision Floating-Point fields
    // data[31] is the sign bit
    // data[30:23] is the exponent
    // data[22:0] is the fraction

    if (data[30:23] == 0) begin
        // Subnormals are not supported
        omod_fp32 = data;
    end

    // Output modifiers mights lead to invalid exponents, but currently
    // have no way of handling it. Would cause an exception.
    unique case (omod)
        0: begin
            // Mult by 1
            omod_fp32 = data;
        end
        1: begin
            // Mult by 2
            omod_fp32 = {data[31], data[30:23] + 8'd1, data[22:0]};
        end
        2: begin
            // Mult by 4
            omod_fp32 = {data[31], data[30:23] + 8'd2, data[22:0]};
        end
        3: begin
            // Mult by 0.5
            omod_fp32 = {data[31], data[30:23] - 8'd1, data[22:0]};
        end
        default: begin
            // Do nothing
            omod_fp32 = data;
        end
    endcase
endfunction

// --- State Definition ---
typedef enum {
    VECTOR_REST,
    VECTOR_MULT_BUSY,
    VECTOR_FP_MAC_BUSY,
    VECTOR_ADD_BUSY,
    VECTOR_LOGIC_BUSY
} states_t;
states_t r_curr_state, next_state;

// --- Instruction Type Defintion ---
typedef enum {
    U32, // B32
    U64,
    I32,
    I64,
    FP32
} inst_t;
inst_t r_inst_type, next_inst_type;

// --- VCC Mux Enum ---
typedef enum {
    COUT_AS_VCC,
    DATA_AS_VCC
} vcc_mux_t;
vcc_mux_t r_vcc_in_type, next_vcc_in_type;

// --- Functional Units Parameters ---
localparam MULT_WIDTH = VGPR_DATA_WIDTH + 1; // Multiplier is one bit larger to support both 32-bit signed & unsigned multiplication
localparam ADD_WIDTH = VGPR_DATA_WIDTH;
localparam LOGIC_UNIT_WIDTH = 2*VGPR_DATA_WIDTH;

// --- Signals and Registers ---
logic [1:0] r_omod, next_omod;
logic r_clamp, next_clamp;

logic r_vcc_we, next_vcc_we;
logic r_vdest_wb, next_vdest_wb;
logic r_sdest_wb, next_sdest_wb;

logic [2:0][VGPR_DATA_WIDTH-1:0] fp_neg_ssrc;
logic [2:0][VGPR_DATA_WIDTH-1:0] fp_abs_ssrc;
logic [2:0][VGPR_DATA_WIDTH-1:0] fp_ssrc;

logic [VGPR_DATA_WIDTH*2:0] output_data; // Output data is one bit bigger to allow for clamping
logic [1:0][VGPR_DATA_WIDTH-1:0] post_mod_output_data;

logic signed [MULT_WIDTH-1:0] mult_in_a, mult_in_b;
logic signed [MULT_WIDTH*2-1:0] r_mult_out;
logic mult_in_valid, r_mult_out_valid;

logic [ADD_WIDTH-1:0] add_sub_in_a, add_sub_in_b;
logic [ADD_WIDTH:0] r_add_sub_out;
logic add_sub_add, add_sub_cin;

logic [VGPR_DATA_WIDTH-1:0] fp32_mac_in_a, fp32_mac_in_b, fp32_mac_in_c, r_fp32_mac_out;
logic r_fp32_mac_in_ready, fp32_mac_in_valid, r_fp32_mac_result_valid;

logic [LOGIC_UNIT_WIDTH-1:0] logic_in_a, logic_in_b, logic_in_c, logic_out, r_logic_out;
logic_op_t logic_in_op;

logic [VGPR_DATA_WIDTH*2-1:0] scratch_data;

// --- Functional Units ---
// 33 x 33 Signed Multiplier
s_multiplier #(.WIDTH(MULT_WIDTH)) s_mult_0
(
    .clk(clk),
    .rst(rst),
    .in_valid(mult_in_valid),
    .a(mult_in_a),
    .b(mult_in_b),
    .out(r_mult_out),
    .out_valid(r_mult_out_valid),
    .out_ready(out_ready)
);

// 32-bit Unsigned Adder/Subtractor
u_add_sub #(.WIDTH(ADD_WIDTH)) u_add_sub_0
(
    .clk(clk),
    .rst(rst),
    .a(add_sub_in_a),
    .b(add_sub_in_b),
    .add(add_sub_add),
    .cin(add_sub_cin),
    .out(r_add_sub_out)
);

// FP32 Fused Multiply-Accumulate
fp32_mac fp32_mac_0
(
    .clk(clk),
    .rst(rst),
    .in_valid(fp32_mac_in_valid),
    .in_ready(r_fp32_mac_in_ready),
    .a_data(fp32_mac_in_a),
    .b_data(fp32_mac_in_b),
    .c_data(fp32_mac_in_c),
    .result_valid(r_fp32_mac_result_valid),
    .result_ready(out_ready),
    .result_data(r_fp32_mac_out)
);

// 64-bit Logic Unit
logic_unit #(.WIDTH(LOGIC_UNIT_WIDTH)) logic_unit_0
(
    .clk(clk),
    .rst(rst),
    .a(logic_in_a),
    .b(logic_in_b),
    .c(logic_in_c),
    .op(logic_in_op),
    .comb_out(logic_out),
    .out(r_logic_out)
);

// --- FP Input Modifier Block ---
always_comb begin
    // Prepare absolute output if needed for floating point instruction
    fp_abs_ssrc[0] = abs_fp32(vector_inst_in.abs[0], ssrc0[0]);
    fp_abs_ssrc[1] = abs_fp32(vector_inst_in.abs[1], ssrc1[0]);
    fp_abs_ssrc[2] = abs_fp32(vector_inst_in.abs[2], ssrc2[0]);
    // Prepare negated output if needed for floating point instruction
    fp_neg_ssrc[0] = neg_fp32(vector_inst_in.neg[0], fp_abs_ssrc[0]);
    fp_neg_ssrc[1] = neg_fp32(vector_inst_in.neg[1], fp_abs_ssrc[1]);
    fp_neg_ssrc[2] = neg_fp32(vector_inst_in.neg[2], fp_abs_ssrc[2]);

    for (int i = 0; i < 3; i++) begin
        fp_ssrc[i] = fp_neg_ssrc[i];
    end
end

// --- State Assignment Block + Input Assignment + Input/Output Control Signals ---
always_comb begin
    // Default Instruction Data Type
    next_inst_type = U32;

    // Default WB
    next_vcc_we = '0;
    next_sdest_wb = '0;
    next_vdest_wb = '0;

    // Default VCC Mux Selection
    next_vcc_in_type = COUT_AS_VCC;

    // Default FP32 Ouput Modifier Values
    next_omod = '0;
    next_clamp = '0;

    // Default FP32 MAC Values
    fp32_mac_in_valid = '0;
    fp32_mac_in_a = '0;
    fp32_mac_in_b = '0;
    fp32_mac_in_c = '0;

    // Default MULT Values
    mult_in_a = '0;
    mult_in_b = '0;
    mult_in_valid = '0;

    // Default Adder/Subtractor Values
    add_sub_in_a = '0;
    add_sub_in_b = '0;
    add_sub_add = '0;
    add_sub_cin = '0;

    // Default Logic Unit Values
    logic_in_a = '0;
    logic_in_b = '0;
    logic_in_c = '0;
    logic_in_op = OR;

    // Default Misc Values
    scratch_data = '0; // Used for misc operations

    unique case (r_curr_state)
        VECTOR_REST: begin
            // Default Next State
            next_state = VECTOR_REST;

            // By default, we are writing to VGPRs
            next_vdest_wb = '1;

            unique case(vector_inst_in.format)
                VOP2: begin
                    case(vector_inst_in.op)
                        V_MUL_F32: begin
                            // V_MUL_F32
                            fp32_mac_in_valid = 1'b1;
                            fp32_mac_in_a = ssrc0[0];
                            fp32_mac_in_b = vsrc;
                            fp32_mac_in_c = '0;

                            if (r_fp32_mac_in_ready) begin
                                next_state = VECTOR_FP_MAC_BUSY;
                            end
                            next_inst_type = FP32;
                        end
                        V_MUL_I32_I24: begin
                            // V_MUL_I32_I24
                            // Technically this is supposed to use the floating point core
                            // but just using the normal multiplier to make things easy for us.
                            mult_in_valid = 1'b1;
                            mult_in_a = {{(MULT_WIDTH-24){ssrc0[0][23]}}, ssrc0[0][23:0]};
                            mult_in_b = {{(MULT_WIDTH-24){vsrc[23]}}, vsrc[23:0]};

                            next_state = VECTOR_MULT_BUSY;
                            next_inst_type = I32;
                        end
                        V_MUL_U32_U24: begin
                            // V_MUL_U32_U24
                            // Technically this is supposed to use the floating point core
                            // but just using the normal multiplier to make things easy for us.
                            mult_in_valid = 1'b1;
                            mult_in_a = {{(MULT_WIDTH-24){1'b0}}, ssrc0[0][23:0]};
                            mult_in_b = {{(MULT_WIDTH-24){1'b0}}, vsrc[23:0]};

                            next_state = VECTOR_MULT_BUSY;
                            next_inst_type = U32;
                        end
                        V_LSHLREV_B32: begin
                            // V_LSHLREV_B32
                            logic_in_a[VGPR_DATA_WIDTH-1:0] = vsrc;
                            logic_in_b[4:0] = ssrc0[0][4:0];
                            logic_in_op = LSHFTL;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U32;
                        end
                        V_XOR_B32: begin
                            // V_XOR_B32
                            logic_in_a[VGPR_DATA_WIDTH-1:0] = ssrc0[0];
                            logic_in_b[VGPR_DATA_WIDTH-1:0] = vsrc;
                            logic_in_op = XOR;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U32;
                        end
                        V_ADD_NC_U32: begin
                            // V_ADD_NC_U32
                            add_sub_in_a = ssrc0[0];
                            add_sub_in_b = vsrc;
                            add_sub_add = 1'b1;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;
                        end
                        V_SUB_NC_U32: begin
                            // V_SUB_NC_U32
                            add_sub_in_a = ssrc0[0];
                            add_sub_in_b = vsrc;
                            add_sub_add = 1'b0;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;
                        end
                        V_SUBREV_NC_U32: begin
                            // V_SUBREV_NC_U32
                            add_sub_in_a = vsrc;
                            add_sub_in_b = ssrc0[0];
                            add_sub_add = 1'b0;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;
                        end
                        V_ADD_CO_CI_U32: begin
                            // V_ADD_CO_CI_U32
                            add_sub_in_a = ssrc0[0];
                            add_sub_in_b = vsrc;
                            add_sub_add = 1'b1;
                            add_sub_cin = vcc_in;

                            next_vcc_we = 1'b1;
                            next_vcc_in_type = COUT_AS_VCC;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;
                        end
                        V_FMAC_F32: begin
                            // V_FMAC_F32
                            fp32_mac_in_valid = 1'b1;
                            fp32_mac_in_a = ssrc0[0];
                            fp32_mac_in_b = vsrc;
                            fp32_mac_in_c = dst_data;

                            if (r_fp32_mac_in_ready) begin
                                next_state = VECTOR_FP_MAC_BUSY;
                            end
                            next_inst_type = FP32;
                        end
                        V_FMAMK_F32: begin
                            // V_FMAMK_F32
                            fp32_mac_in_valid = 1'b1;
                            fp32_mac_in_a = ssrc0[0];
                            fp32_mac_in_b = vector_inst_in.literal;
                            fp32_mac_in_c = vsrc;

                            if (r_fp32_mac_in_ready) begin
                                next_state = VECTOR_FP_MAC_BUSY;
                            end
                            next_inst_type = FP32;
                        end
                        default: begin
                            // Disable VGPR writeback if not valid instruction
                            next_vdest_wb = 1'b0;
                        end
                    endcase
                end
                VOP1: begin
                    case(vector_inst_in.op)
                        V_MOV_B32: begin
                            // V_MOV_B32
                            // Using adder with + 0 as bypass mechanism
                            add_sub_in_a = ssrc0[0];
                            add_sub_in_b = '0;
                            add_sub_add = 1'b1;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = FP32; // Set to FP32 type to do correct output modifiers
                        end
                        default: begin
                            // Disable VGPR writeback if not valid instruction
                            next_vdest_wb = 1'b0;
                        end
                    endcase
                end
                VOPC: begin
                    // Disable VGPR writeback as VOPC instructions don't writeback to VGPR
                    next_vdest_wb = 1'b0;

                    // Enable VCC writeback
                    next_vcc_we = 1'b1;

                    // Change VCC mux to use logic unit output
                    next_vcc_in_type = DATA_AS_VCC;

                    case(vector_inst_in.op)
                        V_CMP_LT_I32: begin
                            // V_CMP_LT_I32
                            logic_in_a = sign_extend_to_64(ssrc0[0]);
                            logic_in_b = sign_extend_to_64(vsrc);
                            logic_in_op = S_LT;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = I32;
                        end
                        V_CMP_GT_I32: begin
                            // V_CMP_GT_I32
                            logic_in_a = sign_extend_to_64(ssrc0[0]);
                            logic_in_b = sign_extend_to_64(vsrc);
                            logic_in_op = S_GT;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = I32;
                        end
                        V_CMP_EQ_U32: begin
                            // V_CMP_EQ_U32
                            logic_in_a[VGPR_DATA_WIDTH-1:0] = ssrc0[0];
                            logic_in_b[VGPR_DATA_WIDTH-1:0] = vsrc;
                            logic_in_op = EQ;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U32;
                        end
                        V_CMP_GT_U32: begin
                            // V_CMP_GT_U32
                            logic_in_a[VGPR_DATA_WIDTH-1:0] = ssrc0[0];
                            logic_in_b[VGPR_DATA_WIDTH-1:0] = vsrc;
                            logic_in_op = U_GT;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U32;
                        end
                        default: begin
                            // Disable vcc writeback if no valid instructions
                            next_vcc_we = 1'b1;
                        end
                    endcase
                end
                VINTRP: begin // No VINTRP instructions currently
                    // Disable writeback as no instructions
                    next_vdest_wb = 1'b0;
                end
                VOP3: begin
                    // Set clamp and omod bits as VOP3 instructions use them
                    next_clamp = vector_inst_in.clmp;
                    next_omod = vector_inst_in.omod;

                    case(vector_inst_in.op)
                        /* --- VOP3A  --- */
                        V_ASHRREV_I32: begin
                            // V_ASHRREV_I32
                            logic_in_a = sign_extend_to_64(ssrc1[0]);
                            logic_in_b[4:0] = ssrc0[0][4:0];
                            logic_in_op = ASHFTR;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = I32;
                        end
                        V_MAX3_I32: begin
                            // V_MAX3_I32
                            logic_in_a = sign_extend_to_64(ssrc0[0]);
                            logic_in_b = sign_extend_to_64(ssrc1[0]);
                            logic_in_c = sign_extend_to_64(ssrc2[0]);
                            logic_in_op = MAX3;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = I32;
                        end
                        V_MUL_LO_U32: begin
                            // V_MUL_LO_U32
                            mult_in_valid = 1'b1;
                            mult_in_a = {1'b0, ssrc0[0]};
                            mult_in_b = {1'b0, ssrc1[0]};

                            next_state = VECTOR_MULT_BUSY;
                            next_inst_type = U32;
                        end
                        V_LSHLREV_B64: begin
                            // V_LSHLREV_B64
                            logic_in_a = ssrc1;
                            logic_in_b[5:0] = ssrc0[0][5:0];
                            logic_in_op = LSHFTL;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U64;
                        end
                        V_LSHL_ADD_U32: begin
                            // V_LSHL_ADD_U32
                            add_sub_in_a = ssrc0[0] << ssrc1[0][4:0];
                            add_sub_in_b = ssrc2[0];
                            add_sub_add = 1'b1;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;
                        end
                        V_ADD3_U32: begin
                            // V_ADD3_U32
                            scratch_data[VGPR_DATA_WIDTH:0] = {1'b0, ssrc0[0]} + {1'b0, ssrc1[0]};
                            add_sub_in_a = scratch_data[VGPR_DATA_WIDTH-1:0];
                            add_sub_in_b = ssrc2[0];
                            add_sub_add = 1'b1;
                            add_sub_cin = scratch_data[VGPR_DATA_WIDTH];

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;
                        end
                        V_LSHL_OR_B32: begin
                            // V_LSHL_OR_B32
                            scratch_data[VGPR_DATA_WIDTH-1:0] = (ssrc0[0] << ssrc1[0][4:0]);
                            logic_in_a[VGPR_DATA_WIDTH-1:0] = scratch_data[VGPR_DATA_WIDTH-1:0];
                            logic_in_b[VGPR_DATA_WIDTH-1:0] = ssrc2[0];
                            logic_in_op = OR;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U32;
                        end
                        /* --- VOP3B --- */
                        // V_MAD_U64_U32: begin
                            // V_MAD_U64_U32 
                            // TODO: This instruction is not currently supported
                        //     mult_in_valid = 1'b1;
                        //     mult_in_a = {1'b0, ssrc0[0]};
                        //     mult_in_b = {1'b0, ssrc1[0]};

                        //     next_state = VECTOR_MULT_BUSY;
                        //     next_inst_type = U64;

                        //     // Might need to write to SDST for this instruction

                        //     pre_clamp_output = ssrc0[0] * ssrc1[0] + {2'b0, ssrc2};
                        //     post_modif_output = clamp_uint64(vector_inst_in.clmp, pre_clamp_output);

                        //     // Since each element of pre_clamp_output is 33 bits, the carryout would be
                        //     // on bit index 31 of the second element as 65 bits = 33 bits (first element)
                        //     // + 32 bits(second element)
                        //     vcc_out = pre_clamp_output[1][31];
                        //     vcc_we = 1'b1;
                        // end
                        V_ADD_CO_U32: begin
                            // V_ADD_CO_U32
                            add_sub_in_a = ssrc0[0];
                            add_sub_in_b = ssrc1[0];
                            add_sub_add = 1'b1;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;

                            // SDEST used for carryout
                            next_sdest_wb = 1'b1;
                        end
                        /* --- VOP2 as VOP3 --- */
                        VOP3_V_MUL_F32: begin
                            // V_MUL_F32
                            fp32_mac_in_valid = 1'b1;
                            fp32_mac_in_a = fp_ssrc[0];
                            fp32_mac_in_b = fp_ssrc[1];
                            fp32_mac_in_c = '0;

                            if (r_fp32_mac_in_ready) begin
                                next_state = VECTOR_FP_MAC_BUSY;
                            end
                            next_inst_type = FP32;
                        end
                        VOP3_V_MUL_I32_I24: begin
                            // V_MUL_I32_I24
                            // Technically this is supposed to use the floating point core
                            // but just using the normal multiplier to make things easy for us.
                            mult_in_valid = 1'b1;
                            mult_in_a = {{(MULT_WIDTH-24){ssrc0[0][23]}}, ssrc0[0][23:0]};
                            mult_in_b = {{(MULT_WIDTH-24){ssrc1[0][23]}}, ssrc1[0][23:0]};

                            next_state = VECTOR_MULT_BUSY;
                            next_inst_type = I32;
                        end
                        VOP3_V_MUL_U32_U24: begin
                            // V_MUL_U32_U24
                            // Technically this is supposed to use the floating point core
                            // but just using the normal multiplier to make things easy for us.
                            mult_in_valid = 1'b1;
                            mult_in_a = {{(MULT_WIDTH-24){1'b0}}, ssrc0[0][23:0]};
                            mult_in_b = {{(MULT_WIDTH-24){1'b0}}, ssrc1[0][23:0]};

                            next_state = VECTOR_MULT_BUSY;
                            next_inst_type = U32;
                        end
                        VOP3_V_LSHLREV_B32: begin
                            // V_LSHLREV_B32
                            logic_in_a[VGPR_DATA_WIDTH-1:0] = ssrc1[0];
                            logic_in_b[4:0] = ssrc0[0][4:0];
                            logic_in_op = LSHFTL;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U32;
                        end
                        VOP3_V_XOR_B32: begin
                            // V_XOR_B32
                            logic_in_a[VGPR_DATA_WIDTH-1:0] = ssrc0[0];
                            logic_in_b[VGPR_DATA_WIDTH-1:0] = ssrc1[0];
                            logic_in_op = XOR;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U32;
                        end
                        VOP3_V_ADD_NC_U32: begin
                            // V_ADD_NC_U32
                            add_sub_in_a = ssrc0[0];
                            add_sub_in_b = ssrc1[0];
                            add_sub_add = 1'b1;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;
                        end
                        VOP3_V_SUB_NC_U32: begin
                            // V_SUB_NC_U32
                            add_sub_in_a = ssrc0[0];
                            add_sub_in_b = ssrc1[0];
                            add_sub_add = 1'b0;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;
                        end
                        VOP3_V_SUBREV_NC_U32: begin
                            // V_SUBREV_NC_U32
                            add_sub_in_a = ssrc1[0];
                            add_sub_in_b = ssrc0[0];
                            add_sub_add = 1'b0;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;
                        end
                        VOP3_V_ADD_CO_CI_U32: begin
                            // V_ADD_CO_CI_U32
                            // VOP3B
                            add_sub_in_a = ssrc0[0];
                            add_sub_in_b = ssrc1[0];
                            add_sub_add = 1'b1;
                            add_sub_cin = ssrc2[0][0]; // VCC source might be entire 32-bit SGPR

                            // SDEST used for carryout
                            next_sdest_wb = 1'b1;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = U32;

                            // Unsure if carry out is still outputed to VCC if SDEST is used
                            // vcc_out = pre_clamp_output[0][32];
                            // vcc_we = 1'b1;
                        end
                        VOP3_V_FMAC_F32: begin
                            // V_FMAC_F32
                            fp32_mac_in_valid = 1'b1;
                            fp32_mac_in_a = fp_ssrc[0];
                            fp32_mac_in_b = fp_ssrc[1];
                            fp32_mac_in_c = dst_data;

                            if (r_fp32_mac_in_ready) begin
                                next_state = VECTOR_FP_MAC_BUSY;
                            end
                            next_inst_type = FP32;
                        end
                        // No VOP3_V_FMAMK_F32 as explicitly excluded in spec
                        /* --- VOP1 as VOP3 --- */
                        VOP3_V_MOV_B32: begin
                            // V_MOV_B32 - VOP3A
                            // Using adder with + 0 as bypass mechanism
                            add_sub_in_a = fp_ssrc[0];
                            add_sub_in_b = '0;
                            add_sub_add = 1'b1;
                            add_sub_cin = 1'b0;

                            next_state = VECTOR_ADD_BUSY;
                            next_inst_type = FP32; // Set to FP32 type to do correct output modifiers
                        end
                        /* --- VOPC as VOP3A --- */
                        // Note: Ignoring when CLAMP=1, NaN inputs should cause an exception as we don't have
                        // exception hardware
                        // Note: Unknown if instructions should output to VCC, SGPR, or VGPR. There is
                        // conflicting information: some pages in doc mention writing to SGPR, other parts of
                        // docs mention VOPC instructions can only be VOP3A which can't output to SGPR, and
                        // the actual instructions just write to VGPR. Currently assuming the VGPR write is
                        // correct.
                        VOP3_V_CMP_LT_I32: begin
                            // V_CMP_LT_I32
                            logic_in_a = sign_extend_to_64(ssrc0[0]);
                            logic_in_b = sign_extend_to_64(ssrc1[0]);
                            logic_in_op = S_LT;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = I32;
                        end
                        VOP3_V_CMP_GT_I32: begin
                            // V_CMP_GT_I32
                            logic_in_a = sign_extend_to_64(ssrc0[0]);
                            logic_in_b = sign_extend_to_64(ssrc1[0]);
                            logic_in_op = S_GT;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = I32;
                        end
                        VOP3_V_CMP_EQ_U32: begin
                            // V_CMP_EQ_U32
                            logic_in_a[VGPR_DATA_WIDTH-1:0] = ssrc0[0];
                            logic_in_b[VGPR_DATA_WIDTH-1:0] = ssrc1[0];
                            logic_in_op = EQ;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U32;
                        end
                        VOP3_V_CMP_GT_U32: begin
                            // V_CMP_GT_U32
                            logic_in_a[VGPR_DATA_WIDTH-1:0] = ssrc0[0];
                            logic_in_b[VGPR_DATA_WIDTH-1:0] = ssrc1[0];
                            logic_in_op = U_GT;

                            next_state = VECTOR_LOGIC_BUSY;
                            next_inst_type = U32;
                        end
                        default: begin
                            // Disable VGPR writeback if not valid instruction
                            next_vdest_wb = 1'b0;
                        end
                    endcase
                end
                VOP3P: begin
                    // No VOP3P instructions currently are needed

                    // Disable writeback as no instructions
                    next_vdest_wb = 1'b0;
                end
                default: begin
                    // Shouldn't get here, but disabling VGPR writeback just in case
                    next_vdest_wb = 1'b0;
                end
            endcase
        end
        VECTOR_MULT_BUSY: begin
            // Need to wait for Multiplier to finish before changing state
            if (r_mult_out_valid) begin
                next_state = VECTOR_REST;
            end else begin
                next_state = VECTOR_FP_MAC_BUSY;
            end
        end
        VECTOR_FP_MAC_BUSY: begin
            // Need to wait for FP32 MAC to finish before changing state
            if (r_fp32_mac_result_valid) begin
                next_state = VECTOR_REST;
            end else begin
                next_state = VECTOR_FP_MAC_BUSY;
            end
        end
        // Addition and logic unit only take one cycle so can immediately go to
        // rest state
        VECTOR_ADD_BUSY: begin
            next_state = VECTOR_REST;
        end
        VECTOR_LOGIC_BUSY: begin
            next_state = VECTOR_REST;
        end
        default: begin
            // Go to rest state if in undetermined state
            next_state = VECTOR_REST;
        end
    endcase
end

// --- Intermediary Value Update Block ---
always_ff @(posedge clk) begin
    if (rst) begin
        r_omod <= '0;
        r_clamp <= '0;
        r_vcc_we <= '0;
        r_vdest_wb <= '0;
        r_sdest_wb <= '0;
        r_inst_type <= U32;
        r_vcc_in_type <= COUT_AS_VCC;
    end else begin
        if (r_curr_state == VECTOR_REST && next_state != VECTOR_REST) begin // || (next_state == VECTOR_REST && out_ready)
            r_omod <= next_omod;
            r_clamp <= next_clamp;
            r_vcc_we <= next_vcc_we;
            r_vdest_wb <= next_vdest_wb;
            r_sdest_wb <= next_sdest_wb;
            r_inst_type <= next_inst_type;
            r_vcc_in_type <= next_vcc_in_type;
        end
    end
end

// --- Function Unit Output Mux ---
// Output data from function units must be one larger than data output width
// in order to support clamping in clamp step
// Unsigned numbers are zero-extended if functional unit output is not large
// enough
// Signed numbers are sign-extended if functional unit output is not large
// enough
always_comb begin
    output_data = '0;
    unique case(r_curr_state)
        VECTOR_REST: begin
            // No data output at rest state
        end
        VECTOR_MULT_BUSY: begin
            unique case(r_inst_type)
                // Multiplier output needs to be based off data output type. Data may
                // need to be sign-extended or zero-extended.
                // Output will only be 32-bit or 64-bit. Clamping won't be possible
                // with multiplying as multiplier output is already double the
                // input widths and the current clamping mechanism can't handle it.
                U32: begin
                    output_data[VGPR_DATA_WIDTH:0] = {1'b0, r_mult_out[VGPR_DATA_WIDTH-1:0]};
                end
                I32: begin
                    output_data[VGPR_DATA_WIDTH:0] = {r_mult_out[VGPR_DATA_WIDTH-1], r_mult_out[VGPR_DATA_WIDTH-1:0]};
                end
                U64: begin
                    output_data = {1'b0, r_mult_out[VGPR_DATA_WIDTH*2-1:0]};
                end
                I64: begin
                    output_data = {r_mult_out[VGPR_DATA_WIDTH*2-1], r_mult_out[VGPR_DATA_WIDTH*2-1:0]};
                end
                FP32: begin
                    // Nothing here as the multiplier block is only for non-FP32 types
                end
                default: begin
                end
            endcase
        end
        VECTOR_FP_MAC_BUSY: begin
            // FP32 MAC directly outputs data in 32-bit format so direct output is possible
            output_data[VGPR_DATA_WIDTH-1:0] = r_fp32_mac_out;
        end
        VECTOR_ADD_BUSY: begin
            // Adder directly outputs into WIDTH+1 so zero-extension not needed
            // Adder unsigned so only U32 supported
            output_data[VGPR_DATA_WIDTH:0] = r_add_sub_out;
        end
        VECTOR_LOGIC_BUSY: begin
            // Logic unit only works on 32-bit data without care of sign so direct output
            // is possible
            output_data[VGPR_DATA_WIDTH-1:0] = r_logic_out[VGPR_DATA_WIDTH-1:0];
        end
        default: begin
        end
    endcase
end

// --- Output Modifer Block ---
// Expects output data to be one larger than desired output width in order
// to clamp properly, except for FP32
always_comb begin
    post_mod_output_data = '0;
    if (r_clamp) begin
        unique case (r_inst_type)
            U32: begin
                post_mod_output_data[0] = clamp_uint32(output_data[VGPR_DATA_WIDTH:0]);
            end
            U64: begin
                post_mod_output_data = clamp_uint64(output_data);
            end
            I32: begin
                post_mod_output_data[0] = clamp_int32(output_data[VGPR_DATA_WIDTH:0]);
            end
            I64: begin
                post_mod_output_data = clamp_int64(output_data);
            end
            FP32: begin
                post_mod_output_data[0] = omod_fp32(r_omod, clamp_fp32(output_data[VGPR_DATA_WIDTH-1:0]));
            end
            default: begin
                // Just pass data through without output mods
                post_mod_output_data = output_data[VGPR_DATA_WIDTH*2-1:0];
            end
        endcase
    end else begin
        unique case (r_inst_type)
            U32: begin
                post_mod_output_data[0] = output_data[VGPR_DATA_WIDTH-1:0];
            end
            U64: begin
                post_mod_output_data = output_data[VGPR_DATA_WIDTH*2-1:0];
            end
            I32: begin
                post_mod_output_data[0] = output_data[VGPR_DATA_WIDTH-1:0];
            end
            I64: begin
                post_mod_output_data = output_data[VGPR_DATA_WIDTH*2-1:0];
            end
            FP32: begin
                post_mod_output_data[0] = omod_fp32(r_omod, output_data[VGPR_DATA_WIDTH-1:0]);
            end
            default: begin
                // Just pass data through
                post_mod_output_data = output_data[VGPR_DATA_WIDTH*2-1:0];
            end
        endcase
    end
end

// --- Output Port Assignment Block ---
assign next_busy = next_state != VECTOR_REST; // Busy is only when next state is work
always_ff @(posedge clk) begin
    if (rst) begin
        out_valid <= '0;
        vcc_out <= '0;
        vcc_we <= '0;
        vdest_out <= '0;
        vdest_wb <= '0;
        sdest_out <= '0;
        sdest_wb <= '0;
        busy <= '0;
    end else begin
        // Busy Signal Assignment
        busy <= next_busy;

        // Data Output Assignment
        sdest_out <= {{(SGPR_DATA_WIDTH*2-1){1'b0}}, output_data[VGPR_DATA_WIDTH-1]}; // SDEST is only used for VCC output for select instructions
        vdest_out <= post_mod_output_data;

        // VCC Output Assignment
        unique case(r_vcc_in_type)
            COUT_AS_VCC: begin
                vcc_out <= output_data[VGPR_DATA_WIDTH];
            end
            DATA_AS_VCC: begin
                vcc_out <= output_data[0];
            end
            default: begin
                vcc_out <= '0;
            end
        endcase

        // Write Enable Assignment
        unique case (r_curr_state)
            VECTOR_REST: begin
                out_valid <= '0;
                vcc_we <= '0;
                vdest_wb <= '0;
                sdest_wb <= '0;
            end
            VECTOR_MULT_BUSY: begin
                out_valid <= r_mult_out_valid;
                vcc_we <= r_mult_out_valid & r_vcc_we;
                vdest_wb <= r_mult_out_valid & r_vdest_wb;
                sdest_wb <= r_mult_out_valid & r_sdest_wb;
            end
            VECTOR_FP_MAC_BUSY: begin
                out_valid <= r_fp32_mac_result_valid;
                vcc_we <= r_fp32_mac_result_valid & r_vcc_we;
                vdest_wb <= r_fp32_mac_result_valid & r_vdest_wb;
                sdest_wb <= r_fp32_mac_result_valid & r_sdest_wb;
            end
            // Add and Logic operations are only one cycle so write enables
            // can passed through immedietly
            VECTOR_ADD_BUSY: begin
                out_valid <= 1'b1;
                vcc_we <= r_vcc_we;
                vdest_wb <= r_vdest_wb;
                sdest_wb <= r_sdest_wb;
            end
            VECTOR_LOGIC_BUSY: begin
                out_valid <= 1'b1;
                vcc_we <= r_vcc_we;
                vdest_wb <= r_vdest_wb;
                sdest_wb <= r_sdest_wb;
            end
            default: begin
                // If in bad state, don't write
                out_valid <= '0;
                vcc_we <= '0;
                vdest_wb <= '0;
                sdest_wb <= '0;
            end
        endcase

    end
end

// --- Update Current State Block ---
always_ff @(posedge clk) begin
    if (rst) begin
        r_curr_state <= VECTOR_REST;
    end else begin
        r_curr_state <= next_state;
    end
end

endmodule

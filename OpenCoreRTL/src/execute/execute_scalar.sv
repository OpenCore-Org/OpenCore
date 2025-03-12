/*
    Execute stage p2 for Scalar ALU Instructions
    NOTE: for SOPK instructions, value in destiation register is expected in src1
*/

module execute_scalar
import common_pkg::*;
import mem_pkg::*;
import scalar_op_pkg::*;
(
    input scalar_inst_t scalar_inst_in,
    input logic [SGPR_DATA_WIDTH-1:0] src0,
    input logic [SGPR_DATA_WIDTH-1:0] src1,
    input logic [SGPR_DATA_WIDTH-1:0] src2,
    input logic [SGPR_DATA_WIDTH-1:0] src3,
    input logic scc_in,
    input logic [47:0] pc_in,
    input logic vccz_in,
    input logic execz_in,

    output logic [SGPR_DATA_WIDTH-1:0] dest_value,
    output logic [SGPR_DATA_WIDTH-1:0] dest_value_upper_32,
    output logic scc,
    output logic scc_we,
    output logic [47:0] pc,
    output logic pc_we,
    output logic active,
    output logic active_we,
    output logic barrier,
    output logic barrier_we
);


    function logic [31:0] sign_extend_16_to_32 (logic [15:0] src);
        sign_extend_16_to_32 = { {16{src[15]}}, src[15:0] };
    endfunction

    function logic [47:0] sign_extend_16_to_48 (logic [15:0] src);
        sign_extend_16_to_48 = { {32{src[15]}}, src[15:0] };
    endfunction

    logic [32:0] extended_sum;
    logic [63:0] temp_64_bits;

    /*
        For scc (Scalar Condition Code):
            Compare operations: 1 = true
            Arithmetic operations: 1 = carry out
            Bit/logical operations: 1 = result was not zero
            Move: does not alter scc
        scc_we is high (1) when scc is being written to and low (0) when it is not
    */


    // SM for tracking which portion of instruction
    always_comb begin
        dest_value = '0;
        dest_value_upper_32 = '0;
        scc = '0;
        pc = '0;
        active = '0;
        barrier = '0;
        extended_sum = '0;
        scc_we = '0;
        pc_we = '0;
        active_we = '0;
        barrier_we = '0;
        temp_64_bits = '0;

        case(scalar_inst_in.format)
            SOP2: begin
                case(scalar_inst_in.op)
                    SOP2_ADD_U32: begin
                        // S_ADD_U32
                        extended_sum = {1'b0, src0} + {1'b0, src1};
                        dest_value = extended_sum[31:0];
                        scc = extended_sum[32];
                        scc_we = 1;
                    end
                    SOP2_SUB_U32: begin
                        // S_SUB_U32
                        dest_value = src0 - src1;
                        scc = (src1 > src0 ? 1 : 0); // unsigned overflow or carry-out for S_SUBB_U32
                        scc_we = 1;
                    end
                    SOP2_ADD_I32: begin
                        // S_ADD_I32
                        dest_value = src0 + src1;
                        scc = (src0[31] == src1[31] && src0[31] != dest_value[31]); // signed overflow.
                        scc_we = 1;
                    end
                    SOP2_SUB_I32: begin
                        // S_SUB_I32
                        dest_value = src0 - src1;
                        scc = (src0[31] != src1[31] && src0[31] != dest_value[31]); // signed overflow.
                        scc_we = 1;
                    end
                    SOP2_ADDC_U32: begin
                        // S_ADDC_U32
                        dest_value = src0 + src1 + {31'b0, scc_in};
                        scc = ({32'b0, src0} + {32'b0, src1} + {63'b0, scc_in}) >= 64'h100000000;
                        scc_we = 1;
                    end
                    SOP2_SUBB_U32: begin
                        // S_SUBB_U32
                        dest_value = src0 - src1 - {31'b0, scc_in};
                        scc = ((src1 + {31'b0, scc_in}) > src0 ? 1'b1 : 1'b0); // unsigned overflow.
                        scc_we = 1;
                    end
                    SOP2_MIN_I32: begin
                        // S_MIN_I32
                        dest_value = ($signed(src0) < $signed(src1)) ? src0 : src1;
                        scc = ($signed(src0) < $signed(src1));
                        scc_we = 1;
                    end
                    SOP2_MIN_U32: begin
                        // S_MIN_U32
                        dest_value = (src0 < src1) ? src0 : src1;
                        scc = (src0 < src1);
                        scc_we = 1;
                    end
                    SOP2_MAX_I32: begin
                        // S_MAX_I32
                        dest_value = ($signed(src0) > $signed(src1)) ? src0 : src1;
                        scc = ($signed(src0) > $signed(src1));
                        scc_we = 1;
                    end
                    SOP2_MAX_U32: begin
                        // S_MAX_U32
                        dest_value = (src0 > src1) ? src0 : src1;
                        scc = (src0 > src1);
                        scc_we = 1;
                    end
                    SOP2_CSELECT_B32: begin
                        // S_CSELECT_B32
                        dest_value = scc_in ? src0 : src1;
                    end
                    SOP2_CSELECT_B64: begin
                        // S_CSELECT_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value64 = scc ? src064 : src164;
                    end
                    SOP2_AND_B32: begin
                        // S_AND_B32
                        dest_value = src0 & src1;
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_AND_B64: begin
                        // S_AND_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value = src0 & src1;
                        // scc = (dest_value != 0);
                    end
                    SOP2_OR_B32: begin
                        // S_OR_B32
                        dest_value = src0 | src1;
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_OR_B64: begin
                        // S_OR_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value = src0 | src1;
                        // scc = (dest_value != 0);
                    end
                    SOP2_XOR_B32: begin
                        // S_XOR_B32
                        dest_value = src0 ^ src1;
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_XOR_B64: begin
                        // S_XOR_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value = src0 ^ src1;
                        // scc = (dest_value != 0);
                    end
                    SOP2_ANDN2_B32: begin
                        // S_ANDN2_B32
                        dest_value = src0 & ~src1;
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_ANDN2_B64: begin
                        // S_ANDN2_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value = src0 & ~src1;
                        // scc = (dest_value != 0);
                    end
                    SOP2_ORN2_B32: begin
                        // S_ORN2_B32
                        dest_value = src0 | ~src1;
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_ORN2_B64: begin
                        // S_ORN2_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value = src0 | ~src1;
                        // scc = (dest_value != 0);
                    end
                    SOP2_NAND_B32: begin
                        // S_NAND_B32
                        dest_value = ~(src0 & src1);
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_NAND_B64: begin
                        // S_NAND_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value = ~(src0 & src1);
                        // scc = (dest_value != 0);
                    end
                    SOP2_NOR_B32: begin
                        // S_NOR_B32
                        dest_value = ~(src0 | src1);
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_NOR_B64: begin
                        // S_NOR_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value = ~(src0 | src1);
                        // scc = (dest_value != 0);
                    end
                    SOP2_XNOR_B32: begin
                        // S_XNOR_B32
                        dest_value = ~(src0 ^ src1);
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_XNOR_B64: begin
                        // S_XNOR_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value = ~(src0 ^ src1);
                        // scc = (dest_value != 0);
                    end
                    SOP2_LSHL_B32: begin
                        // S_LSHL_B32
                        dest_value = src0 << src1[4:0];
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_LSHL_B64: begin
                        // S_LSHL_B64
                        // TODO Implement support for 64 bit operations
                        temp_64_bits = {src0, src2} << src1[5:0];
                        dest_value = temp_64_bits[31:0];
                        dest_value_upper_32 = temp_64_bits[63:32];
                        scc = (dest_value != 0) && (dest_value_upper_32 != 0);
                    end
                    SOP2_LSHR_B32: begin
                        // S_LSHR_B32
                        dest_value = src0 >> src1[4:0];
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_LSHR_B64: begin
                        // S_LSHR_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value64 = src064 >> src1[5:0];
                        // scc = (dest_value64 != 0);
                    end
                    SOP2_ASHR_I32: begin
                        // S_ASHR_I32
                        dest_value = src0 >>> src1[4:0];
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_ASHR_I64: begin
                        // S_ASHR_I64
                        // TODO Implement support for 64 bit operations
                        // dest_value64 = src064 >>> src1[5:0];
                        // scc = (dest_value64 != 0);
                    end
                    SOP2_BFM_B32: begin
                        // S_BFM_B32
                        dest_value = ((1 << src0[4:0]) - 1) << src1[4:0];
                    end
                    SOP2_BFM_B64: begin
                        // S_BFM_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value64 = ((1ULL << src0[5:0]) - 1) << src1[5:0];
                    end
                    SOP2_MUL_I32: begin
                        // S_MUL_I32
                        dest_value = $signed(src0) * $signed(src1);
                    end
                    SOP2_BFE_U32: begin
                        // S_BFE_U32
                        dest_value = (src0 >> src1[4:0]) & ((1 << src1[22:16]) - 1);
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_BFE_I32: begin
                        // S_BFE_I32
                        // Bit field extract. src0 is Data, src1[4:0] is field offset, src1[22:16] is field width
                        dest_value = (src0 >>> src1[4:0]) & ((1 << src1[22:16]) - 1);
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_BFE_U64: begin
                        // S_BFE_U64
                        // TODO Implement support for 64 bit operations
                        // dest_value64 = (src064 >> src1[5:0]) & ((1 << src1[22:16]) - 1);
                        // scc = (dest_value64 != 0);
                    end
                    SOP2_BFE_I64: begin
                        // S_BFE_I64
                        // Bit field extract. src0 is Data, src1[5:0] is field offset, src1[22:16] is field width
                        // dest_value64 = (src064 >>> src1[5:0]) & ((1 << src1[22:16]) - 1);
                        // scc = (dest_value64 != 0);
                    end
                    SOP2_ABSDIFF_I32: begin
                        // S_ABSDIFF_I32
                        // Compute the absolute value of difference between two values.
                        dest_value = ($signed(src0 - src1) < 0) ? src1 - src0 : src0 - src1;
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP2_LSHL1_ADD_U32: begin
                        // S_LSHL1_ADD_U32
                        dest_value = (src0 << 1) + src1; // N is the shift value in the opcode
                        scc = ((({32'b0, src0} << 1) + {32'b0, src1}) >= 64'h100000000 ? 1 : 0); // unsigned overflow.
                        scc_we = 1;
                    end
                    SOP2_LSHL2_ADD_U32: begin
                        // S_LSHL2_ADD_U32
                        dest_value = (src0 << 2) + src1; // N is the shift value in the opcode
                        scc = ((({32'b0, src0} << 2) + {32'b0, src1}) >= 64'h100000000 ? 1 : 0); // unsigned overflow.
                        scc_we = 1;
                    end
                    SOP2_LSHL3_ADD_U32: begin
                        // S_LSHL3_ADD_U32
                        dest_value = (src0 << 3) + src1; // N is the shift value in the opcode
                        scc = ((({32'b0, src0} << 3) + {32'b0, src1}) >= 64'h100000000 ? 1 : 0); // unsigned overflow.
                        scc_we = 1;
                    end
                    SOP2_LSHL4_ADD_U32: begin
                        // S_LSHL4_ADD_U32
                        dest_value = (src0 << 4) + src1; // N is the shift value in the opcode
                        scc = ((({32'b0, src0} << 4) + {32'b0, src1}) >= 64'h100000000 ? 1 : 0); // unsigned overflow
                        scc_we = 1;
                    end
                    SOP2_PACK_LL_B32_B16: begin
                        // S_PACK_LL_B32_B16
                        dest_value[31:0] = { src1[15:0], src0[15:0] };
                    end
                    SOP2_PACK_LH_B32_B16: begin
                        // S_PACK_LH_B32_B16
                        dest_value[31:0] = { src1[31:16], src0[15:0] };
                    end
                    SOP2_PACK_HH_B32_B16: begin
                        // S_PACK_HH_B32_B16
                        dest_value[31:0] = { src1[31:16], src0[31:16] };
                    end
                    SOP2_MUL_HI_U32: begin
                        // S_MUL_HI_U32
                        dest_value = (src0 * src1) >> 32;
                    end
                    SOP2_MUL_HI_I32: begin
                        // S_MUL_HI_I32
                        dest_value = ($signed(src0) * $signed(src1)) >> 32;
                    end
                    default:;
                endcase
            end
            SOP1: begin
                case(scalar_inst_in.op)
                    SOP1_MOV_B32: begin
                        // S_MOV_B32
                        dest_value = src0;
                    end
                    SOP1_MOV_B64: begin
                        // S_MOV_B64
                        // TODO Implement support for 64 bit operations
                        // D.u64 = S0.u64.
                    end
                    SOP1_CMOV_B32: begin
                        // S_CMOV_B32
                        if(scc_in) begin
                            dest_value = src0;
                        end
                    end
                    SOP1_CMOV_B64: begin
                        // S_CMOV_B64
                        // TODO Implement support for 64 bit operations
                        // if(scc_in) begin
                        //     dest_value = src0;
                        // end
                    end
                    SOP1_NOT_B32: begin
                        // S_NOT_B32
                        dest_value = ~src0;
                        scc = (dest_value != 0);
                        scc_we = 1;
                    end
                    SOP1_NOT_B64: begin
                        // S_NOT_B64
                        // TODO Implement support for 64 bit operations
                        // dest_value = ~S0;
                        // scc = (dest_value != 0).
                    end
                    SOP1_WQM_B32: begin
                        // S_WQM_B32
                        // Computes whole quad mode for an active/valid mask. 
                        // If any pixel in a quad is active, all pixels of the quad are marked active.
                        // TODO
                        // for (integer i = 0; i<32; i=i+1) begin
                        //     dest_value[i] = (src0[(i & ~3):(i | 3)] != 0);
                        // end
                        // scc = (dest_value != 0);
                    end
                    SOP1_WQM_B64: begin
                        // S_WQM_B64
                        // Computes whole quad mode for an active/valid mask. 
                        // If any pixel in a quad is active, all pixels of the quad are marked active.
                        // TODO Implement support for 64 bit operations
                        // for (integer i = 0; i<64; i=i+1) begin
                        //     dest_value[i] = (src0[(i & ~3):(i | 3)] != 0);
                        // end
                        // scc = (dest_value != 0);
                    end
                    SOP1_BREV_B32: begin
                        // S_BREV_B32
                        dest_value[31:0] = {<< {src0}};
                    end
                    SOP1_BREV_B64: begin
                        // S_BREV_B64
                        // TODO Implement support for 64 bit operations
                        // D.u64[63:0] = S0.u64[0:63].
                    end
                    SOP1_BCNT0_I32_B32: begin
                        // S_BCNT0_I32_B32
                        // Count number of bits that are zero.
                        // TODO
                        // dest_value = 0;
                        // for i in 0 ... opcode_size_in_bits - 1 do
                        //     dest_value += (S0[i] == 0 ? 1 : 0)
                        // endfor;
                        // scc = (dest_value != 0).
                    end
                    SOP1_BCNT0_I32_B64: begin
                        // S_BCNT0_I32_B64
                        // Count number of bits that are zero.
                        // TODO Implement support for 64 bit operations
                        // dest_value = 0;
                        // for i in 0 ... opcode_size_in_bits - 1 do
                        //     dest_value += (S0[i] == 0 ? 1 : 0)
                        // endfor;
                        // scc = (dest_value != 0).
                    end
                    SOP1_BCNT1_I32_B32: begin
                        // S_BCNT1_I32_B32
                        // Count number of bits that are one.
                        // TODO
                        // dest_value = 0;
                        // for i in 0 ... opcode_size_in_bits - 1 do
                        //     dest_value += (S0[i] == 1 ? 1 : 0)
                        // endfor;
                        // scc = (dest_value != 0).
                    end
                    SOP1_BCNT1_I32_B64: begin
                        // S_BCNT1_I32_B64
                        // Count number of bits that are one.
                        // TODO Implement support for 64 bit operations
                        // dest_value = 0;
                        // for i in 0 ... opcode_size_in_bits - 1 do
                        //     dest_value += (S0[i] == 1 ? 1 : 0)
                        // endfor;
                        // scc = (dest_value != 0).
                    end
                    SOP1_FF0_I32_B32: begin
                        // S_FF0_I32_B32
                        // TODO
                    end
                    SOP1_FF0_I32_B64: begin
                        // S_FF0_I32_B64
                        // TODO
                    end
                    SOP1_FF1_I32_B32: begin
                        // S_FF1_I32_B32
                        // TODO
                    end
                    SOP1_FF1_I32_B64: begin
                        // S_FF1_I32_B64
                        // TODO
                    end
                    SOP1_FLBIT_I32_B32: begin
                        // S_FLBIT_I32_B32
                        // TODO
                    end
                    SOP1_FLBIT_I32_B64: begin
                        // S_FLBIT_I32_B64
                        // TODO
                    end
                    SOP1_FLBIT_I32: begin
                        // S_FLBIT_I32
                        // TODO
                    end
                    SOP1_FLBIT_I32_I64: begin
                        // S_FLBIT_I32_I64
                        // TODO
                    end
                    SOP1_SEXT_I32_I8: begin
                        // S_SEXT_I32_I8
                        // TODO
                    end
                    SOP1_SEXT_I32_I16: begin
                        // S_SEXT_I32_I16
                        // TODO
                    end
                    SOP1_BITSET0_B32: begin
                        // S_BITSET0_B32
                        // TODO
                    end
                    SOP1_BITSET0_B64: begin
                        // S_BITSET0_B64
                        // TODO
                    end
                    SOP1_BITSET1_B32: begin
                        // S_BITSET1_B32
                        // TODO
                    end
                    SOP1_BITSET1_B64: begin
                        // S_BITSET1_B64
                        // TODO
                    end
                    SOP1_GETPC_B64: begin
                        // S_GETPC_B64
                        {dest_value_upper_32, dest_value} = {16'b0, $unsigned(pc + 4)};
                    end
                    SOP1_SETPC_B64: begin
                        // S_SETPC_B64
                        pc = {src2[15:0], src0};
                        pc_we = 1'b1;
                    end
                    SOP1_SWAPPC_B64: begin
                        // S_SWAPPC_B64
                        // TODO
                    end
                    SOP1_RFE_B64: begin
                        // S_RFE_B64
                        // TODO
                    end
                    SOP1_AND_SAVEEXEC_B64: begin
                        // S_AND_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_OR_SAVEEXEC_B64: begin
                        // S_OR_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_XOR_SAVEEXEC_B64: begin
                        // S_XOR_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_ANDN2_SAVEEXEC_B64: begin
                        // S_ANDN2_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_ORN2_SAVEEXEC_B64: begin
                        // S_ORN2_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_NAND_SAVEEXEC_B64: begin
                        // S_NAND_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_NOR_SAVEEXEC_B64: begin
                        // S_NOR_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_XNOR_SAVEEXEC_B64: begin
                        // S_XNOR_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_QUADMASK_B32: begin
                        // S_QUADMASK_B32
                        // TODO
                    end
                    SOP1_QUADMASK_B64: begin
                        // S_QUADMASK_B64
                        // TODO
                    end
                    SOP1_MOVRELS_B32: begin
                        // S_MOVRELS_B32
                        // TODO
                    end
                    SOP1_MOVRELS_B64: begin
                        // S_MOVRELS_B64
                        // TODO
                    end
                    SOP1_MOVRELD_B32: begin
                        // S_MOVRELD_B32
                        // TODO
                    end
                    SOP1_MOVRELD_B64: begin
                        // S_MOVRELD_B64
                        // TODO
                    end
                    SOP1_ABS_I32: begin
                        // S_ABS_I32
                        // TODO
                    end
                    SOP1_ANDN1_SAVEEXEC_B64: begin
                        // S_ANDN1_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_ORN1_SAVEEXEC_B64: begin
                        // S_ORN1_SAVEEXEC_B64
                        // TODO
                    end
                    SOP1_ANDN1_WREXEC_B64: begin
                        // S_ANDN1_WREXEC_B64
                        // TODO
                    end
                    SOP1_ANDN2_WREXEC_B64: begin
                        // S_ANDN2_WREXEC_B64
                        // TODO
                    end
                    SOP1_BITREPLICATE_B64_B32: begin
                        // S_BITREPLICATE_B64_B32
                        // TODO
                    end
                    SOP1_AND_SAVEEXEC_B32: begin
                        // S_AND_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_OR_SAVEEXEC_B32: begin
                        // S_OR_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_XOR_SAVEEXEC_B32: begin
                        // S_XOR_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_ANDN2_SAVEEXEC_B32: begin
                        // S_ANDN2_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_ORN2_SAVEEXEC_B32: begin
                        // S_ORN2_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_NAND_SAVEEXEC_B32: begin
                        // S_NAND_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_NOR_SAVEEXEC_B32: begin
                        // S_NOR_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_XNOR_SAVEEXEC_B32: begin
                        // S_XNOR_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_ANDN1_SAVEEXEC_B32: begin
                        // S_ANDN1_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_ORN1_SAVEEXEC_B32: begin
                        // S_ORN1_SAVEEXEC_B32
                        // TODO
                    end
                    SOP1_ANDN1_WREXEC_B32: begin
                        // S_ANDN1_WREXEC_B32
                        // TODO
                    end
                    SOP1_ANDN2_WREXEC_B32: begin
                        // S_ANDN2_WREXEC_B32
                        // TODO
                    end
                    SOP1_MOVRELSD_2_B32: begin
                        // S_MOVRELSD_2_B32 
                        // TODO
                    end
                    default:;
                endcase
            end
            SOPK: begin
                case(scalar_inst_in.op)
                    SOPK_MOVK_I32: begin
                        // S_MOVK_I32
                        dest_value = sign_extend_16_to_32(scalar_inst_in.imm16[15:0]);
                    end
                    SOPK_VERSION: begin
                        // S_VERSION
                        // Do Nothing, argument ignored by hardware.
                        // Not equivalent to S_NOP, hardware may issue next instruction in same cycle
                    end
                    SOPK_CMOVK_I32: begin
                        // S_CMOVK_I32
                        if(scc_in) begin
                            dest_value = sign_extend_16_to_32(scalar_inst_in.imm16[15:0]);
                        end
                    end
                    SOPK_CMPK_EQ_I32: begin
                        // S_CMPK_EQ_I32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 == sign_extend_16_to_32(scalar_inst_in.imm16[15:0]))
                    end
                    SOPK_CMPK_LG_I32: begin
                        // S_CMPK_LG_I32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 != sign_extend_16_to_32(scalar_inst_in.imm16[15:0]))
                    end
                    SOPK_CMPK_GT_I32: begin
                        // S_CMPK_GT_I32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 > sign_extend_16_to_32(scalar_inst_in.imm16[15:0]))
                    end
                    SOPK_CMPK_GE_I32: begin
                        // S_CMPK_GE_I32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 >= sign_extend_16_to_32(scalar_inst_in.imm16[15:0]))
                    end
                    SOPK_CMPK_LT_I32: begin
                        // S_CMPK_LT_I32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 < sign_extend_16_to_32(scalar_inst_in.imm16[15:0]))
                    end
                    SOPK_CMPK_LE_I32: begin
                        // S_CMPK_LE_I32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 <= sign_extend_16_to_32(scalar_inst_in.imm16[15:0]))
                    end
                    SOPK_CMPK_EQ_U32: begin
                        // S_CMPK_EQ_U32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 == scalar_inst_in.imm16[15:0])
                    end
                    SOPK_CMPK_LG_U32: begin
                        // S_CMPK_LG_U32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 != scalar_inst_in.imm16[15:0])
                    end
                    SOPK_CMPK_GT_U32: begin
                        // S_CMPK_GT_U32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 > scalar_inst_in.imm16[15:0])
                    end
                    SOPK_CMPK_GE_U32: begin
                        // S_CMPK_GE_U32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 >= scalar_inst_in.imm16[15:0])
                    end
                    SOPK_CMPK_LT_U32: begin
                        // S_CMPK_LT_U32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 < scalar_inst_in.imm16[15:0])
                    end
                    SOPK_CMPK_LE_U32: begin
                        // S_CMPK_LE_U32
                        // TODO: figure our what they mean by src0
                        // scc = (src0 <= scalar_inst_in.imm16[15:0])
                    end
                    SOPK_ADDK_I32: begin
                        // S_ADDK_I32
                        // Add a 16-bit signed constant to the destination.
                        // TODO
                        // int32 tmp = dest_value; // save value so we can check sign bits for overflow later.
                        // dest_value = dest_value + sign_extend_16_to_32(scalar_inst_in.imm16[15:0]);
                        // scc = (tmp[31] == scalar_inst_in.imm16[15] && tmp[31] != dest_value[31]) // signed overflow.
                    end
                    SOPK_MULK_I32: begin
                        // S_MULK_I32
                        // TODO
                        // D.i32 = D.i32 * sign_extend_16_to_32(scalar_inst_in.imm16[15:0])
                    end
                    SOPK_GETREG_B32: begin
                        // S_GETREG_B32
                        // Read some or all of a hardware register into the LSBs of D.
                        // scalar_inst_in.imm16 = {size[4:0], offset[4:0], hwRegId[5:0]}; offset is 0..31, size is 1..32.
                        // TODO
                        // uint32 offset = scalar_inst_in.imm16[10:6];
                        // uint32 size = scalar_inst_in.imm16[15:11];
                        // uint32 id = scalar_inst_in.imm16[5:0];
                        // D.u32 = hardware_reg[id][offset+size-1:offset]
                    end
                    SOPK_SETREG_B32: begin
                        // S_SETREG_B32
                        // Write some or all of the LSBs of S0 into a hardware register.
                        // scalar_inst_in.imm16 = {size[4:0], offset[4:0], hwRegId[5:0]}; offset is 0..31, size is 1..32.
                        // TODO
                        // hardware-reg = src0.
                    end
                    SOPK_SETREG_IMM32_B32: begin
                        // S_SETREG_IMM32_B32
                        // Write some or all of the LSBs of IMM32 into a hardware register;
                        // this instruction requires a 32-bit literal constant.
                        // scalar_inst_in.imm16 = {size[4:0], offset[4:0], hwRegId[5:0]}; offset is 0..31, size is 1..32.
                        // TODO
                        // hardware-reg = LITERAL
                    end
                    SOPK_CALL_B64: begin
                        // TODO
                        // S_CALL_B64
                        // Implements a short call, where the return address (the next instruction after the S_CALL_B64) is saved to D. 
                        // Long calls should consider S_SWAPPC_B64 instead
                        // D.u64 = PC + 4;
                        // PC = PC + sign_extend_16_to_32(scalar_inst_in.imm16 * 4) + 4
                    end
                    SOPK_WAITCNT_VSCNT: begin
                        // TODO
                        // S_WAITCNT_VSCNT
                        // Wait for the counts of outstanding vector store events -- vector memory stores and atomics that DO NOT return data -- to be at or below the specified level. 
                        // This counter is not used in 'all-in-order' mode.
                        // vscnt <= src0[5:0] + src1[5:0]
                    end
                    SOPK_WAITCNT_VMCNT: begin
                        // TODO
                        // S_WAITCNT_VMCNT
                        // Wait for the counts of outstanding vector memory events --everything except for memory stores and atomics-without-return-- to be at or below the specified level. 
                        // When in 'all-in-order' mode, wait for all vector memory events
                        // vmcnt <= src0[5:0] + src1[5:0]
                    end
                    SOPK_WAITCNT_EXPCNT: begin
                        // TODO
                        // S_WAITCNT_EXPCNT
                        // Waits for the following condition to hold before continuing:
                        // expcnt <= src0[2:0] + src1[2:0]
                    end
                    SOPK_WAITCNT_LGKMCNT: begin
                        // TODO
                        // S_WAITCNT_LGKMCNT
                        // Waits for the following condition to hold before continuing:
                        // lgkmcnt <= src0[5:0] + src1[5:0]
                    end
                    SOPK_SUBVECTOR_LOOP_BEGIN: begin
                        // TODO
                        // S_SUBVECTOR_LOOP_BEGIN
                    end
                    SOPK_SUBVECTOR_LOOP_END: begin
                        // TODO
                        // S_SUBVECTOR_LOOP_END
                    end
                    default:;
                endcase
            end
            SOPP: begin
                case(scalar_inst_in.op)
                    SOPP_NOP: begin
                        // S_NOP
                    end
                    SOPP_ENDPGM: begin
                        // S_ENDPGM
                        active = 1'b0;
                        active_we = 1'b1; 
                    end
                    SOPP_BRANCH: begin
                        // S_BRANCH
                        pc = pc_in + $signed(sign_extend_16_to_48(scalar_inst_in.imm16) << 2) + 4;
                        pc_we = 1'b1;
                    end
                    SOPP_WAKEUP: begin
                        // S_WAKEUP
                        // TODO
                    end
                    SOPP_CBRANCH_SCC0: begin
                        // S_CBRANCH_SCC0
                        pc = pc_in + $signed(sign_extend_16_to_48(scalar_inst_in.imm16) << 2) + 4;
                        pc_we = (scc_in == 1'b0);
                    end
                    SOPP_CBRANCH_SCC1: begin
                        // S_CBRANCH_SCC1
                        pc = pc_in + $signed(sign_extend_16_to_48(scalar_inst_in.imm16) << 2) + 4;
                        pc_we = (scc_in == 1'b1);
                    end
                    SOPP_CBRANCH_VCCZ: begin
                        // S_CBRANCH_VCCZ
                        pc = pc_in + $signed(sign_extend_16_to_48(scalar_inst_in.imm16) << 2) + 4;
                        pc_we = (vccz_in == 1'b0);
                    end
                    SOPP_CBRANCH_VCCNZ: begin
                        pc = pc_in + $signed(sign_extend_16_to_48(scalar_inst_in.imm16) << 2) + 4;
                        pc_we = (vccz_in != 1'b0); 
                    end
                    SOPP_CBRANCH_EXECZ: begin
                        // S_CBRANCH_EXECZ
                        pc = pc_in + $signed(sign_extend_16_to_48(scalar_inst_in.imm16) << 2) + 4;
                        pc_we = (execz_in == 1'b0); 
                    end
                    SOPP_CBRANCH_EXECNZ: begin
                        // S_CBRANCH_EXECNZ
                        pc = pc_in + $signed(sign_extend_16_to_48(scalar_inst_in.imm16) << 2) + 4;
                        pc_we = (execz_in != 1'b0); 
                    end
                    SOPP_BARRIER: begin
                        // S_BARRIER
                        barrier = 1'b1;
                        barrier_we = 1'b1;
                    end
                    SOPP_SETKILL: begin
                        // S_SETKILL
                        // TODO
                    end
                    SOPP_WAITCNT: begin
                        // S_WAITCNT
                        // TODO
                    end
                    SOPP_SETHALT: begin
                        // S_SETHALT
                        // TODO
                    end
                    SOPP_SLEEP: begin
                        // S_SLEEP
                        // TODO
                    end
                    SOPP_SETPRIO: begin
                        // S_SETPRIO
                        // TODO
                    end
                    SOPP_SENDMSG: begin
                        // S_SENDMSG
                        // TODO
                    end
                    SOPP_SENDMSGHALT: begin
                        // S_SENDMSGHALT
                        // TODO
                    end
                    SOPP_TRAP: begin
                        // S_TRAP
                        // TODO
                    end
                    SOPP_ICACHE_INV: begin
                        // S_ICACHE_INV
                        // TODO
                    end
                    SOPP_INCPERFLEVEL: begin
                        // S_INCPERFLEVEL
                        // TODO
                    end
                    SOPP_DECPERFLEVEL: begin
                        // S_DECPERFLEVEL
                        // TODO
                    end
                    SOPP_TTRACEDATA: begin
                        // S_TTRACEDATA
                        // TODO
                    end
                    SOPP_CBRANCH_CDBGSYS: begin
                        // S_CBRANCH_CDBGSYS
                        // TODO
                    end
                    SOPP_CBRANCH_CDBGUSER: begin
                        // S_CBRANCH_CDBGUSER
                        // TODO
                    end
                    SOPP_CBRANCH_CDBGSYS_OR_USER: begin
                        // S_CBRANCH_CDBGSYS_OR_USER
                        // TODO
                    end
                    SOPP_CBRANCH_CDBGSYS_AND_USER: begin
                        // S_CBRANCH_CDBGSYS_AND_USER
                        // TODO
                    end
                    SOPP_ENDPGM_SAVED: begin
                        // S_ENDPGM_SAVED
                        // TODO
                    end
                    SOPP_ENDPGM_ORDERED_PS_DONE: begin
                        // S_ENDPGM_ORDERED_PS_DONE
                        // TODO
                    end
                    SOPP_CODE_END: begin
                        // S_CODE_END
                        // TODO
                    end
                    SOPP_INST_PREFETCH: begin
                        // S_INST_PREFETCH
                        // TODO
                    end
                    SOPP_CLAUSE: begin
                        // S_CLAUSE
                        // TODO
                    end
                    SOPP_WAITCNT_DEPCTR: begin
                        // S_WAITCNT_DEPCTR
                        // TODO
                    end
                    SOPP_ROUND_MODE: begin
                        // S_ROUND_MODE
                        // TODO
                    end
                    SOPP_DENORM_MODE: begin
                        // S_DENORM_MODE
                        // TODO
                    end
                    SOPP_TTRACEDATA_IMM: begin
                        // S_TTRACEDATA_IMM
                        // TODO
                    end
                    default:;
                endcase
            end
            SOPC: begin
                case(scalar_inst_in.op)
                    SOPC_CMP_EQ_I32: begin
                        // S_CMP_EQ_I32
                        // Identitcal to S_CMP_EQ_U32, both are provided for symmetry
                        scc = (src0 == src1);
                        scc_we = 1;
                    end
                    SOPC_CMP_LG_I32: begin
                        // S_CMP_LG_I32
                        // Identitcal to S_CMP_LG_U32, both are provided for symmetry
                        scc = (src0 != src1);
                        scc_we = 1;
                    end
                    SOPC_CMP_GT_I32: begin
                        // S_CMP_GT_I32
                        scc = ($signed(src0) > $signed(src1));
                        scc_we = 1;
                    end
                    SOPC_CMP_GE_I32: begin
                        // S_CMP_GE_I32
                        scc = ($signed(src0) >= $signed(src1));
                        scc_we = 1;
                    end
                    SOPC_CMP_LT_I32: begin
                        // S_CMP_LT_I32
                        scc = ($signed(src0) < $signed(src1));
                        scc_we = 1;
                    end
                    SOPC_CMP_LE_I32: begin
                        // S_CMP_LE_I32
                        scc = ($signed(src0) <= $signed(src1));
                        scc_we = 1;
                    end
                    SOPC_CMP_EQ_U32: begin
                        // S_CMP_EQ_U32
                        // Identitcal to S_CMP_EQ_I32, both are provided for symmetry
                        scc = (src0 == src1);
                        scc_we = 1;
                    end
                    SOPC_CMP_LG_U32: begin
                        // S_CMP_LG_U32
                        // Identitcal to S_CMP_LG_I32, both are provided for symmetry
                        scc = (src0 != src1);
                        scc_we = 1;
                    end
                    SOPC_CMP_GT_U32: begin
                        // S_CMP_GT_U32
                        scc = (src0 > src1);
                        scc_we = 1;
                    end
                    SOPC_CMP_GE_U32: begin
                        // S_CMP_GE_U32
                        scc = (src0 >= src1);
                        scc_we = 1;
                    end
                    SOPC_CMP_LT_U32: begin
                        // S_CMP_LT_U32
                        scc = (src0 < src1);
                        scc_we = 1;
                    end
                    SOPC_CMP_LE_U32: begin
                        // S_CMP_LE_U32
                        scc = (src0 <= src1);
                        scc_we = 1;
                    end
                    SOPC_BITCMP0_B32: begin
                        // S_BITCMP0_B32
                        scc = (src0[src1[4:0]] == 0);
                        scc_we = 1;
                    end
                    SOPC_BITCMP1_B32: begin
                        // S_BITCMP1_B32
                        scc = (src0[src1[4:0]] == 1);
                        scc_we = 1;
                    end
                    SOPC_BITCMP0_B64: begin
                        // S_BITCMP0_B64
                        // TODO Implement support for 64 bit operations
                        // scc = (S0.u64[src1[5:0]] == 0);
                    end
                    SOPC_BITCMP1_B64: begin
                        // S_BITCMP1_B64
                        // TODO Implement support for 64 bit operations
                        // scc = (S0.u64[src1[5:0]] == 1);
                    end
                    SOPC_CMP_EQ_U64: begin
                        // S_CMP_EQ_U64
                        // TODO Implement support for 64 bit operations
                        // scc = (S0.i64 == S1.i64);
                    end
                    SOPC_CMP_LG_U64: begin
                        // S_CMP_LG_U64
                        // TODO Implement support for 64 bit operations
                        // scc = (S0.i64 != S1.i64);
                    end
                    default:;
                endcase
            end
            default:;
        endcase
    end

endmodule

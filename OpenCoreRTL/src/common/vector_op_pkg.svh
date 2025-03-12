package vector_op_pkg;

    // Offsets
    localparam VOP2_AS_VOP3_OFFSET  = 10'h100;
    localparam VOP1_AS_VOP3_OFFSET  = 10'h180;
    localparam VOPC_AS_VOP3A_OFFSET = 10'h000;

    // VOP2 Opcodes
    localparam V_MUL_F32            = 10'd8;
    localparam V_MUL_I32_I24        = 10'd9;
    localparam V_MUL_U32_U24        = 10'd11;
    localparam V_LSHLREV_B32        = 10'd26;
    localparam V_XOR_B32            = 10'd29;
    localparam V_ADD_NC_U32         = 10'd37;
    localparam V_SUB_NC_U32         = 10'd38;
    localparam V_SUBREV_NC_U32      = 10'd39;
    localparam V_ADD_CO_CI_U32      = 10'd40;
    localparam V_FMAC_F32           = 10'd43;
    localparam V_FMAMK_F32          = 10'd44;

    // VOP1 Opcodes
    localparam V_MOV_B32            = 10'd1;

    // VOPC Opcodes
    localparam V_CMP_LT_I32         = 10'd129;
    localparam V_CMP_GT_I32         = 10'd132;
    localparam V_CMP_EQ_U32         = 10'd194;
    localparam V_CMP_GT_U32         = 10'd196;

    // VINTRP Opcodes

    // VOP3 Opcodes
    // ---- VOP3A ----
    localparam V_ASHRREV_I32        = 10'd24;
    localparam V_MAX3_I32           = 10'd341;
    localparam V_MUL_LO_U32         = 10'd361;
    localparam V_LSHLREV_B64        = 10'd767;
    localparam V_LSHL_ADD_U32       = 10'd838;
    localparam V_ADD3_U32           = 10'd877;
    localparam V_LSHL_OR_B32        = 10'd879;
    // ---- VOP3B ----
    localparam V_MAD_U64_U32        = 10'd374;
    localparam V_ADD_CO_U32         = 10'd783;
    // ---- VOP2 as VOP3 ----
    localparam VOP3_V_MUL_F32       = VOP2_AS_VOP3_OFFSET + V_MUL_F32;
    localparam VOP3_V_MUL_I32_I24   = VOP2_AS_VOP3_OFFSET + V_MUL_I32_I24;
    localparam VOP3_V_MUL_U32_U24   = VOP2_AS_VOP3_OFFSET + V_MUL_U32_U24;
    localparam VOP3_V_LSHLREV_B32   = VOP2_AS_VOP3_OFFSET + V_LSHLREV_B32;
    localparam VOP3_V_XOR_B32       = VOP2_AS_VOP3_OFFSET + V_XOR_B32;
    localparam VOP3_V_ADD_NC_U32    = VOP2_AS_VOP3_OFFSET + V_ADD_NC_U32;
    localparam VOP3_V_SUB_NC_U32    = VOP2_AS_VOP3_OFFSET + V_SUB_NC_U32;
    localparam VOP3_V_SUBREV_NC_U32 = VOP2_AS_VOP3_OFFSET + V_SUBREV_NC_U32;
    localparam VOP3_V_ADD_CO_CI_U32 = VOP2_AS_VOP3_OFFSET + V_ADD_CO_CI_U32;
    localparam VOP3_V_FMAC_F32      = VOP2_AS_VOP3_OFFSET + V_FMAC_F32;
    localparam VOP3_V_FMAMK_F32     = VOP2_AS_VOP3_OFFSET + V_FMAMK_F32;
    // ---- VOP1 as VOP3 ----
    localparam VOP3_V_MOV_B32       = VOP1_AS_VOP3_OFFSET + V_MOV_B32;
    // ---- VOPC as VOP3A ----
    localparam VOP3_V_CMP_LT_I32    = VOPC_AS_VOP3A_OFFSET + V_CMP_LT_I32;
    localparam VOP3_V_CMP_GT_I32    = VOPC_AS_VOP3A_OFFSET + V_CMP_GT_I32;
    localparam VOP3_V_CMP_EQ_U32    = VOPC_AS_VOP3A_OFFSET + V_CMP_EQ_U32;
    localparam VOP3_V_CMP_GT_U32    = VOPC_AS_VOP3A_OFFSET + V_CMP_GT_U32;

endpackage

`timescale 1ps/1ps

package ex_pkg;
    
    /* verilator lint_off IMPORTSTAR */
    import common_pkg::*;
    import mem_pkg::*;
    /* verilator lint_on IMPORTSTAR */


    localparam ALL_FLAG_WIDTH = 8;

    localparam VECTOR_FLAG  = 8'b1000_0000;
    localparam SCALAR_FLAG  = 8'b0100_0000;
    localparam FLAT_FLAG    = 8'b0010_0000;
    localparam DS_FLAG      = 8'b0001_0000;
    localparam EXPORT_FLAG  = 8'b0000_1000;
    localparam MIMG_FLAG    = 8'b0000_0100;
    localparam MBUF_FLAG    = 8'b0000_0010;
    localparam SMEM_FLAG    = 8'b0000_0001;

    // For EX1
    function logic [31:0] scalar_src_decode (logic [7:0] src, logic [31:0] reg_rdata, logic [31:0] literal, logic vccz, logic scc, logic execz);
        if ((src == NULL_ADDR) || src == ZERO) begin // 125, 128
            scalar_src_decode = '0;
        end else if (src < SGPR_DEPTH) begin // Use value from SGPR module
            scalar_src_decode = reg_rdata;
        end else if (src <= INT64) begin // 129 - 192
            scalar_src_decode = int'(src) - 128;
        end else if (src <= NEG_INT16) begin // 193 - 208
            scalar_src_decode = (int'(src) - 192) * -1; 
        end else if (src <= 234) begin // 209 - 234 (Reserved)
            scalar_src_decode = 'x; // FIXME Might need to throw an error here?
        end else if (src <= PRIVATE_LIMIT) begin // 235 - 238
            scalar_src_decode = 'x;
            // FIXME: Add Memory Aperature SRCs
        end else if (src == POPS_EXITING_WAVE_ID) begin // 239
            scalar_src_decode = 'x; 
            // FIXME: Add POPS_EXISTING_WAVE_ID = Primitive Ordered Pixel Shading wave ID
        end else if (src == FLOAT_0_5) begin // 240
            scalar_src_decode = `FP32_0_5;
        end else if (src == FLOAT_NEG_0_5) begin // 241
            scalar_src_decode = `FP32_NEG_0_5;
        end else if (src == FLOAT_1_0) begin // 242
            scalar_src_decode = `FP32_1_0;
        end else if (src == FLOAT_NEG_1_0) begin // 243
            scalar_src_decode = `FP32_NEG_1_0;
        end else if (src == FLOAT_2_0) begin // 244
            scalar_src_decode = `FP32_2_0;
        end else if (src == FLOAT_NEG_2_0) begin // 245
            scalar_src_decode = `FP32_NEG_2_0;
        end else if (src == FLOAT_4_0) begin // 246
            scalar_src_decode = `FP32_4_0;
        end else if (src == FLOAT_NEG_4_0) begin //247
            scalar_src_decode = `FP32_NEG_4_0;
        end else if (src == INV_TWO_PI) begin // 248
            scalar_src_decode = `FP32_INV_2_PI;
        end else if (src == VCCZ) begin // 251
            scalar_src_decode = {31'b0, vccz};
        end else if (src == EXECZ) begin // 252
            scalar_src_decode = {31'b0, execz};
        end else if (src == SCC) begin // 253
            scalar_src_decode = {31'b0, scc};
        end else if (src == LITERAL_CONSTANT) begin // 255
            scalar_src_decode = literal;
        end else begin
            // Reserved 249, 250, 254
            scalar_src_decode = 'x;
        end
    endfunction

    function logic [31:0] vector_src_decode (logic [8:0] src, logic [31:0] ssrc_data, logic [31:0] vsrc_data, logic [31:0] literal, logic vccz, logic scc, logic execz);
        if (src[8] == 1'b1) begin
            vector_src_decode = vsrc_data;
        end else begin
            vector_src_decode = scalar_src_decode(.src(src[7:0]), .reg_rdata(ssrc_data), .literal(literal), .vccz(vccz), .scc(scc), .execz(execz));
        end
    endfunction



endpackage

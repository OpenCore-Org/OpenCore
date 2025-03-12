/*

    Scalar General Purpose Register File

    16 banks, each bank has:
        128 Registers:
            0 - 105 - SGPR
            106 - VCC LO
            107 - VCC HI
            108 - 123 TTMP
            124 - M0
            125 - NULL
            126 - EXEC LO
            127 - EXEC HI

    Reads and Writes are 64bits - Here how to read/write to these registers

    For Reads: 
    64bit reads MUST be 64bit aligned. I.e. read to reg 4 & 5 or 10 & 11 are allowed. 11 and 12 is not.
    32bit reads are allowed to any address.

    If an ODD address is selected, it is assumed to be a 32 bit READ, RADDR will appear in radata_lo, rdata_hi will be zeroed out
    If an EVEN address is selected, it is assumed to be a 64 bit READ, RADDR will appear in rdata_lo, and RADDR+1 will appear in rdata_hi

    For Writes:
    64bit writes MUST be 64bit aligned. I.e. write to reg 4 & 5 or 10 & 11 are allowed. 11 and 12 is not.
    32bit writes are allowed to any address - ensure LSB of STRB is set.

    If an ODD address is selected for write, only the ODD address will be written. Regardless if wstrb is enabled for both.

    Module supports bypass
*/


module reg_sgpr
import common_pkg::*;
import mem_pkg::*;
#(
    parameter RD_PORTS = SGPR_RD_PORTS, // Number of Read Ports - 2
    parameter DATA_WIDTH = SGPR_DATA_WIDTH, // Width of each register - 32
    parameter DEPTH = SGPR_DEPTH, // Number of Registers - 128
    parameter BANKS = MAX_WAVEFRONT_CNT, // Number of Wavefronts
    parameter WAVE32_ONLY = 1
) (
    input clk,
    input reset,

    input  logic [$clog2(BANKS)-1:0]               rd_bank_sel,
    input  logic [RD_PORTS-1:0][$clog2(DEPTH)-1:0] raddr,
    output logic [RD_PORTS-1:0][DATA_WIDTH-1:0]    rdata_hi,
    output logic [RD_PORTS-1:0][DATA_WIDTH-1:0]    rdata_lo,

    input logic [$clog2(BANKS)-1:0]          wr_bank_sel,
    input logic [$clog2(DEPTH)-1:0]                waddr,
    input logic [DATA_WIDTH*2-1:0]                 wdata,
    input logic [1:0]                              wstrb,
    input logic                                  wenable,

    input                                    wave64_mode, // If enabled, work in wave64 mode. Ignore if WAVE32_ONLY == 1
    output logic [BANKS-1:0][DATA_WIDTH-1:0]        exec,                       
    output logic [BANKS-1:0]                       execz,
    output logic [BANKS-1:0]                        vccz,
    output logic [BANKS-1:0][DATA_WIDTH-1:0]         vcc,     
    input  logic                                  vcc_en,
    input  logic [$clog2(BANKS)-1:0]        vcc_bank_sel, // VCC_LO only
    input  logic [DATA_WIDTH-1:0]               vcc_data
);

logic [BANKS-1:0][DEPTH/2-1:0][DATA_WIDTH*2-1:0] r_reg_mem; // Effectively 16 Banks of 64 x 64 registers.

logic wr32bit;
logic wr64bit_lo, wr64bit_hi;

assign wr32bit = waddr[0] && wenable && wstrb[0];
assign wr64bit_lo = !waddr[0] && wenable && wstrb[0];
assign wr64bit_hi = !waddr[0] && wenable && wstrb[1];

// Register Writes
always_ff @(posedge clk) begin
    if (reset) begin
        /* verilator lint_off WIDTHCONCAT */
        r_reg_mem <= '0;
        for (int ii = 0; ii < BANKS; ii++) begin // Sets EXEC to all 1s
            r_reg_mem[ii][EXEC_LO[$clog2(DEPTH)-1:1]] <= '1;
        end
        /* verilator lint_on WIDTHCONCAT */
    end else begin
        if (wenable) begin
            if (waddr[0]) begin // Force 32bit write
                r_reg_mem[wr_bank_sel][waddr[$clog2(DEPTH)-1:1]][63:32] <= wdata[31:0] & {32{wstrb[0]}};
            end else begin // 64bit write
                r_reg_mem[wr_bank_sel][waddr[$clog2(DEPTH)-1:1]] <= wdata & {{32{wstrb[1]}}, {32{wstrb[0]}}};
            end
        end

        if (vcc_en) begin
            r_reg_mem[vcc_bank_sel][VCC_LO[$clog2(DEPTH)-1:1]][31:0] <= vcc_data;
        end

    end
end

// Register Reads (we do NOT bypass VCC or EXEC)
always_comb begin
    for (int ii = 0; ii < RD_PORTS; ii++) begin
        if (raddr[ii][0]) begin // Force 32bit read
            rdata_hi[ii] = '0;
            rdata_lo[ii] = r_reg_mem[rd_bank_sel][raddr[ii][$clog2(DEPTH)-1:1]][63:32];

            if ((raddr[ii][$clog2(DEPTH)-1:1] == waddr[$clog2(DEPTH)-1:1]) && (rd_bank_sel == wr_bank_sel)) begin // Potentially Reading/Writing from same Reg
                if (wr32bit) begin // 32bit write
                    rdata_lo[ii] = wdata[31:0];
                end else if (wr64bit_hi) begin // 64bit write
                    rdata_lo[ii] = wdata[63:32];
                end
            end
            // If NULL, return 0
            if (raddr[ii] == NULL_ADDR[$clog2(DEPTH)-1:0]) begin
                rdata_lo[ii] = '0;
            end
        end else begin // 64bit read
            {rdata_hi[ii], rdata_lo[ii]} = r_reg_mem[rd_bank_sel][raddr[ii][$clog2(DEPTH)-1:1]];

            if ((raddr[ii][$clog2(DEPTH)-1:1] == waddr[$clog2(DEPTH)-1:1]) && (rd_bank_sel == wr_bank_sel)) begin // Potentially Reading/Writing from same Reg
                if (wr32bit) begin // 32bit write (imples address match too)
                    rdata_hi[ii] = wdata[31:0];
                end else begin // 64bit write
                    if (wr64bit_hi) begin
                        rdata_hi[ii] = wdata[63:32];
                    end
                    if (wr64bit_lo) begin
                        rdata_lo[ii] = wdata[31:0];
                    end
                end
            end
            // If NULL, return 0
            if (raddr[ii] == (NULL_ADDR[$clog2(DEPTH)-1:0]-1)) begin
                rdata_hi[ii] = '0;
            end
        end
    end
end

generate
    for (genvar bk = 0; bk < BANKS; bk++) begin : g_CONNECT_VCCZ_EXECZ_LOOP
        if (WAVE32_ONLY) begin : g_CONNECT_VCCZ_EXECZ_WAVE32
            assign vccz[bk] = ~(|r_reg_mem[bk][VCC_LO[$clog2(DEPTH)-1:1]][31:0]); // A single bit-flag indicating that the VCC mask is all zeros.
            assign execz[bk] = ~(|r_reg_mem[bk][EXEC_LO[$clog2(DEPTH)-1:1]][31:0]); // A single bit flag indicating that the EXEC mask is all zeros.
        end else begin : g_CONNECT_VCCZ_EXECZ
            assign vccz[bk] = (wave64_mode) ? ~(|r_reg_mem[bk][VCC_LO[$clog2(DEPTH)-1:1]]) : ~(|r_reg_mem[bk][VCC_LO[$clog2(DEPTH)-1:1]][31:0]);
            assign execz[bk] = (wave64_mode) ? ~(|r_reg_mem[bk][EXEC_LO[$clog2(DEPTH)-1:1]]) : ~(|r_reg_mem[bk][EXEC_LO[$clog2(DEPTH)-1:1]][31:0]);
        end
    end
endgenerate

always_comb begin
    for (int bk = 0; bk < BANKS; bk++) begin
        exec[bk] = r_reg_mem[bk][EXEC_LO[$clog2(DEPTH)-1:1]][DATA_WIDTH-1:0]; 
        vcc[bk]  = r_reg_mem[bk][VCC_LO[$clog2(DEPTH)-1:1]][DATA_WIDTH-1:0]; 
    end
end
endmodule

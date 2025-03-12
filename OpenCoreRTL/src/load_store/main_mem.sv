/*
####################################################
 
Copyright (c) 2025 Joey Chen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

####################################################
*/
/*
    Main Memory RAM
*/

module main_mem #(
    parameter BANKS = 1,
    localparam THREADS = 32,
    parameter DATA_WIDTH = 64
)(
    input clk,
    input reset,

    // SIMD32 #1
    input  logic [THREADS-1:0]                     ram_en,
    input  logic [THREADS-1:0][1 : 0]              ram_wstrb,
    input  logic              [0 : 0]              ram_we,
    input  logic [THREADS-1:0][31 : 0]             ram_addr,
    input  logic [THREADS-1:0][DATA_WIDTH-1 : 0]   ram_wdata,
    output logic [THREADS-1:0][DATA_WIDTH-1 : 0]   ram_rdata,
    output logic                                   ram_done // Indicate entire request fulfilled


);

    typedef enum logic {
        IDLE,
        COMPLETE
    } thread_state_e;

    typedef enum logic {
        READY,
        BUSY
    } bank_state_e;

    // For SIMD32 #1
    logic [BANKS-1:0]                     ena;
    logic [BANKS-1:0][7 : 0]              wea;
    logic [BANKS-1:0][32-1 : 0]           addra;
    logic [BANKS-1:0][DATA_WIDTH-1 : 0]   dina;
    logic [BANKS-1:0][DATA_WIDTH-1 : 0]   douta;
    bank_state_e [BANKS-1:0]              next_a_bank, r_a_bank;

    logic [THREADS-1:0][DATA_WIDTH-1 : 0]   next_ram_rdata;
    thread_state_e [THREADS-1:0]            next_a_thread, r_a_thread;
    logic                                   next_a_done;
    logic [BANKS-1:0][$clog2(THREADS)-1:0]  a_grant;
    logic [BANKS-1:0][$clog2(THREADS)-1:0]  next_a_dest, r_a_dest;
    logic [BANKS-1:0]                       a_grant_valid;

    always_comb begin
        next_a_thread = r_a_thread;
        next_a_bank   = r_a_bank;

        next_a_dest = '0;

        next_ram_rdata = ram_rdata;

        ena = '0;
        wea = '0;
        addra = '0;
        dina = '0;

        // Port A
        for (int ii = 0; ii < BANKS; ii++) begin // Per bank
            if (r_a_bank[ii] == READY) begin
                ena[ii]   = a_grant_valid[ii];
                wea[ii]   = {8{ram_we}} & {{4{ram_wstrb[a_grant[ii]][1]}}, {4{ram_wstrb[a_grant[ii]][0]}}};
                addra[ii] = ram_addr[a_grant[ii]];
                dina[ii]  = ram_wdata[a_grant[ii]];
                next_a_dest[ii] = a_grant[ii];
                
                if (a_grant_valid[ii]) begin
                    next_a_thread[a_grant[ii]] = COMPLETE;
                    if (~|ram_we) begin
                        next_a_bank[ii] = BUSY;
                    end
                end

            end else begin // r_a_bank[ii] == BUSY
                ena[ii]   = a_grant_valid[ii];
                wea[ii]   = {8{ram_we}} & {{4{ram_wstrb[a_grant[ii]][1]}}, {4{ram_wstrb[a_grant[ii]][0]}}};
                addra[ii] = ram_addr[a_grant[ii]];
                dina[ii]  = ram_wdata[a_grant[ii]];
                next_a_dest[ii] = a_grant[ii];
                
                next_ram_rdata[r_a_dest[ii]] = douta[ii];

                if (a_grant_valid[ii]) begin
                    next_a_thread[a_grant[ii]] = COMPLETE;
                    // We assume its always a read/write
                end else begin
                    next_a_bank[ii] = READY;
                end
            end
        end

        next_a_done = |ram_en && ~ram_done;
        for (int th = 0; th < THREADS; th++) begin
            if ((r_a_thread[th] != COMPLETE) && (ram_en[th] != 1'b0)) begin
                next_a_done = '0;
            end
        end

        if (ram_done) begin
            for (int th = 0; th < THREADS; th++) begin
                next_a_thread[th] = IDLE;
            end
        end

    end

    always_ff @(posedge clk) begin
        if (reset) begin
            r_a_thread <= {32{IDLE}};
            r_a_bank <= READY;
            r_a_dest <= '0;
            ram_done <= '0;
            ram_rdata <= '0;

        end else begin
            ram_done <= next_a_done;
            r_a_thread <= next_a_thread;
            r_a_bank <= next_a_bank;
            ram_rdata <= next_ram_rdata;
            r_a_dest <= next_a_dest;
        end
    end

    logic [THREADS-1:0] threads_waiting;

    always_comb begin
        for (int th = 0; th < THREADS; th++) begin
            threads_waiting[th] = (r_a_thread[th] == IDLE);
        end
    end

    for (genvar bk = 0; bk < BANKS; bk++) begin : gen_prio_encoder
        prio_encoder #(.WIDTH(THREADS)) u_p_encoder (
            .req(ram_en & threads_waiting),
            .grant(a_grant[bk]),
            .valid(a_grant_valid[bk])
        );
    end


    for (genvar bk = 0; bk < BANKS; bk++) begin : gen_mem_bank

        `ifdef SYNTHESIS
        ram ram (
            .clka(clk),    // input wire clka
            .ena(ena[bk]),      // input wire ena
            .wea(wea[bk]),      // input wire [7 : 0] wea
            .addra(addra[bk]),  // input wire [31 : 0] addra
            .dina(dina[bk]),    // input wire [63 : 0] dina
            .douta(douta[bk])  // output wire [63 : 0] douta
        );
        `else
            /* verilator lint_off PINCONNECTEMPTY */
            dual_port_RAM #(
                .N(9),
                .D(512),
                .W(64)
            ) ram_inst (
                .CLK(clk),
                .CS(!(ena[bk] != 0)),
                .WR_RD_A(|wea[bk]),
                .WR_RD_B('0),
                .ADDR_A(addra[bk][8:0]),
                .ADDR_B('0),
                .WDATA_A(dina[bk]),
                .WDATA_B('0),
                .RDATA_A(douta[bk]),
                .RDATA_B()
            );
            /* verilator lint_on PINCONNECTEMPTY */
        `endif
    end
    
endmodule

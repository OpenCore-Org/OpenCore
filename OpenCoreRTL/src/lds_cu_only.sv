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
    From RDNA 2.0 ISA
        Physically located on-chip, directly adjacent to the ALUs, the LDS is approximately one order of
        magnitude faster than global memory (assuming no bank conflicts).
        There are 128kB memory per workgroup processor split up into 64 banks of dword-wide RAMs.
        These 64 banks are further sub-divided into two sets of 32-banks each where 32 of the banks
        are affiliated with a pair of SIMD32’s, and the other 32 banks are affiliated with the other pair of
        SIMD32’s within the WGP. Each bank is a 512x32 two-port RAM (1R/1W per clock cycle).
        Dwords are placed in the banks serially, but all banks can execute a store or load
        simultaneously. One work-group can request up to 64kB memory.

        The high bandwidth of the LDS memory is achieved not only through its proximity to the ALUs,
        but also through simultaneous access to its memory banks. Thus, it is possible to concurrently
        execute 32 write or read instructions, each nominally 32-bits; extended instructions,
        read2/write2, can be 64-bits each. If, however, more than one access attempt is made to the
        same bank at the same time, a bank conflict occurs. In this case, for indexed and atomic
        operations, the hardware is designed to prevent the attempted concurrent accesses to the same
        bank by turning them into serial accesses. This decreases the effective bandwidth of the LDS.
        For increased throughput (optimal efficiency), therefore, it is important to avoid bank conflicts. A
        knowledge of request scheduling and address mapping is key to achieving this.


        Depending on the need for performance, more/less banks can be selected. Although the ISA specifies a 
        use of 32-banks. This may not need to be true for smaller designs. 
*/

module lds_cu_only #(
    parameter BANKS = 16,
    parameter THREADS = 32
)(
    input clk,
    input reset,

    // SIMD32 #1
    input  logic [THREADS-1:0]           simd32_1_en,
    input  logic              [0 : 0]    simd32_1_we,
    input  logic [THREADS-1:0][13 : 0]   simd32_1_addr,
    input  logic [THREADS-1:0][31 : 0]   simd32_1_wdata,
    output logic [THREADS-1:0][31 : 0]   simd32_1_rdata,
    output logic                         simd32_1_done, // Indicate entire request fulfilled

    // SIMD32 #2
    input  logic [THREADS-1:0]           simd32_2_en,
    input  logic              [0 : 0]    simd32_2_we,
    input  logic [THREADS-1:0][13 : 0]   simd32_2_addr,
    input  logic [THREADS-1:0][31 : 0]   simd32_2_wdata,
    output logic [THREADS-1:0][31 : 0]   simd32_2_rdata,
    output logic                         simd32_2_done // Indicate entire request fulfilled

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
    logic [BANKS-1:0]           ena;
    logic [BANKS-1:0][0 : 0]    wea;
    logic [BANKS-1:0][9 : 0]    addra;
    logic [BANKS-1:0][31 : 0]   dina;
    logic [BANKS-1:0][31 : 0]   douta;
    bank_state_e [BANKS-1:0]    next_a_bank, r_a_bank;

    logic [THREADS-1:0][31 : 0]     next_simd32_1_rdata;
    thread_state_e [THREADS-1:0]    next_a_thread, r_a_thread;
    logic                           next_a_done;
    logic [BANKS-1:0][$clog2(THREADS)-1:0]  a_grant;
    logic [BANKS-1:0][$clog2(THREADS)-1:0]  next_a_dest, r_a_dest;
    logic [BANKS-1:0]               a_grant_valid;


    // For SIMD32 #2
    logic [BANKS-1:0]           enb;
    logic [BANKS-1:0][0 : 0]    web;
    logic [BANKS-1:0][9 : 0]    addrb;
    logic [BANKS-1:0][31 : 0]   dinb;
    logic [BANKS-1:0][31 : 0]   doutb;
    bank_state_e [BANKS-1:0]    next_b_bank, r_b_bank;

    logic [THREADS-1:0][31 : 0]     next_simd32_2_rdata;
    thread_state_e [THREADS-1:0]    next_b_thread, r_b_thread;
    logic                           next_b_done;
    logic [BANKS-1:0][$clog2(THREADS)-1:0]  b_grant;
    logic [BANKS-1:0][$clog2(THREADS)-1:0]  next_b_dest, r_b_dest;
    logic [BANKS-1:0]               b_grant_valid;

    always_comb begin
        next_a_thread = r_a_thread;
        next_b_thread = r_b_thread;
        next_a_bank   = r_a_bank;
        next_b_bank   = r_b_bank;

        next_a_dest = '0;
        next_b_dest = '0;

        next_simd32_1_rdata = simd32_1_rdata;
        next_simd32_2_rdata = simd32_2_rdata;

        ena = '0;
        wea = '0;
        addra = '0;
        dina = '0;

        enb = '0;
        web = '0;
        addrb = '0;
        dinb = '0;

        // Port A
        for (int ii = 0; ii < BANKS; ii++) begin // Per bank
            if (r_a_bank[ii] == READY) begin
                ena[ii]   = a_grant_valid[ii];
                wea[ii]   = simd32_1_we;
                addra[ii] = simd32_1_addr[a_grant[ii]][13:4];
                dina[ii]  = simd32_1_wdata[a_grant[ii]];
                next_a_dest[ii] = a_grant[ii];
                
                if (a_grant_valid[ii]) begin
                    next_a_thread[a_grant[ii]] = COMPLETE;
                    if (~simd32_1_we) begin
                        next_a_bank[ii] = BUSY;
                    end
                end

            end else begin // r_a_bank[ii] == BUSY
                ena[ii]   = a_grant_valid[ii];
                wea[ii]   = simd32_1_we;
                addra[ii] = simd32_1_addr[a_grant[ii]][13:4];
                dina[ii]  = simd32_1_wdata[a_grant[ii]];
                next_a_dest[ii] = a_grant[ii];
                
                next_simd32_1_rdata[r_a_dest[ii]] = douta[ii];

                if (a_grant_valid[ii]) begin
                    next_a_thread[a_grant[ii]] = COMPLETE;
                    // We assume its always a read/write
                end else begin
                    next_a_bank[ii] = READY;
                end
            end
        end

        next_a_done = |simd32_1_en && ~simd32_1_done;
        for (int th = 0; th < THREADS; th++) begin
            if ((r_a_thread[th] != COMPLETE) && (simd32_1_en[th] != 1'b0)) begin
                next_a_done = '0;
            end
        end

        if (simd32_1_done) begin
            for (int th = 0; th < THREADS; th++) begin
                next_a_thread[th] = IDLE;
            end
        end

        // Port B
        for (int ii = 0; ii < BANKS; ii++) begin // Per bank
            if (r_b_bank[ii] == READY) begin
                ena[ii]   = b_grant_valid[ii];
                wea[ii]   = simd32_2_we;
                addra[ii] = simd32_2_addr[b_grant[ii]][13:4];
                dina[ii]  = simd32_2_wdata[b_grant[ii]];
                next_b_dest[ii] = b_grant[ii];
                
                if (b_grant_valid[ii]) begin
                    next_b_thread[b_grant[ii]] = COMPLETE;
                    if (~simd32_2_we) begin
                        next_b_bank[ii] = BUSY;
                    end
                end

            end else begin // r_b_bank[ii] == BUSY
                ena[ii]   = b_grant_valid[ii];
                wea[ii]   = simd32_2_we;
                addra[ii] = simd32_2_addr[b_grant[ii]][13:4];
                dina[ii]  = simd32_2_wdata[b_grant[ii]];
                next_b_dest[ii] = b_grant[ii];
                
                next_simd32_2_rdata[r_b_dest[ii]] = doutb[ii];

                if (b_grant_valid[ii]) begin
                    next_b_thread[b_grant[ii]] = COMPLETE;
                    // We assume its always a read/write
                end else begin
                    next_b_bank[ii] = READY;
                end
            end
        end

        next_b_done = |simd32_2_en && ~simd32_2_done;
        for (int th = 0; th < THREADS; th++) begin
            if ((r_b_thread[th] != COMPLETE) && (simd32_2_en[th] != 1'b0)) begin
                next_b_done = '0;
            end
        end

        if (simd32_2_done) begin
            for (int th = 0; th < THREADS; th++) begin
                next_b_thread[th] = IDLE;
            end
        end

    end

    always_ff @(posedge clk) begin
        if (reset) begin
            r_a_thread <= {THREADS{IDLE}};
            r_b_thread <= {THREADS{IDLE}};
            r_a_bank <= {BANKS{READY}};
            r_b_bank <= {BANKS{READY}};
            r_a_dest <= '0;
            r_b_dest <= '0;
            simd32_1_done <= '0;
            simd32_2_done <= '0;
            simd32_1_rdata <= '0;
            simd32_2_rdata <= '0;
        end else begin
            simd32_1_done <= next_a_done;
            simd32_2_done <= next_b_done;
            r_a_thread <= next_a_thread;
            r_b_thread <= next_b_thread;
            r_a_bank <= next_a_bank;
            r_b_bank <= next_b_bank;
            simd32_1_rdata <= next_simd32_1_rdata;
            simd32_2_rdata <= next_simd32_2_rdata;

            r_a_dest <= next_a_dest;
            r_b_dest <= next_b_dest;
        end
    end

    logic [THREADS-1:0] threads_waiting_a, threads_waiting_b;
    logic [BANKS-1:0][THREADS-1:0] bank_match_a, bank_match_b;

    always_comb begin
        for (int th = 0; th < THREADS; th++) begin
            threads_waiting_a[th] = (r_a_thread[th] == IDLE);
            threads_waiting_b[th] = (r_b_thread[th] == IDLE);
        end

        for (int bk = 0; bk < BANKS; bk++) begin
            for (int th = 0; th < THREADS; th++) begin
                bank_match_a[bk][th] = (bk[4:0] == simd32_1_addr[th][4:0]);
                bank_match_b[bk][th] = (bk[4:0] == simd32_2_addr[th][4:0]);
            end
        end
    end

    for (genvar bk = 0; bk < BANKS; bk++) begin : gen_prio_encoder
        prio_encoder #(.WIDTH(THREADS)) u_p_encoder_a (
            .req(simd32_1_en & threads_waiting_a & bank_match_a[bk]),
            .grant(a_grant[bk]),
            .valid(a_grant_valid[bk])
        );

        prio_encoder #(.WIDTH(THREADS)) u_p_encoder_b (
            .req(simd32_1_en & threads_waiting_a & bank_match_b[bk]),
            .grant(b_grant[bk]),
            .valid(b_grant_valid[bk])
        );
    end


    for (genvar bk = 0; bk < BANKS; bk++) begin : gen_lds_banks
        `ifdef SYNTHESIS
         lds_bank u_lds_bank (
             .clka   (clk),          // input wire clka
             .ena    (ena[bk]),      // input wire ena
             .wea    (wea[bk]),      // input wire [0 : 0] wea
             .addra  (addra[bk]),    // input wire [9 : 0] addra
             .dina   (dina[bk]),     // input wire [31 : 0] dina
             .douta  (douta[bk]),    // output wire [31 : 0] douta
             .clkb   (clk),          // input wire clkb
             .enb    (enb[bk]),      // input wire enb
             .web    (web[bk]),      // input wire [0 : 0] web
             .addrb  (addrb[bk]),    // input wire [9 : 0] addrb
             .dinb   (dinb[bk]),     // input wire [31 : 0] dinb
             .doutb  (doutb[bk])     // output wire [31 : 0] doutb
         );
        `else
            dual_port_RAM #(
                .N(10),
                .D(1024),
                .W(32)
            ) ram_inst (
                .CLK(clk),
                .CS(!(ena[bk] || enb[bk])),
                .WR_RD_A(wea[bk]),
                .WR_RD_B(web[bk]),
                .ADDR_A(addra[bk]),
                .ADDR_B(addrb[bk]),
                .WDATA_A(dina[bk]),
                .WDATA_B(dinb[bk]),
                .RDATA_A(douta[bk]),
                .RDATA_B(doutb[bk])
            );
        `endif
    end
    
endmodule

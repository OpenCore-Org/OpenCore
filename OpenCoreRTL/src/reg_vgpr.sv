module reg_vgpr
import common_pkg::*;
import mem_pkg::*;
#(
    parameter RD_PORTS = 4, // Number of Read Ports - 4
    parameter DATA_WIDTH = 32, // Width of each register - 32
    parameter DEPTH = 256, // Number of Registers - 256
    localparam THREADS = RD_PORTS // Number of write / read ports

) (
    input clk,
    input reset,

    input  logic [RD_PORTS-1:0][$clog2(DEPTH)-1:0]  raddr,
    input  logic [RD_PORTS-1:0]                     renable,
    output logic [RD_PORTS-1:0][DATA_WIDTH-1:0]     rdata_hi,
    output logic [RD_PORTS-1:0][DATA_WIDTH-1:0]     rdata_lo,

    input logic [$clog2(DEPTH)-1:0]                 waddr,
    input logic [DATA_WIDTH*2-1:0]                  wdata,
    input logic [1:0]                               wstrb,
    input logic                                     wenable,

    output logic                                    vgpr_done
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
    logic  ena;
    logic  [7 : 0] wea;
    logic  [6 : 0] addra;
    logic  [63 : 0] dina;
    logic  enb;
    logic  [6 : 0] addrb;
    logic  [63 : 0] doutb;

    bank_state_e  next_b_bank, r_b_bank;

    logic [THREADS-1:0][DATA_WIDTH*2-1 : 0] next_ram_rdata, ram_rdata;
    thread_state_e [THREADS-1:0]            next_b_thread, r_b_thread;
    logic                                   next_b_done;
    logic [$clog2(THREADS)-1:0]  b_grant;
    logic [$clog2(THREADS)-1:0]  next_b_dest, r_b_dest;
    logic                        b_grant_valid;

    always_comb begin
        for (int th = 0; th < RD_PORTS; th++) begin
            rdata_hi[th] = ram_rdata[th][63:32];
            rdata_lo[th] = (raddr[th][0]) ? ram_rdata[th][63:32] : ram_rdata[th][31:0];
        end
    end

    // ENA
    always_comb begin
        ena = wenable;
        addra = waddr[7:1];

        if (waddr[0]) begin // Force 32bit write
            dina   = {wdata[31:0], 32'b0};
            wea    = {{4{wstrb[0]}}, 4'b0};
        end else begin // 64bit write
            dina   = wdata;
            wea    = {{4{wstrb[1]}}, {4{wstrb[0]}}};
        end
    end

    // ENB
    always_comb begin
        next_b_thread = r_b_thread;
        next_b_bank   = r_b_bank;

        next_b_dest = '0;
        next_ram_rdata = ram_rdata;


        // Port B
        if (r_b_bank == READY) begin
            enb   = b_grant_valid;
            addrb = raddr[b_grant][$clog2(DEPTH)-1:1];
            next_b_dest = b_grant;
            
            if (b_grant_valid) begin
                next_b_thread[b_grant] = COMPLETE;
                next_b_bank = BUSY;
            end

        end else begin // r_b_bank == BUSY
            enb   = b_grant_valid;
            addrb = raddr[b_grant][$clog2(DEPTH)-1:1];
            next_b_dest = b_grant;
            
            next_ram_rdata[r_b_dest] = doutb;

            if (b_grant_valid) begin
                next_b_thread[b_grant] = COMPLETE;
            end else begin
                next_b_bank = READY;
            end
        end


        next_b_done = |renable && ~vgpr_done;
        for (int th = 0; th < THREADS; th++) begin
            if ((r_b_thread[th] != COMPLETE) && (renable[th] != 1'b0)) begin
                next_b_done = '0;
            end
        end

        if (vgpr_done) begin
            for (int th = 0; th < THREADS; th++) begin
                next_b_thread[th] = IDLE;
            end
        end

    end

    always_ff @(posedge clk) begin
        if (reset) begin
            r_b_thread <= {IDLE, IDLE, IDLE, IDLE};
            r_b_bank <= READY;
            r_b_dest <= '0;
            vgpr_done <= '0;
            ram_rdata <= '0;

        end else begin
            vgpr_done <= next_b_done;
            r_b_thread <= next_b_thread;
            r_b_bank <= next_b_bank;
            ram_rdata <= next_ram_rdata;
            r_b_dest <= next_b_dest;
        end
    end

    logic [THREADS-1:0] threads_waiting;

    always_comb begin
        for (int th = 0; th < THREADS; th++) begin
            threads_waiting[th] = (r_b_thread[th] == IDLE);
        end
    end

    prio_encoder #(.WIDTH(THREADS)) u_p_encoder (
        .req(renable & threads_waiting),
        .grant(b_grant),
        .valid(b_grant_valid)
    );

    `ifdef SYNTHESIS
        vgpr u_vgpr (
        .clka(clk),    // input wire clka
        .ena(ena),      // input wire ena
        .wea(wea),      // input wire [7 : 0] wea
        .addra(addra),  // input wire [6 : 0] addra
        .dina(dina),    // input wire [63 : 0] dina
        .clkb(clk),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [6 : 0] addrb
        .doutb(doutb)  // output wire [63 : 0] doutb
        );
    `else
        /* verilator lint_off PINCONNECTEMPTY */
        dual_port_RAM #(
            .N(7),
            .D(128),
            .W(64)
        ) ram_inst (
            .CLK(clk),
            .CS(!(ena || enb)),
          .WR_RD_A((|wea) && ena),
            .WR_RD_B('0),
            .ADDR_A(addra),
            .ADDR_B(addrb),
            .WDATA_A(dina),
            .WDATA_B('0),
            .RDATA_A(),
            .RDATA_B(doutb)
        );
        /* verilator lint_on PINCONNECTEMPTY */
    `endif


endmodule

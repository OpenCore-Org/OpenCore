`timescale 1ns/1ns

module tb_main_mem;
    parameter int BANKS = 32;
    logic clk;
    logic reset;

    // SIMD32 #1 Signals
    logic [BANKS-1:0]           simd32_1_en;
    logic            [7 : 0]    simd32_1_we;
    logic [BANKS-1:0][31 : 0]   simd32_1_addr;
    logic [BANKS-1:0][63 : 0]   simd32_1_wdata;
    logic [BANKS-1:0][63 : 0]   simd32_1_rdata;
    logic                       simd32_1_done;

    // Clock generation (50% duty cycle)
    always #5 clk = ~clk;

    // Instantiate the DUT (Device Under Test)
    main_mem #(
        .BANKS(1)
    ) dut (
        .clk(clk),
        .reset(reset),

        // SIMD32 #1
        .ram_en(simd32_1_en),
        .ram_we(simd32_1_we),
        .ram_wstrb('1),
        .ram_addr(simd32_1_addr),
        .ram_wdata(simd32_1_wdata),
        .ram_rdata(simd32_1_rdata),
      	.ram_done(simd32_1_done)
    );

    // Initial block: VCD dump, reset, and test case
    initial begin
        //   $dumpfile("ram.vcd");  // VCD waveform dump
        //   $dumpvars(0, tb_lds_cu_only);

        // Initialize signals
        clk = 0;
        reset = 1;
        simd32_1_en = 0;
        simd32_1_we = 0;
        simd32_1_addr = 0;
        simd32_1_wdata = 0;

        // Apply reset
        #20 reset = 0;
        #10;

        // Test Case: Write to SIMD32 #1, Bank 0
      for (int ii = 0; ii < 32; ii++) begin
        simd32_1_en[ii] = 1;
        simd32_1_we = '1;
        simd32_1_addr[ii] = ii*8;
        simd32_1_wdata[ii] = ii;
      end

        // Maintain input until done signal is asserted
//        #1000;
//        $finish;
        wait (simd32_1_done);
      @(negedge clk);
        
        // Deassert signals after completion
        simd32_1_en[0] = 0;
        simd32_1_we = 0;
        #10;

        // Test Case: Read from SIMD32 #1, Bank 0
      for (int ii = 0; ii < 32; ii++) begin
        simd32_1_en[ii] = 1;
        simd32_1_we = 0;
        simd32_1_addr[ii] = ii*8;
        simd32_1_wdata[ii] = 32'hDEADBEEF;
      end

        // Maintain input until done signal is asserted
        wait (simd32_1_done);
        
        // Capture read data
        $display("Read Data from SIMD32_1 Bank 0: %h", simd32_1_rdata[0]);

        // Deassert signals after completion
        simd32_1_en[0] = 0;
        #10;

        // Finish simulation
        #50;
        $finish;
    end
endmodule

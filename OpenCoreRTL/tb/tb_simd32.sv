`timescale 1ns/1ns

module tb_simd32;
    // import common_pkg::*;

    logic clk = 0;
    logic rst;
    logic decoder_stall;
    logic [31:0] inst_mem [100];
    logic [31:0] inst;
    int file;
    int num_lines;

    task load_file();
        file = $fopen("C:\\Vivado Projects\\OpenCore\\OpenCoreRTL\\tb\\benchmarks\\simple_bench.txt","r");
        if (file)   $display("File was opened successfully : %0d", file);
        else        $display("File was NOT opened successfully : %0d", file);

        while ($fscanf(file, "%h\n", inst_mem[num_lines]) == 1) begin
            $display("i=%d, Read Line: %h", num_lines, inst_mem[num_lines]);
            num_lines++;
        end
        $fclose(file);
    endtask

    task run_cycle();
        #20;
    endtask

    task apply_reset();
        rst = 1;
        run_cycle();
        run_cycle();
        rst = 0;
    endtask

    always #10 clk = ~clk;

    simd32_top simd32 (
        .clk(clk),
        .reset(rst),
        .inst(inst),
        .wavefront_num(0),
        .decoder_stall(decoder_stall)
    );

    int i;
    initial begin
        i = 0;
        inst = 0;
        decoder_stall = 0;
        num_lines = 0;

        load_file();
        apply_reset();

        while (i != num_lines) begin
            if (!decoder_stall) begin
                inst = inst_mem[i];
                i++;
            end
            $display ("T=%0t, inst=%h", $realtime, inst);
            run_cycle();
        end
        $finish();
    end

endmodule

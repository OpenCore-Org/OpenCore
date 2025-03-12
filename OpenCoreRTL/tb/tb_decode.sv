`timescale 1ps/1ps

/*
    Decoder Testbench

    Tests all the instructions for decoder
*/

module tb_decode;
import common_pkg::*;


logic clk;
logic reset;

logic [63:0] r_raw_inst;
logic [31:0] inst;

logic decoder_stall;

logic ready;
logic valid;

logic vector_flag;
vector_inst_t vector_inst_out;
logic scalar_flag;
scalar_inst_t scalar_inst_out;
logic flat_flag;
flat_inst_t flat_inst_out;
logic ds_flag;
ds_inst_t ds_inst_out;
logic export_flag;
export_inst_t export_inst_out;
logic mimg_flag;
mimg_inst_t mimg_inst_out;
logic mbuf_flag;
mbuf_inst_t mbuf_inst_out;
logic smem_flag;
smem_inst_t smem_inst_out;

decode dut
(
    .reset (reset),
    .clk (clk),
    .inst(inst),
    .decoder_stall(decoder_stall),
    .vector_flag(vector_flag),
    .vector_inst_out(vector_inst_out),
    .scalar_flag(scalar_flag),
    .scalar_inst_out(scalar_inst_out),
    .flat_flag(flat_flag),
    .flat_inst_out(flat_inst_out),
    .ds_flag(ds_flag),
    .ds_inst_out(ds_inst_out),
    .export_flag(export_flag),
    .export_inst_out(export_inst_out),
    .mimg_flag(mimg_flag),
    .mimg_inst_out(mimg_inst_out),
    .mbuf_flag(mbuf_flag),
    .mbuf_inst_out(mbuf_inst_out),
    .smem_flag(smem_flag),
    .smem_inst_out(smem_inst_out),
    .valid(valid),
    .ready(ready)
);

localparam CLK_PERIOD = 10;
always #(CLK_PERIOD/2) clk=~clk;

initial begin
    #1 reset<=1'bx;clk<=1'bx;
    #(CLK_PERIOD*3) reset<=1;
    #(CLK_PERIOD*3) reset<=0;clk<=0;
    repeat(5) @(posedge clk);
    reset<=1;
    ready<=1;
    @(posedge clk);
    repeat(2) @(posedge clk);

    @(negedge clk);
    inst = '0;

    repeat(100);
    $finish(2);
end



always_ff @(posedge clk) begin 
    if (reset) begin
        r_raw_inst <= 0;
    end 
end

endmodule
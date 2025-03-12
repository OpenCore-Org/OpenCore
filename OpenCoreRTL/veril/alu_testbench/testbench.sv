

module testbench #(
    parameter WIDTH = 32
)
(
    input logic clk,
    input logic rst,

    input logic [WIDTH-1:0] a_add,
    input logic [WIDTH-1:0] b_add,
    input logic add,
    input logic cin_add,
    output logic [WIDTH-1:0] out_add,
    output logic cout_add,

    input logic in_valid_mul,
    input logic signed [WIDTH:0] a_mul,
    input logic signed [WIDTH:0] b_mul,
    output logic signed [WIDTH:0] out_mul,
    output logic out_mul_valid
);

    u_add_sub add_sub1 (
        .clk(clk),
        .rst(rst),
        .a(a_add),
        .b(b_add),
        .add(add),
        .cin(cin_add),
        .out(out_add),
        .cout(cout_add)
    );

    s_multiplier mul (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid_mul),
        .a(a_mul),
        .b(b_mul),
        .out(out_mul),
        .out_valid(out_mul_valid)
    );

endmodule

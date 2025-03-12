/*
    Unsigned Adder/Subtractor
    - Output width would be one larger than input to support cout
*/

module u_add_sub
#(
    parameter WIDTH = 32
) (
    input logic clk,
    input logic rst,

    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b,
    input logic add,
    input logic cin,
    output logic [WIDTH:0] out
);
`ifdef SYNTHESIS
    add_sub add_sub1 (
        .A(a),          // input wire [31 : 0] A
        .B(b),          // input wire [31 : 0] B
        .CLK(clk),      // input wire CLK
        .ADD(add),      // input wire ADD
        .C_IN(cin),     // input wire C_IN
        .SCLR(rst),     // input wire SCLR
        .S(out)         // output wire [32 : 0] S
    );
`else
    always_ff @(posedge clk) begin
        if (rst) begin
            out <= '0;
        end else begin
            if (add) begin
                out <= {1'b0, a} + {1'b0, b} + {{(WIDTH-1){1'b0}}, cin};
            end else begin
                out <= {1'b0, a} - {1'b0, b};
            end
        end
    end
`endif
endmodule

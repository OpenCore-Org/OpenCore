module logic_unit
import arithmetic_pkg::*;
#(
    parameter WIDTH = 64
) (
    input logic rst,
    input logic clk,

    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b,
    input logic [WIDTH-1:0] c,
    input logic_op_t op,
    output logic [WIDTH-1:0] comb_out,
    output logic [WIDTH-1:0] out
);

always_comb begin
    unique case(op)
        LSHFTL: begin
            comb_out = a << b;
        end
        LSHFTR: begin
            comb_out = a >> b;
        end
        ASHFTR: begin
            comb_out = signed' (a) >>> signed' (b);
        end
        AND: begin
            comb_out = a & b;
        end
        XOR: begin
            comb_out = a ^ b;
        end
        OR: begin
            comb_out = a | b;
        end
        S_LT: begin
            comb_out = {{(WIDTH-1){1'b0}}, (signed' (a) < signed' (b))};
        end
        S_GT: begin
            comb_out = {{(WIDTH-1){1'b0}}, (signed' (a) > signed' (b))};
        end
        U_LT: begin
            comb_out = {{(WIDTH-1){1'b0}}, (a < b)};
        end
        U_GT: begin
            comb_out = {{(WIDTH-1){1'b0}}, (a > b)};
        end
        EQ: begin
            comb_out = {{(WIDTH-1){1'b0}}, (a == b)};
        end
        MAX3: begin
            if (signed' (a) >= signed' (b) && signed' (a) >= signed' (c)) begin
                comb_out = a;
            end else if (signed' (b) >= signed' (a) && signed' (b) >= signed' (c)) begin
                comb_out = b;
            end else begin
                comb_out = c;
            end
        end
        default: comb_out = '0;
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        out <= '0;
    end else begin
        out <= comb_out;
    end
end

endmodule

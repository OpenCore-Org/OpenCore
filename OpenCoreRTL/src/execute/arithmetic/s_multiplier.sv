/*
    Signed Multiplier
    - Non-pipelined
*/

module s_multiplier
#(
    // These parameters are only applicable to the Verilog and not
    // the multiplier IP block
    parameter WIDTH = 33,
    localparam CYCLES = 1
) (
    input logic clk,
    input logic rst,

    input logic in_valid,
    input logic signed [WIDTH-1:0] a,
    input logic signed [WIDTH-1:0] b,
    output logic signed [2*WIDTH-1:0] out,

    // Output Ready/Valid Interface
    output logic out_valid,
    input logic out_ready
);
    logic [CYCLES-1:0] valid_delay;
    logic actually_valid;
    logic run_multiplier;

    assign out_valid = valid_delay[CYCLES-1];
    assign actually_valid = in_valid && ~(|valid_delay);
    assign run_multiplier = !valid_delay[CYCLES-1] || out_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_delay <= '0;
        end else begin
            valid_delay[0] <= actually_valid;

            // Shift valid
            for (int i = 1; i < CYCLES; i++) begin
                if (run_multiplier) begin
                    valid_delay[i] <= valid_delay[i-1];
                end
            end
        end
    end

`ifdef SYNTHESIS
    signed_multiplier multiplier (
        .CLK(clk),  // input wire CLK
        .A(a),      // input wire [32 : 0] A
        .B(b),      // input wire [32 : 0] B
        .CE(run_multiplier),    // input wire CE
        .P(out)     // output wire [65 : 0] P
    );
`else
    logic signed [CYCLES-1:0][WIDTH*2-1:0] data_delay;
    
    assign out = data_delay[CYCLES-1];
    
    // assign run_multiplier = !valid_delay[CYCLES-1] || out_ready;
    // assign actually_valid = in_valid && ~(|valid_delay)

    always_ff @(posedge clk) begin
        if (rst) begin
            data_delay <= '0;
        end else begin
            if (actually_valid) begin
                data_delay[0] <= a * b;
            end else begin
                data_delay[0] <= '0;
            end

            // Shift data and valid
            for (int i = 1; i < CYCLES; i++) begin
                if (run_multiplier) begin
                    data_delay[i] <= data_delay[i-1];
                end
            end
        end
    end
`endif
endmodule

/*
    FP32 Fused Multiply Add

    Does A*B+C
*/

module fp32_mac
# (
    localparam CYCLES = 2,
    localparam WIDTH = 32
) (
    input logic clk,
    input logic rst,

    input logic in_valid,
    output logic in_ready,
    input logic [31:0] a_data,
    input logic [31:0] b_data,
    input logic [31:0] c_data,

    output logic result_valid,
    input logic result_ready,
    output logic [31:0] result_data
);
`ifdef SYNTHESIS
    logic [CYCLES-1:0] valid_delay;
    logic actually_valid;
    logic run_multiplier;
    logic a_ready;
    logic b_ready;
    logic c_ready;

    assign in_ready = a_ready & b_ready & c_ready;
    assign run_multiplier = !valid_delay[CYCLES-1] || result_ready;
    assign actually_valid = in_valid && ~(|valid_delay) && in_ready;

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

    floating_point_mac fp32 (
        .aclk(clk),                           // input wire aclk
        .aresetn(rst),                        // input wire aresetn
        .s_axis_a_tvalid(actually_valid),     // input wire s_axis_a_tvalid
        .s_axis_a_tready(a_ready),            // output wire s_axis_a_tready
        .s_axis_a_tdata(a_data),              // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(actually_valid),     // input wire s_axis_b_tvalid
        .s_axis_b_tready(b_ready),            // output wire s_axis_b_tready
        .s_axis_b_tdata(b_data),              // input wire [31 : 0] s_axis_b_tdata
        .s_axis_c_tvalid(actually_valid),     // input wire s_axis_c_tvalid
        .s_axis_c_tready(c_ready),            // output wire s_axis_c_tready
        .s_axis_c_tdata(c_data),              // input wire [31 : 0] s_axis_c_tdata
        .m_axis_result_tvalid(result_valid),  // output wire m_axis_result_tvalid
        .m_axis_result_tready(result_ready),  // input wire m_axis_result_tready
        .m_axis_result_tdata(result_data),    // output wire [31 : 0] m_axis_result_tdata
        /* verilator lint_off PINCONNECTEMPTY */
        .m_axis_result_tuser()                // output wire [2 : 0] m_axis_result_tuser = Outputs overflow, underflow, and NaN
        /* verilator lint_on PINCONNECTEMPTY */

    );
`else
    logic signed [CYCLES-1:0][WIDTH-1:0] data_delay;
    logic [CYCLES-1:0] valid_delay;
    logic actually_valid;
    logic run_multiplier;

    assign result_data = data_delay[CYCLES-1];
    assign result_valid = valid_delay[CYCLES-1];
    assign run_multiplier = !valid_delay[CYCLES-1] || result_ready;
    assign actually_valid = in_valid && ~(|valid_delay)

    always_ff @(posedge clk) begin
        if (rst) begin
            data_delay <= '0;
            valid_delay <= '0;
        end else begin
            if (actually_valid) begin
                data_delay[0] <= a_data * b_data + c_data;
            end else begin
                data_delay[0] <= '0;
            end
            valid_delay[0] <= actually_valid;

            // Shift data and valid
            for (int i = 1; i < CYCLES; i++) begin
                if (run_multiplier) begin
                    data_delay[i] <= data_delay[i-1];
                    valid_delay[i] <= valid_delay[i-1];
                end
            end
        end
    end
`endif
endmodule

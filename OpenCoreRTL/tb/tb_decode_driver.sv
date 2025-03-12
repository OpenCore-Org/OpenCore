module tb_decode_driver #(
    parameter WIDTH = 64 // Must be multiple of 32
) (
    input clk,
    input reset,

    // TB Instructions
    input  valid,
    output ready,

    // DUT Instructions
    input  inst_in[WIDTH-1:0],
    output inst_out[31:0],

    output inst_valid,
    input  inst_ready
);
    localparam BUSY_CNT = (WIDTH <= 63) ? 0 : ((WIDTH/32) - 1); // Number of cycle, 

    localparam IDLE = 1'b0;
    localparam BUSY = 1'b1;

    logic r_curr_state;
    logic next_state; 

    logic [$clog(BUSY_CNT+1)-1:0] r_int_busy_counter;

    always_ff @(posdege clk) begin
    end

    always_comb begin
        ready = 1'b0;
        next_state = r_curr_state;
        inst_valid = 1'b0;

        unique case (r_curr_state)
            IDLE: begin
                if (valid && inst_ready) begin
                    ready = 1'b1;
                    inst_valid = 1'b1;
                    if (BUSY_CNT > 0) begin
                        next_state = BUSY;
                    end 
                end
            end 
            BUSY: begin
                inst_valid = 1'b1
                if (r_int_busy_counter == 1) begin
                    next_state = IDLE;
                end
            end

        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            r_curr_state <= IDLE;
        end else begin
            if (!inst_ready) begin
                r_curr_state <= next_state;
            end
        end
    end


    
endmodule
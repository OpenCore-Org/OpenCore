module reg_status  (
    input logic clk,
    input logic reset,

    // Register Reads
    output logic scc,
    output logic [47:0] pc,
    output logic active,
    output logic barrier,
    output logic clause,

    // Register Writes
    input logic scc_data,
    input logic scc_we,
    input logic [47:0] pc_data,
    input logic pc_we,
    input logic active_data,
    input logic active_we,
    input logic barrier_data,
    input logic barrier_we,
    input logic clause_data,
    input logic clause_we
);

    logic r_scc;
    logic [47:0] r_pc /* verilator public */;
    logic r_active;
    logic r_barrier;
    logic r_clause;

    // SCC
    assign scc = (scc_we) ? scc_data : r_scc;

    always_ff @(posedge clk) begin
        if (reset) begin
            r_scc <= '0;
        end else begin
            if (scc_we) begin
                r_scc <= scc_data;
            end
        end
    end

    // PC
    assign pc = (pc_we) ? pc_data : r_pc;

    always_ff @(posedge clk) begin
        if (reset) begin
            r_pc <= '0;
        end else begin
            if (pc_we) begin
                r_pc <= pc_data;
            end else begin
                r_pc <= r_pc + 4;
            end
        end
    end

    
    // wavefront waiting on barrier 
    assign barrier = (barrier_we) ? barrier_data : r_barrier;

    always_ff @(posedge clk) begin
        if (reset) begin
            r_barrier <= '0;
        end else begin
            if (barrier_we) begin
                r_barrier <= barrier_data;
            end
        end
    end


    // wavefront active 
    assign active = (active_we) ? active_data : r_active;

    always_ff @(posedge clk) begin
        if (reset) begin
            r_active <= '0;
        end else begin
            if (active_we) begin
                r_active <= active_data;
            end
        end
    end
    
    // clause active 
    assign clause = (clause_we) ? clause_data : r_clause;

    always_ff @(posedge clk) begin
        if (reset) begin
            r_clause <= '0;
        end else begin
            if (clause_we) begin
                r_clause <= clause_data;
            end
        end
    end
endmodule

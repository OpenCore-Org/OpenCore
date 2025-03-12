module prio_encoder #(
    parameter WIDTH = 32
) (
    input logic [WIDTH-1:0] req,
    output logic [$clog2(WIDTH)-1:0] grant,
    output logic valid
);

    assign valid = |req; // Ensure that we have a valid signal

    always_comb begin
        grant = '0;
        for (int ii = 0; ii < WIDTH; ii++) begin
            if (req[ii]) begin
                grant = ii[$clog2(WIDTH)-1:0];
            end
        end
    end
    
endmodule

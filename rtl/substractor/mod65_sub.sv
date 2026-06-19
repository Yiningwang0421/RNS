module mod65_sub (
    input  logic [6:0] a,
    input  logic [6:0] b,
    output logic [6:0] y
);

    logic [7:0] diff_nowrap;
    logic [7:0] diff_wrap;

    always_comb begin
        // Candidate 0: no wrap
        diff_nowrap = {1'b0, a} - {1'b0, b};

        // Candidate 1: wrap around by adding modulus
        diff_wrap   = {1'b0, a} + 8'd65 - {1'b0, b};

        if (a >= b)
            y = diff_nowrap[6:0];
        else
            y = diff_wrap[6:0];
    end

endmodule

module mod63_sub (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);

    logic [6:0] diff_nowrap;
    logic [6:0] diff_wrap;

    always_comb begin
        // Candidate 0: no wrap
        diff_nowrap = {1'b0, a} - {1'b0, b};

        // Candidate 1: wrap around by adding modulus
        diff_wrap   = {1'b0, a} + 7'd63 - {1'b0, b};

        // Select correct candidate
        if (a >= b)
            y = diff_nowrap[5:0];
        else
            y = diff_wrap[5:0];
    end

endmodule

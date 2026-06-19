module mod63_reduce_7bit (
    input  logic [6:0] x,
    output logic [5:0] y
);

    logic [6:0] x_minus_63;
    logic [6:0] x_minus_126;

    always_comb begin
        x_minus_63  = x - 7'd63;
        x_minus_126 = x - 7'd126;

        if (x >= 7'd126)
            y = x_minus_126[5:0];
        else if (x >= 7'd63)
            y = x_minus_63[5:0];
        else
            y = x[5:0];
    end

endmodule

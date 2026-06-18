module mod63_add (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);

    logic [6:0] sum;
    logic [6:0] sum_minus_63;

    always_comb begin
        sum = a + b;
        sum_minus_63 = sum - 7'd63;

        if (sum >= 7'd63)
            y = sum_minus_63[5:0];
        else
            y = sum[5:0];
    end
endmodule

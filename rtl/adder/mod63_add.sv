module mod63_add (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);

    logic [6:0] sum;

    always_comb begin
        sum = a + b;

        if (sum >= 7'd63)
            y = sum - 7'd63;
        else
            y = sum[5:0];
    end

endmodule

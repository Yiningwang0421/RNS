module mod65_add (
    input  logic [6:0] a,
    input  logic [6:0] b,
    output logic [6:0] y
);

    logic [7:0] sum;
    logic [7:0] sum_minus_65;

    always_comb begin
        sum = a + b;
        sum_minus_65 = sum - 8'd65;

        if (sum >= 8'd65)
            y = sum_minus_65[6:0];
        else
            y = sum[6:0];
    end

endmodule


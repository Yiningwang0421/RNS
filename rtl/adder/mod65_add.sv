module mod65_add (
    input  logic [6:0] a,
    input  logic [6:0] b,
    output logic [6:0] y
);

    logic [7:0] sum;

    always_comb begin
        sum = a + b;

        if (sum >= 8'd65)
            y = sum - 8'd65;
        else
            y = sum[6:0];
    end

endmodule

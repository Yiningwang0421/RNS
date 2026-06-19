module mod63_add_final (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);

    logic [6:0] sum;

    always_comb begin
        sum = {1'b0, a} + {1'b0, b};
    end

    mod63_reduce_7bit u_reduce (
        .x (sum),
        .y (y)
    );

endmodule

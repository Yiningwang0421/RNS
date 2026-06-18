module mod64_add (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);

    always_comb begin
        y = a + b;
    end

endmodule

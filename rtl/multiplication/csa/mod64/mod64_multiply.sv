module mod64_multiply_fast (
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y
);

    logic [5:0] pp0;
    logic [5:0] pp1;
    logic [5:0] pp2;
    logic [5:0] pp3;
    logic [5:0] pp4;
    logic [5:0] pp5;

    always_comb begin
        // Only keep bits that can affect product[5:0]
        pp0 = b[0] ? a                    : 6'd0;
        pp1 = b[1] ? {a[4:0], 1'b0}        : 6'd0;
        pp2 = b[2] ? {a[3:0], 2'b00}       : 6'd0;
        pp3 = b[3] ? {a[2:0], 3'b000}      : 6'd0;
        pp4 = b[4] ? {a[1:0], 4'b0000}     : 6'd0;
        pp5 = b[5] ? {a[0],   5'b00000}    : 6'd0;

        // Output is 6 bits, so this automatically means mod 64.
        y = pp0 + pp1 + pp2 + pp3 + pp4 + pp5;
    end

endmodule
module rns_sub_63_64_65 (
    input  logic [5:0] a63,
    input  logic [5:0] a64,
    input  logic [6:0] a65,

    input  logic [5:0] b63,
    input  logic [5:0] b64,
    input  logic [6:0] b65,

    output logic [5:0] y63,
    output logic [5:0] y64,
    output logic [6:0] y65
);

    mod63_sub u_sub63 (
        .a(a63),
        .b(b63),
        .y(y63)
    );

    mod64_sub u_sub64 (
        .a(a64),
        .b(b64),
        .y(y64)
    );

    mod65_sub u_sub65 (
        .a(a65),
        .b(b65),
        .y(y65)
    );

endmodule
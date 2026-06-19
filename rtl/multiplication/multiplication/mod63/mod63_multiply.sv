module mod63_multiply (
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
        pp0 = b[0] ? a                 : 6'd0;
        pp1 = b[1] ? {a[4:0], a[5]}     : 6'd0;
        pp2 = b[2] ? {a[3:0], a[5:4]}   : 6'd0;
        pp3 = b[3] ? {a[2:0], a[5:3]}   : 6'd0;
        pp4 = b[4] ? {a[1:0], a[5:2]}   : 6'd0;
        pp5 = b[5] ? {a[0],   a[5:1]}   : 6'd0;
    end

    logic [5:0] s0, c0;
    logic [5:0] s1, c1;
    logic [5:0] s2, c2;
    logic [5:0] s3, c3;

    csa_circular #(.W(6)) u_csa0 (
        .x (pp0),
        .y (pp1),
        .z (pp2),
        .s (s0),
        .c (c0)
    );

    csa_circular #(.W(6)) u_csa1 (
        .x (pp3),
        .y (pp4),
        .z (pp5),
        .s (s1),
        .c (c1)
    );

    csa_circular #(.W(6)) u_csa2 (
        .x (s0),
        .y (c0),
        .z (s1),
        .s (s2),
        .c (c2)
    );

    csa_circular #(.W(6)) u_csa3 (
        .x (s2),
        .y (c2),
        .z (c1),
        .s (s3),
        .c (c3)
    );

    mod63_add_final u_final_add (
        .a (s3),
        .b (c3),
        .y (y)
    );

endmodule
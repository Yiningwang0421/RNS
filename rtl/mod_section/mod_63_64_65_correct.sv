module mod_63_64_65_correct (
    input  logic [7:0] sum63,
    input  logic [7:0] sum65,
    input  logic [5:0] r64_in,

    output logic [5:0] r63,
    output logic [5:0] r64,
    output logic [6:0] r65
);

    logic [7:0] r63_sub63;
    logic [7:0] r63_sub126;

    logic [7:0] r65_sub65;
    logic [7:0] r65_sub130;

    always_comb begin
        // Parallel candidates for mod 63
        r63_sub63  = sum63 - 8'd63;
        r63_sub126 = sum63 - 8'd126;

        if (sum63 >= 8'd126)
            r63 = r63_sub126[5:0];
        else if (sum63 >= 8'd63)
            r63 = r63_sub63[5:0];
        else
            r63 = sum63[5:0];

        // mod64 pass-through
        r64 = r64_in;

        // Parallel candidates for mod 65
        r65_sub65  = sum65 - 8'd65;
        r65_sub130 = sum65 - 8'd130;

        if (sum65 >= 8'd130)
            r65 = r65_sub130[6:0];
        else if (sum65 >= 8'd65)
            r65 = r65_sub65[6:0];
        else
            r65 = sum65[6:0];
    end

endmodule
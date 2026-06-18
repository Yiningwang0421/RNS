module mod_63_64_65_precompute (
    input  logic [15:0] x,

    output logic [7:0]  sum63,
    output logic [7:0]  sum65,
    output logic [5:0]  r64
);

    logic [5:0] chunk0;
    logic [5:0] chunk1;
    logic [3:0] chunk2;

    always_comb begin
        chunk0 = x[5:0];
        chunk1 = x[11:6];
        chunk2 = x[15:12];

        // mod 63 precompute
        // 64 ≡ 1 mod 63
        // x mod 63 = chunk0 + chunk1 + chunk2 mod 63
        sum63 = {2'b00, chunk0}
              + {2'b00, chunk1}
              + {4'b0000, chunk2};

        // mod 65 precompute
        // 64 ≡ -1 mod 65
        // x mod 65 = chunk0 - chunk1 + chunk2
        //
        // Rewrite to avoid signed negative:
        // chunk0 + chunk2 + 65 - chunk1
        sum65 = {2'b00, chunk0}
              + {4'b0000, chunk2}
              + 8'd65
              - {2'b00, chunk1};

        // mod 64
        r64 = chunk0;
    end

endmodule

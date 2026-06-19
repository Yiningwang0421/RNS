module mod65_multiply (
    input  logic [6:0] a,
    input  logic [6:0] b,
    output logic [6:0] y
);

    logic [5:0] a_low;
    logic [5:0] b_low;
    logic       a_neg;
    logic       b_neg;

    logic [11:0] product_low;

    logic [5:0] p_lo;
    logic [5:0] p_hi;

    logic [8:0] folded_biased;

    logic [8:0] cand0;
    logic [8:0] cand1;
    logic [8:0] cand2;
    logic [8:0] cand3;

    always_comb begin
        a_low = a[5:0];
        b_low = b[5:0];

        // a[6] represents 64, which is -1 mod 65
        a_neg = a[6];
        b_neg = b[6];

        // Only multiply the lower 6 bits
        product_low = a_low * b_low;

        // Since 64 ≡ -1 mod 65:
        // product_low mod 65 = product_low[5:0] - product_low[11:6]
        p_lo = product_low[5:0];
        p_hi = product_low[11:6];

        // Biased version to avoid signed arithmetic.
        //
        // raw = p_lo - p_hi
        //       - a_neg*b_low
        //       - b_neg*a_low
        //       + a_neg*b_neg
        //
        // Add 195 = 3*65 to make it always positive.
        folded_biased =
              {3'b000, p_lo}
            + 9'd195
            + {8'd0, (a_neg & b_neg)}
            - {3'b000, p_hi}
            - (a_neg ? {3'b000, b_low} : 9'd0)
            - (b_neg ? {3'b000, a_low} : 9'd0);

        // folded_biased is now in a small positive range.
        // Reduce by 65 using parallel candidates.
        cand0 = folded_biased;
        cand1 = folded_biased - 9'd65;
        cand2 = folded_biased - 9'd130;
        cand3 = folded_biased - 9'd195;

        if (folded_biased >= 9'd195)
            y = cand3[6:0];
        else if (folded_biased >= 9'd130)
            y = cand2[6:0];
        else if (folded_biased >= 9'd65)
            y = cand1[6:0];
        else
            y = cand0[6:0];
    end

endmodule

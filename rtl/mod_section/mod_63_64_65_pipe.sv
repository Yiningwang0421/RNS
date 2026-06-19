module mod_63_64_65_pipe (
    input  logic        clk,
    input  logic        reset_n,

    input  logic        valid_in,
    input  logic signed [15:0] x,

    output logic        valid_out,
    output logic [5:0]  r63,
    output logic [5:0]  r64,
    output logic [6:0]  r65
);

    // Precompute combinational outputs
    logic [7:0] sum63_comb;
    logic [7:0] sum65_comb;
    logic [5:0] r64_comb;

    // Stage 1 registers
    logic       valid_s1;
    logic [7:0] sum63_s1;
    logic [7:0] sum65_s1;
    logic [5:0] r64_s1;
    logic       negative_s1;

    // Correct combinational outputs
    logic [5:0] r63_comb;
    logic [5:0] r64_correct_comb;
    logic [6:0] r65_comb;
    logic [5:0] r63_signed_comb;
    logic [6:0] r65_signed_comb;

    mod_63_64_65_precompute u_precompute (
        .x     (x),
        .sum63 (sum63_comb),
        .sum65 (sum65_comb),
        .r64   (r64_comb)
    );

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_s1 <= 1'b0;
            sum63_s1 <= 8'd0;
            sum65_s1 <= 8'd0;
            r64_s1   <= 6'd0;
            negative_s1 <= 1'b0;
        end else begin
            valid_s1 <= valid_in;
            sum63_s1 <= sum63_comb;
            sum65_s1 <= sum65_comb;
            r64_s1   <= r64_comb;
            negative_s1 <= x[15];
        end
    end

    mod_63_64_65_correct u_correct (
        .sum63  (sum63_s1),
        .sum65  (sum65_s1),
        .r64_in (r64_s1),

        .r63    (r63_comb),
        .r64    (r64_correct_comb),
        .r65    (r65_comb)
    );

    // The precompute block sees the 16-bit two's-complement bit pattern as
    // unsigned. For a negative input that pattern is x + 65536. Since
    // 65536 mod 63 = 16, mod 64 = 0, and mod 65 = 16, subtract 16 from
    // the mod-63 and mod-65 residues to recover the signed value's residues.
    always_comb begin
        r63_signed_comb = r63_comb;
        r65_signed_comb = r65_comb;

        if (negative_s1) begin
            if (r63_comb >= 6'd16)
                r63_signed_comb = r63_comb - 6'd16;
            else
                r63_signed_comb = r63_comb + 6'd47;

            if (r65_comb >= 7'd16)
                r65_signed_comb = r65_comb - 7'd16;
            else
                r65_signed_comb = r65_comb + 7'd49;
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_out <= 1'b0;
            r63       <= 6'd0;
            r64       <= 6'd0;
            r65       <= 7'd0;
        end else begin
            valid_out <= valid_s1;
            r63       <= r63_signed_comb;
            r64       <= r64_correct_comb;
            r65       <= r65_signed_comb;
        end
    end

endmodule

module mod_63_64_65_pipe (
    input  logic        clk,
    input  logic        reset_n,

    input  logic        valid_in,
    input  logic [15:0] x,

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

    // Correct combinational outputs
    logic [5:0] r63_comb;
    logic [5:0] r64_correct_comb;
    logic [6:0] r65_comb;

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
        end else begin
            valid_s1 <= valid_in;
            sum63_s1 <= sum63_comb;
            sum65_s1 <= sum65_comb;
            r64_s1   <= r64_comb;
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

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_out <= 1'b0;
            r63       <= 6'd0;
            r64       <= 6'd0;
            r65       <= 7'd0;
        end else begin
            valid_out <= valid_s1;
            r63       <= r63_comb;
            r64       <= r64_correct_comb;
            r65       <= r65_comb;
        end
    end

endmodule

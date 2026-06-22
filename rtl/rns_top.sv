module rns_top (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        valid_in,

    input  logic [1:0]  op_sel,
    input  logic signed [15:0] a_bin,
    input  logic signed [15:0] b_bin,

    output logic        valid_out,
    output logic [17:0] y_bin,
    output logic signed [17:0] y_signed,

    output logic [5:0]  y63,
    output logic [5:0]  y64,
    output logic [6:0]  y65
);

    localparam logic [1:0] OpAdd = 2'd0;
    localparam logic [1:0] OpSub = 2'd1;
    localparam logic [1:0] OpMul = 2'd2;
    localparam logic [1:0] OpPassA = 2'd3;

    logic [5:0] a63;
    logic [5:0] a64;
    logic [6:0] a65;

    logic [5:0] b63;
    logic [5:0] b64;
    logic [6:0] b65;

    logic       valid_a_rns;
    logic       valid_b_rns;
    logic       valid_res_s1;
    logic       valid_res_s2;
    logic       valid_res_s3;

    mod_63_64_65_pipe u_a_to_rns (
        .clk       (clk),
        .reset_n   (reset_n),
        .valid_in  (valid_in),
        .x         (a_bin),
        .valid_out (valid_a_rns),
        .r63       (a63),
        .r64       (a64),
        .r65       (a65)
    );

    mod_63_64_65_pipe u_b_to_rns (
        .clk       (clk),
        .reset_n   (reset_n),
        .valid_in  (valid_in),
        .x         (b_bin),
        .valid_out (valid_b_rns),
        .r63       (b63),
        .r64       (b64),
        .r65       (b65)
    );

    logic [1:0] op_s1;
    logic [1:0] op_s2;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            op_s1 <= 2'd0;
            op_s2 <= 2'd0;
        end else begin
            op_s1 <= op_sel;
            op_s2 <= op_s1;
        end
    end

    logic [5:0] add63;
    logic [5:0] add64;
    logic [6:0] add65;

    logic [5:0] sub63;
    logic [5:0] sub64;
    logic [6:0] sub65;

    logic [5:0] mul63;
    logic [5:0] mul64;
    logic [6:0] mul65;

    rns_add_63_64_65 u_add (
        .a63 (a63),
        .a64 (a64),
        .a65 (a65),
        .b63 (b63),
        .b64 (b64),
        .b65 (b65),
        .y63 (add63),
        .y64 (add64),
        .y65 (add65)
    );

    rns_sub_63_64_65 u_sub (
        .a63 (a63),
        .a64 (a64),
        .a65 (a65),
        .b63 (b63),
        .b64 (b64),
        .b65 (b65),
        .y63 (sub63),
        .y64 (sub64),
        .y65 (sub65)
    );

    mod63_multiply u_mul63 (
        .a (a63),
        .b (b63),
        .y (mul63)
    );

    mod64_multiply_fast u_mul64 (
        .a (a64),
        .b (b64),
        .y (mul64)
    );

    mod65_multiply u_mul65 (
        .a (a65),
        .b (b65),
        .y (mul65)
    );

    logic [5:0] result63_c;
    logic [5:0] result64_c;
    logic [6:0] result65_c;

    always_comb begin
        result63_c = a63;
        result64_c = a64;
        result65_c = a65;

        unique case (op_s2)
            OpAdd: begin
                result63_c = add63;
                result64_c = add64;
                result65_c = add65;
            end

            OpSub: begin
                result63_c = sub63;
                result64_c = sub64;
                result65_c = sub65;
            end

            OpMul: begin
                result63_c = mul63;
                result64_c = mul64;
                result65_c = mul65;
            end

            default: begin
                result63_c = a63;
                result64_c = a64;
                result65_c = a65;
            end
        endcase
    end

    logic [5:0] y63_s1;
    logic [5:0] y63_s2;
    logic [5:0] y63_s3;
    logic [5:0] y64_s1;
    logic [5:0] y64_s2;
    logic [5:0] y64_s3;
    logic [6:0] y65_s1;
    logic [6:0] y65_s2;
    logic [6:0] y65_s3;

    rns_63_64_65_to_binary_pipe u_to_binary (
        .clk     (clk),
        .reset_n (reset_n),
        .valid_in (valid_a_rns & valid_b_rns),
        .r63     (result63_c),
        .r64     (result64_c),
        .r65     (result65_c),
        .valid_out (),
        .x       (y_bin)
    );

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_res_s1 <= 1'b0;
            valid_res_s2 <= 1'b0;
            valid_res_s3 <= 1'b0;
            y63_s1   <= 6'd0;
            y63_s2   <= 6'd0;
            y63_s3   <= 6'd0;
            y64_s1   <= 6'd0;
            y64_s2   <= 6'd0;
            y64_s3   <= 6'd0;
            y65_s1   <= 7'd0;
            y65_s2   <= 7'd0;
            y65_s3   <= 7'd0;
        end else begin
            valid_res_s1 <= valid_a_rns & valid_b_rns;
            valid_res_s2 <= valid_res_s1;
            valid_res_s3 <= valid_res_s2;

            y63_s1 <= result63_c;
            y63_s2 <= y63_s1;
            y63_s3 <= y63_s2;

            y64_s1 <= result64_c;
            y64_s2 <= y64_s1;
            y64_s3 <= y64_s2;

            y65_s1 <= result65_c;
            y65_s2 <= y65_s1;
            y65_s3 <= y65_s2;
        end
    end

    always_comb begin
        valid_out = valid_res_s3;
        y63       = y63_s3;
        y64       = y64_s3;
        y65       = y65_s3;

        if (y_bin >= 18'd131040)
            y_signed = $signed({1'b0, y_bin}) - 19'sd262080;
        else
            y_signed = $signed(y_bin);
    end

endmodule

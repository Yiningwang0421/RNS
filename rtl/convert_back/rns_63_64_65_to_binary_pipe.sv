module rns_63_64_65_to_binary_pipe (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        valid_in,

    input  logic [5:0]  r63,   // valid range: 0..62
    input  logic [5:0]  r64,   // valid range: 0..63
    input  logic [6:0]  r65,   // valid range: 0..64

    output logic        valid_out,
    output logic [17:0] x      // valid range: 0..262079
);

    // ------------------------------------------------------------
    // t = 32 * d mod 65
    // d range: 0..64
    //
    // This replaces:
    //   q = d >> 1;
    //   if even: t = 65 - q
    //   if odd : t = 32 - q
    //
    // Small 65-entry LUT, 7-bit output.
    // ------------------------------------------------------------
    function automatic logic [6:0] t_lut_32d_mod65 (
        input logic [6:0] d
    );
        begin
            unique case (d)
                7'd0:  t_lut_32d_mod65 = 7'd0;
                7'd1:  t_lut_32d_mod65 = 7'd32;
                7'd2:  t_lut_32d_mod65 = 7'd64;
                7'd3:  t_lut_32d_mod65 = 7'd31;
                7'd4:  t_lut_32d_mod65 = 7'd63;
                7'd5:  t_lut_32d_mod65 = 7'd30;
                7'd6:  t_lut_32d_mod65 = 7'd62;
                7'd7:  t_lut_32d_mod65 = 7'd29;
                7'd8:  t_lut_32d_mod65 = 7'd61;
                7'd9:  t_lut_32d_mod65 = 7'd28;
                7'd10: t_lut_32d_mod65 = 7'd60;
                7'd11: t_lut_32d_mod65 = 7'd27;
                7'd12: t_lut_32d_mod65 = 7'd59;
                7'd13: t_lut_32d_mod65 = 7'd26;
                7'd14: t_lut_32d_mod65 = 7'd58;
                7'd15: t_lut_32d_mod65 = 7'd25;
                7'd16: t_lut_32d_mod65 = 7'd57;
                7'd17: t_lut_32d_mod65 = 7'd24;
                7'd18: t_lut_32d_mod65 = 7'd56;
                7'd19: t_lut_32d_mod65 = 7'd23;
                7'd20: t_lut_32d_mod65 = 7'd55;
                7'd21: t_lut_32d_mod65 = 7'd22;
                7'd22: t_lut_32d_mod65 = 7'd54;
                7'd23: t_lut_32d_mod65 = 7'd21;
                7'd24: t_lut_32d_mod65 = 7'd53;
                7'd25: t_lut_32d_mod65 = 7'd20;
                7'd26: t_lut_32d_mod65 = 7'd52;
                7'd27: t_lut_32d_mod65 = 7'd19;
                7'd28: t_lut_32d_mod65 = 7'd51;
                7'd29: t_lut_32d_mod65 = 7'd18;
                7'd30: t_lut_32d_mod65 = 7'd50;
                7'd31: t_lut_32d_mod65 = 7'd17;
                7'd32: t_lut_32d_mod65 = 7'd49;
                7'd33: t_lut_32d_mod65 = 7'd16;
                7'd34: t_lut_32d_mod65 = 7'd48;
                7'd35: t_lut_32d_mod65 = 7'd15;
                7'd36: t_lut_32d_mod65 = 7'd47;
                7'd37: t_lut_32d_mod65 = 7'd14;
                7'd38: t_lut_32d_mod65 = 7'd46;
                7'd39: t_lut_32d_mod65 = 7'd13;
                7'd40: t_lut_32d_mod65 = 7'd45;
                7'd41: t_lut_32d_mod65 = 7'd12;
                7'd42: t_lut_32d_mod65 = 7'd44;
                7'd43: t_lut_32d_mod65 = 7'd11;
                7'd44: t_lut_32d_mod65 = 7'd43;
                7'd45: t_lut_32d_mod65 = 7'd10;
                7'd46: t_lut_32d_mod65 = 7'd42;
                7'd47: t_lut_32d_mod65 = 7'd9;
                7'd48: t_lut_32d_mod65 = 7'd41;
                7'd49: t_lut_32d_mod65 = 7'd8;
                7'd50: t_lut_32d_mod65 = 7'd40;
                7'd51: t_lut_32d_mod65 = 7'd7;
                7'd52: t_lut_32d_mod65 = 7'd39;
                7'd53: t_lut_32d_mod65 = 7'd6;
                7'd54: t_lut_32d_mod65 = 7'd38;
                7'd55: t_lut_32d_mod65 = 7'd5;
                7'd56: t_lut_32d_mod65 = 7'd37;
                7'd57: t_lut_32d_mod65 = 7'd4;
                7'd58: t_lut_32d_mod65 = 7'd36;
                7'd59: t_lut_32d_mod65 = 7'd3;
                7'd60: t_lut_32d_mod65 = 7'd35;
                7'd61: t_lut_32d_mod65 = 7'd2;
                7'd62: t_lut_32d_mod65 = 7'd34;
                7'd63: t_lut_32d_mod65 = 7'd1;
                7'd64: t_lut_32d_mod65 = 7'd33;
                default: t_lut_32d_mod65 = 7'd0;
            endcase
        end
    endfunction


    // ------------------------------------------------------------
    // Stage 1 combinational:
    // compute:
    //   a = (r63 - r64) mod 63
    //   b = (r64 - r65) mod 65
    // ------------------------------------------------------------

    logic [5:0] r63_norm_c;

    logic [6:0] tmp_a_c;
    logic [7:0] tmp_b_c;   // fixed: needs 8 bits

    logic [5:0] a_c;
    logic [6:0] b_c;
    logic [5:0] r64_c;

    always_comb begin
        r63_norm_c = (r63 == 6'd63) ? 6'd0 : r63;

        tmp_a_c = {1'b0, r63_norm_c} + 7'd63 - {1'b0, r64};

        if (tmp_a_c >= 7'd63)
            a_c = tmp_a_c - 7'd63;
        else
            a_c = tmp_a_c[5:0];

        tmp_b_c = {2'b00, r64} + 8'd65 - {1'b0, r65};

        if (tmp_b_c >= 8'd65)
            b_c = tmp_b_c - 8'd65;
        else
            b_c = tmp_b_c[6:0];

        r64_c = r64;
    end


    // ------------------------------------------------------------
    // Stage 1 registers
    // ------------------------------------------------------------

    logic       valid_s1;
    logic [5:0] a_s1;
    logic [6:0] b_s1;
    logic [5:0] r64_s1;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_s1 <= 1'b0;
            a_s1     <= 6'd0;
            b_s1     <= 7'd0;
            r64_s1   <= 6'd0;
        end else begin
            valid_s1 <= valid_in;
            if (valid_in) begin
                a_s1   <= a_c;
                b_s1   <= b_c;
                r64_s1 <= r64_c;
            end
        end
    end


    // ------------------------------------------------------------
    // Stage 2 combinational:
    // compute:
    //   d = (b - a) mod 65
    //   t = 32*d mod 65
    // ------------------------------------------------------------

    logic [7:0] tmp_d_c;   // fixed: needs 8 bits
    logic [6:0] d_c;
    logic [6:0] t_c;

    always_comb begin
        tmp_d_c = {1'b0, b_s1} + 8'd65 - {2'b00, a_s1};

        if (tmp_d_c >= 8'd65)
            d_c = tmp_d_c - 8'd65;
        else
            d_c = tmp_d_c[6:0];

        t_c = t_lut_32d_mod65(d_c);
    end


    // ------------------------------------------------------------
    // Stage 2 registers
    // ------------------------------------------------------------

    logic       valid_s2;
    logic [5:0] a_s2;
    logic [6:0] t_s2;
    logic [5:0] r64_s2;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_s2 <= 1'b0;
            a_s2     <= 6'd0;
            t_s2     <= 7'd0;
            r64_s2   <= 6'd0;
        end else begin
            valid_s2 <= valid_s1;
            if (valid_s1) begin
                a_s2   <= a_s1;
                t_s2   <= t_c;
                r64_s2 <= r64_s1;
            end
        end
    end


    // ------------------------------------------------------------
    // Stage 3 combinational:
    // compute:
    //   k = a + 63*t
    //     = a + 64*t - t
    //
    // output:
    //   x = 64*k + r64
    //     = {k, r64}
    // ------------------------------------------------------------

    logic [12:0] k_ext_c;
    logic [11:0] k_c;
    logic [17:0] x_c;

    always_comb begin
        k_ext_c = ({6'd0, t_s2} << 6) - {6'd0, t_s2} + {7'd0, a_s2};
        k_c     = k_ext_c[11:0];
        x_c     = {k_c, r64_s2};
    end


    // ------------------------------------------------------------
    // Stage 3 output register
    // ------------------------------------------------------------

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            valid_out <= 1'b0;
            x         <= 18'd0;
        end else begin
            valid_out <= valid_s2;
            if (valid_s2)
                x <= x_c;
        end
    end

endmodule

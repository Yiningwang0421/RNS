module rns_golden_model (
    input  logic [1:0]         op,
    input  logic signed [15:0] a,
    input  logic signed [15:0] b,

    output logic [17:0]        y_bin,
    output logic signed [17:0] y_signed,
    output logic [5:0]         y63,
    output logic [5:0]         y64,
    output logic [6:0]         y65
);

    localparam integer ModN = 262080;

    integer signed a_value;
    integer signed b_value;
    integer signed raw_value;
    integer signed canonical_value;

    always_comb begin
        a_value = a;
        b_value = b;

        case (op)
            2'd0: raw_value = a_value + b_value;
            2'd1: raw_value = a_value - b_value;
            2'd2: raw_value = a_value * b_value;
            default: raw_value = a_value;
        endcase

        canonical_value = raw_value % ModN;
        if (canonical_value < 0)
            canonical_value = canonical_value + ModN;

        y_bin = canonical_value[17:0];
        if (canonical_value >= 131040)
            y_signed = canonical_value - ModN;
        else
            y_signed = canonical_value;

        y63 = canonical_value % 63;
        y64 = canonical_value % 64;
        y65 = canonical_value % 65;
    end

endmodule

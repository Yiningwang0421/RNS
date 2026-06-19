module csa_circular #(
    parameter int W = 6
)(
    input  logic [W-1:0] x,
    input  logic [W-1:0] y,
    input  logic [W-1:0] z,

    output logic [W-1:0] s,
    output logic [W-1:0] c
);

    logic [W-1:0] carry_raw;

    always_comb begin
        // Sum bits without carry propagation
        s = x ^ y ^ z;

        // Carry generation
        carry_raw = (x & y) | (x & z) | (y & z);

        // Circular carry:
        // normal CSA carry would be carry_raw << 1
        // for modulus 2^W - 1, the carry out from bit W-1 wraps to bit 0
        c = {carry_raw[W-2:0], carry_raw[W-1]};
    end

endmodule

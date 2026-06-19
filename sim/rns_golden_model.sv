module rns_golden_model (
    input  logic [1:0]  op,
    input  logic [15:0] a,
    input  logic [15:0] b,

    output logic [17:0] y_bin,
    output logic [5:0]  y63,
    output logic [5:0]  y64,
    output logic [6:0]  y65
);

    localparam int unsigned ModN = 262080;

    logic [31:0] value;
    logic [31:0] product;

    always_comb begin
        product = {16'd0, a} * {16'd0, b};

        case (op)
            2'd0: value = ({16'd0, a} + {16'd0, b}) % ModN;
            2'd1: value = ({16'd0, a} + ModN - {16'd0, b}) % ModN;
            2'd2: value = product % ModN;
            default: value = a;
        endcase

        y_bin = value[17:0];
        y63   = value % 63;
        y64   = value % 64;
        y65   = value % 65;
    end

endmodule

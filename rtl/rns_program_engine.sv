module rns_program_engine #(
    parameter integer RegisterCount = 8,
    parameter integer AddressWidth  = 3
) (
    input  logic                         clk,
    input  logic                         reset_n,

    // One pulse converts all program inputs in parallel and stores them in
    // RNS registers 0..RegisterCount-1.
    input  logic                         load_valid,
    input  logic [RegisterCount*16-1:0]  load_values,
    output logic                         load_ready,
    output logic                         load_done,

    // Register-to-register RNS instruction interface.
    input  logic                         instruction_valid,
    input  logic [1:0]                   instruction_op,
    input  logic [AddressWidth-1:0]      destination,
    input  logic [AddressWidth-1:0]      source_a,
    input  logic [AddressWidth-1:0]      source_b,
    output logic                         instruction_ready,
    output logic                         instruction_done,

    // Convert one selected RNS register back to binary.
    input  logic                         convert_valid,
    input  logic [AddressWidth-1:0]      convert_source,
    output logic                         convert_ready,
    output logic                         result_valid,
    output logic [17:0]                  result_binary,
    output logic signed [17:0]           result_signed
);

    localparam logic [1:0] OpAdd   = 2'd0;
    localparam logic [1:0] OpSub   = 2'd1;
    localparam logic [1:0] OpMul   = 2'd2;
    localparam logic [1:0] OpPassA = 2'd3;

    logic [5:0] register63 [0:RegisterCount-1];
    logic [5:0] register64 [0:RegisterCount-1];
    logic [6:0] register65 [0:RegisterCount-1];

    logic       load_busy;
    logic       converter_valid [0:RegisterCount-1];
    logic [5:0] converted63 [0:RegisterCount-1];
    logic [5:0] converted64 [0:RegisterCount-1];
    logic [6:0] converted65 [0:RegisterCount-1];

    genvar lane;
    generate
        for (lane = 0; lane < RegisterCount; lane = lane + 1) begin : g_input_converter
            mod_63_64_65_pipe u_input_converter (
                .clk       (clk),
                .reset_n   (reset_n),
                .valid_in  (load_valid & load_ready),
                .x         ($signed(load_values[lane*16 +: 16])),
                .valid_out (converter_valid[lane]),
                .r63       (converted63[lane]),
                .r64       (converted64[lane]),
                .r65       (converted65[lane])
            );
        end
    endgenerate

    logic [5:0] operand_a63;
    logic [5:0] operand_a64;
    logic [6:0] operand_a65;
    logic [5:0] operand_b63;
    logic [5:0] operand_b64;
    logic [6:0] operand_b65;

    always_comb begin
        operand_a63 = register63[source_a];
        operand_a64 = register64[source_a];
        operand_a65 = register65[source_a];
        operand_b63 = register63[source_b];
        operand_b64 = register64[source_b];
        operand_b65 = register65[source_b];
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
        .a63 (operand_a63), .a64 (operand_a64), .a65 (operand_a65),
        .b63 (operand_b63), .b64 (operand_b64), .b65 (operand_b65),
        .y63 (add63),       .y64 (add64),       .y65 (add65)
    );

    rns_sub_63_64_65 u_sub (
        .a63 (operand_a63), .a64 (operand_a64), .a65 (operand_a65),
        .b63 (operand_b63), .b64 (operand_b64), .b65 (operand_b65),
        .y63 (sub63),       .y64 (sub64),       .y65 (sub65)
    );

    mod63_multiply u_mul63 (
        .a (operand_a63), .b (operand_b63), .y (mul63)
    );

    mod64_multiply_fast u_mul64 (
        .a (operand_a64), .b (operand_b64), .y (mul64)
    );

    mod65_multiply u_mul65 (
        .a (operand_a65), .b (operand_b65), .y (mul65)
    );

    logic [5:0] instruction_result63;
    logic [5:0] instruction_result64;
    logic [6:0] instruction_result65;

    always_comb begin
        instruction_result63 = operand_a63;
        instruction_result64 = operand_a64;
        instruction_result65 = operand_a65;

        unique case (instruction_op)
            OpAdd: begin
                instruction_result63 = add63;
                instruction_result64 = add64;
                instruction_result65 = add65;
            end
            OpSub: begin
                instruction_result63 = sub63;
                instruction_result64 = sub64;
                instruction_result65 = sub65;
            end
            OpMul: begin
                instruction_result63 = mul63;
                instruction_result64 = mul64;
                instruction_result65 = mul65;
            end
            OpPassA: begin
                instruction_result63 = operand_a63;
                instruction_result64 = operand_a64;
                instruction_result65 = operand_a65;
            end
        endcase
    end

    integer register_index;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            load_busy        <= 1'b0;
            load_done        <= 1'b0;
            instruction_done <= 1'b0;
            for (register_index = 0;
                 register_index < RegisterCount;
                 register_index = register_index + 1) begin
                register63[register_index] <= 6'd0;
                register64[register_index] <= 6'd0;
                register65[register_index] <= 7'd0;
            end
        end else begin
            load_done        <= 1'b0;
            instruction_done <= 1'b0;

            if (load_valid & load_ready)
                load_busy <= 1'b1;

            if (converter_valid[0] & load_busy) begin
                load_busy <= 1'b0;
                load_done <= 1'b1;
                for (register_index = 0;
                     register_index < RegisterCount;
                     register_index = register_index + 1) begin
                    register63[register_index] <= converted63[register_index];
                    register64[register_index] <= converted64[register_index];
                    register65[register_index] <= converted65[register_index];
                end
            end else if (instruction_valid & instruction_ready) begin
                register63[destination] <= instruction_result63;
                register64[destination] <= instruction_result64;
                register65[destination] <= instruction_result65;
                instruction_done <= 1'b1;
            end
        end
    end

    always_comb begin
        load_ready        = ~load_busy;
        instruction_ready = ~load_busy;
        convert_ready     = ~load_busy;
    end

    logic [5:0] convert63;
    logic [5:0] convert64;
    logic [6:0] convert65;

    always_comb begin
        convert63 = register63[convert_source];
        convert64 = register64[convert_source];
        convert65 = register65[convert_source];
    end

    rns_63_64_65_to_binary_pipe u_output_converter (
        .clk       (clk),
        .reset_n   (reset_n),
        .valid_in  (convert_valid & convert_ready),
        .r63       (convert63),
        .r64       (convert64),
        .r65       (convert65),
        .valid_out (result_valid),
        .x         (result_binary)
    );

    always_comb begin
        if (result_binary >= 18'd131040)
            result_signed = $signed({1'b0, result_binary}) - 19'sd262080;
        else
            result_signed = $signed(result_binary);
    end

endmodule

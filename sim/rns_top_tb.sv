`timescale 1ns/1ps

module rns_top_tb;

    localparam int unsigned ModN = 262080;
    localparam int unsigned DutLatency = 4;
    localparam int unsigned OperandBinCount = 6;
    localparam int unsigned ScenarioBinCount = 12;

    localparam logic [1:0] OpAdd   = 2'd0;
    localparam logic [1:0] OpSub   = 2'd1;
    localparam logic [1:0] OpMul   = 2'd2;
    localparam logic [1:0] OpPassA = 2'd3;

    logic clk;
    logic reset_n;
    logic valid_in;
    logic [1:0] op_sel;
    logic signed [15:0] a_bin;
    logic signed [15:0] b_bin;

    logic valid_out;
    logic [17:0] y_bin;
    logic signed [17:0] y_signed;
    logic [5:0] y63;
    logic [5:0] y64;
    logic [6:0] y65;

    logic program_load_valid;
    logic [127:0] program_load_values;
    logic program_load_ready;
    logic program_load_done;
    logic program_instruction_valid;
    logic [1:0] program_instruction_op;
    logic [2:0] program_destination;
    logic [2:0] program_source_a;
    logic [2:0] program_source_b;
    logic program_instruction_ready;
    logic program_instruction_done;
    logic program_convert_valid;
    logic [2:0] program_convert_source;
    logic program_convert_ready;
    logic program_result_valid;
    logic [17:0] program_result_binary;
    logic signed [17:0] program_result_signed;

    logic [17:0] golden_bin;
    logic signed [17:0] golden_signed;
    logic [5:0] golden_r63;
    logic [5:0] golden_r64;
    logic [6:0] golden_r65;

    rns_top dut (
        .clk       (clk),
        .reset_n   (reset_n),
        .valid_in  (valid_in),
        .op_sel    (op_sel),
        .a_bin     (a_bin),
        .b_bin     (b_bin),
        .valid_out (valid_out),
        .y_bin     (y_bin),
        .y_signed  (y_signed),
        .y63       (y63),
        .y64       (y64),
        .y65       (y65)
    );

    rns_golden_model golden (
        .op    (op_sel),
        .a     (a_bin),
        .b     (b_bin),
        .y_bin (golden_bin),
        .y_signed (golden_signed),
        .y63   (golden_r63),
        .y64   (golden_r64),
        .y65   (golden_r65)
    );

    rns_program_engine #(
        .RegisterCount (8),
        .AddressWidth  (3)
    ) program_engine (
        .clk               (clk),
        .reset_n           (reset_n),
        .load_valid        (program_load_valid),
        .load_values       (program_load_values),
        .load_ready        (program_load_ready),
        .load_done         (program_load_done),
        .instruction_valid (program_instruction_valid),
        .instruction_op    (program_instruction_op),
        .destination       (program_destination),
        .source_a          (program_source_a),
        .source_b          (program_source_b),
        .instruction_ready (program_instruction_ready),
        .instruction_done  (program_instruction_done),
        .convert_valid     (program_convert_valid),
        .convert_source    (program_convert_source),
        .convert_ready     (program_convert_ready),
        .result_valid      (program_result_valid),
        .result_binary     (program_result_binary),
        .result_signed     (program_result_signed)
    );

    logic [17:0] expected_bin_q[$];
    logic signed [17:0] expected_signed_q[$];
    logic [5:0] expected_r63_q[$];
    logic [5:0] expected_r64_q[$];
    logic [6:0] expected_r65_q[$];
    logic [1:0] expected_op_q[$];
    logic signed [15:0] expected_a_q[$];
    logic signed [15:0] expected_b_q[$];
    integer expected_id_q[$];
    integer expected_cycle_q[$];

    integer op_hits [0:3];
    integer a_bin_hits [0:OperandBinCount-1];
    integer b_bin_hits [0:OperandBinCount-1];
    integer op_a_b_cross [0:3][0:OperandBinCount-1][0:OperandBinCount-1];
    integer relation_hits [0:2];
    integer scenario_hits [0:ScenarioBinCount-1];
    integer residue_edge_hits [0:8];
    integer special_hits [0:7];

    integer transaction_count;
    integer checked_count;
    integer error_count;
    integer op_checked [0:3];
    integer op_failed [0:3];
    integer cycle_count;
    integer random_test_count;
    integer seed;
    integer seed_dummy;
    integer chain_count;
    integer chain_passed;
    integer chain_failed;
    integer program_count;
    integer program_passed;
    integer program_failed;
    integer program_zero_length;
    integer program_1_to_9;
    integer program_10_to_49;
    integer program_50_to_99;
    integer program_100;
    integer last_checked_id;
    integer last_checked_failed;
    logic signed [17:0] last_checked_signed;
    logic [5:0] last_checked_r63;
    logic [5:0] last_checked_r64;
    logic [6:0] last_checked_r65;

    function automatic integer operand_bin(input logic signed [15:0] value);
        begin
            if (value == -32768)
                operand_bin = 0;
            else if (value < 0)
                operand_bin = 1;
            else if (value == 0)
                operand_bin = 2;
            else if (value == 1)
                operand_bin = 3;
            else if (value < 32767)
                operand_bin = 4;
            else
                operand_bin = 5;
        end
    endfunction

    function automatic logic signed [15:0] random_from_bin(input integer bin_index);
        begin
            case (bin_index)
                0: random_from_bin = -32768;
                1: random_from_bin = -$signed($urandom_range(1, 32767));
                2: random_from_bin = 0;
                3: random_from_bin = 1;
                4: random_from_bin = $urandom_range(2, 32766);
                default: random_from_bin = 32767;
            endcase
        end
    endfunction

    function automatic [8*8-1:0] op_name(input logic [1:0] op);
        begin
            case (op)
                OpAdd: op_name = "ADD";
                OpSub: op_name = "SUB";
                OpMul: op_name = "MUL";
                default: op_name = "PASS_A";
            endcase
        end
    endfunction

    task automatic sample_coverage(
        input logic [1:0] op,
        input logic signed [15:0] a,
        input logic signed [15:0] b,
        input logic [17:0] result,
        input logic [5:0] result63,
        input logic [5:0] result64,
        input logic [6:0] result65,
        input integer scenario
    );
        integer a_category;
        integer b_category;
        integer signed wide_sum;
        integer signed wide_product;
        begin
            a_category = operand_bin(a);
            b_category = operand_bin(b);
            wide_sum = a + b;
            wide_product = a * b;

            op_hits[op]++;
            a_bin_hits[a_category]++;
            b_bin_hits[b_category]++;
            op_a_b_cross[op][a_category][b_category]++;
            scenario_hits[scenario]++;

            if (a == b)
                relation_hits[0]++;
            else if (a < b)
                relation_hits[1]++;
            else
                relation_hits[2]++;

            if (result63 == 0) residue_edge_hits[0]++;
            if (result63 == 1) residue_edge_hits[1]++;
            if (result63 == 62) residue_edge_hits[2]++;
            if (result64 == 0) residue_edge_hits[3]++;
            if (result64 == 1) residue_edge_hits[4]++;
            if (result64 == 63) residue_edge_hits[5]++;
            if (result65 == 0) residue_edge_hits[6]++;
            if (result65 == 1) residue_edge_hits[7]++;
            if (result65 == 64) residue_edge_hits[8]++;

            if ((op == OpAdd) &&
                ((wide_sum > 32767) || (wide_sum < -32768))) special_hits[0]++;
            if ((op == OpSub) && (a < b)) special_hits[1]++;
            if ((op == OpSub) && (a == b)) special_hits[2]++;
            if ((op == OpMul) && ((a == 0) || (b == 0))) special_hits[3]++;
            if ((op == OpMul) &&
                ((a == 1) || (b == 1) || (a == -1) || (b == -1)))
                special_hits[4]++;
            if ((op == OpMul) &&
                ((wide_product >= 262080) || (wide_product <= -262080)))
                special_hits[5]++;
            if ((op == OpMul) && (wide_product < 262080) &&
                (wide_product > -262080) && (a != 0) && (b != 0))
                special_hits[6]++;
            if (op == OpPassA) special_hits[7]++;
        end
    endtask

    task automatic drive_transaction(
        input logic [1:0] op,
        input logic signed [15:0] a,
        input logic signed [15:0] b,
        input integer scenario
    );
        begin
            @(negedge clk);
            op_sel = op;
            a_bin = a;
            b_bin = b;
            valid_in = 1'b1;
            #1;

            transaction_count++;
            expected_bin_q.push_back(golden_bin);
            expected_signed_q.push_back(golden_signed);
            expected_r63_q.push_back(golden_r63);
            expected_r64_q.push_back(golden_r64);
            expected_r65_q.push_back(golden_r65);
            expected_op_q.push_back(op);
            expected_a_q.push_back(a);
            expected_b_q.push_back(b);
            expected_id_q.push_back(transaction_count);
            expected_cycle_q.push_back(cycle_count + DutLatency + 1);

            sample_coverage(
                op, a, b, golden_bin, golden_r63, golden_r64, golden_r65, scenario
            );

            $display(
                "[drive %0d] %0s a=%0d b=%0d -> signed=%0d canonical=%0d r63=%0d r64=%0d r65=%0d",
                transaction_count, op_name(op), a, b, golden_signed, golden_bin,
                golden_r63, golden_r64, golden_r65
            );

            case (op)
                OpAdd:
                    $display("[meaning %0d] %0d + %0d -> signed %0d, canonical %0d",
                             transaction_count, a, b, golden_signed, golden_bin);
                OpSub:
                    $display("[meaning %0d] %0d - %0d -> signed %0d, canonical %0d",
                             transaction_count, a, b, golden_signed, golden_bin);
                OpMul:
                    $display("[meaning %0d] %0d * %0d -> signed %0d, canonical %0d",
                             transaction_count, a, b, golden_signed, golden_bin);
                default:
                    $display("[meaning %0d] PASS A returns signed %0d (canonical %0d); b=%0d is ignored",
                             transaction_count, golden_signed, golden_bin, b);
            endcase
        end
    endtask

    task automatic drive_and_wait(
        input logic [1:0] op,
        input logic signed [15:0] a,
        input logic signed [15:0] b,
        input integer scenario,
        output logic signed [17:0] result,
        output integer failed
    );
        integer transaction_id;
        begin
            drive_transaction(op, a, b, scenario);
            transaction_id = transaction_count;

            // A dependent sequence must wait for this result before issuing
            // the next operation. Deassert valid so the current transaction
            // is not accepted repeatedly during that wait.
            @(negedge clk);
            valid_in = 1'b0;
            op_sel = OpAdd;
            a_bin = 16'sd0;
            b_bin = 16'sd0;

            wait (last_checked_id >= transaction_id);
            #1;
            result = last_checked_signed;
            failed = last_checked_failed;
        end
    endtask

    task automatic run_mac_chain(
        input logic signed [15:0] a,
        input logic signed [15:0] b,
        input logic signed [15:0] c,
        input logic signed [15:0] d
    );
        logic signed [17:0] add_result;
        logic signed [17:0] multiply_result;
        logic signed [17:0] final_result;
        integer stage_failed;
        integer sequence_failed;
        integer signed expected_add;
        integer signed expected_multiply;
        integer signed expected_final;
        begin
            chain_count++;
            sequence_failed = 0;
            expected_add = a + b;
            expected_multiply = expected_add * c;
            expected_final = expected_multiply + d;

            $display(
                "[sequence %0d] START: (%0d + %0d) * %0d + %0d",
                chain_count, a, b, c, d
            );

            drive_and_wait(OpAdd, a, b, 10, add_result, stage_failed);
            sequence_failed = sequence_failed | stage_failed;

            if ((add_result < -32768) || (add_result > 32767)) begin
                sequence_failed = 1;
                $display(
                    "[sequence %0d] FAIL: A+B=%0d cannot feed the signed 16-bit input",
                    chain_count, add_result
                );
            end else begin
                drive_and_wait(
                    OpMul, add_result[15:0], c, 10,
                    multiply_result, stage_failed
                );
                sequence_failed = sequence_failed | stage_failed;

                if ((multiply_result < -32768) ||
                    (multiply_result > 32767)) begin
                    sequence_failed = 1;
                    $display(
                        "[sequence %0d] FAIL: (A+B)*C=%0d cannot feed the signed 16-bit input",
                        chain_count, multiply_result
                    );
                end else begin
                    drive_and_wait(
                        OpAdd, multiply_result[15:0], d, 10,
                        final_result, stage_failed
                    );
                    sequence_failed = sequence_failed | stage_failed;

                    if ((add_result !== expected_add) ||
                        (multiply_result !== expected_multiply) ||
                        (final_result !== expected_final)) begin
                        sequence_failed = 1;
                        $display(
                            "[sequence %0d] FAIL: stages got=(%0d,%0d,%0d) expected=(%0d,%0d,%0d)",
                            chain_count, add_result, multiply_result, final_result,
                            expected_add, expected_multiply, expected_final
                        );
                    end
                end
            end

            if (sequence_failed) begin
                chain_failed++;
                error_count++;
            end else begin
                chain_passed++;
                $display(
                    "[sequence %0d] PASS: (%0d + %0d) * %0d + %0d = %0d",
                    chain_count, a, b, c, d, final_result
                );
            end
        end
    endtask

    task automatic run_chained_sequences;
        integer index;
        logic signed [15:0] a;
        logic signed [15:0] b;
        logic signed [15:0] c;
        logic signed [15:0] d;
        begin
            $display("[scenario] dependent MAC-style sequences: (A+B)*C+D");

            run_mac_chain(3, 4, 5, 6);
            run_mac_chain(-10, 4, 3, 2);
            run_mac_chain(100, 20, -2, 7);
            run_mac_chain(300, 200, 20, -100);

            for (index = 0; index < 96; index++) begin
                a = $signed($urandom_range(0, 200)) - 100;
                b = $signed($urandom_range(0, 200)) - 100;
                c = $signed($urandom_range(0, 20)) - 10;
                d = $signed($urandom_range(0, 200)) - 100;
                run_mac_chain(a, b, c, d);
            end
        end
    endtask

    task automatic issue_program_instruction(
        input logic [1:0] operation,
        input logic [2:0] destination_register,
        input logic [2:0] source_register_a,
        input logic [2:0] source_register_b
    );
        begin
            wait (program_instruction_ready);
            @(negedge clk);
            program_instruction_op = operation;
            program_destination = destination_register;
            program_source_a = source_register_a;
            program_source_b = source_register_b;
            program_instruction_valid = 1'b1;
            @(negedge clk);
            program_instruction_valid = 1'b0;
            wait (program_instruction_done);
        end
    endtask

    task automatic run_parallel_input_program;
        integer expected_result;
        begin
            // Program: ((a + b) * c - d) + e
            // R0..R4 receive a..e simultaneously. R5/R6 are temporaries.
            program_load_values = 128'd0;
            program_load_values[0*16 +: 16] = 16'sd3;
            program_load_values[1*16 +: 16] = 16'sd4;
            program_load_values[2*16 +: 16] = 16'sd5;
            program_load_values[3*16 +: 16] = 16'sd6;
            program_load_values[4*16 +: 16] = 16'sd7;
            expected_result = ((3 + 4) * 5 - 6) + 7;

            $display("[scenario] parallel program input conversion and RNS register execution");
            wait (program_load_ready);
            @(negedge clk);
            program_load_valid = 1'b1;
            @(negedge clk);
            program_load_valid = 1'b0;
            wait (program_load_done);

            issue_program_instruction(OpAdd, 3'd5, 3'd0, 3'd1);
            issue_program_instruction(OpMul, 3'd6, 3'd5, 3'd2);
            issue_program_instruction(OpSub, 3'd5, 3'd6, 3'd3);
            issue_program_instruction(OpAdd, 3'd6, 3'd5, 3'd4);

            wait (program_convert_ready);
            @(negedge clk);
            program_convert_source = 3'd6;
            program_convert_valid = 1'b1;
            @(negedge clk);
            program_convert_valid = 1'b0;
            wait (program_result_valid);
            #1;

            if (program_result_signed !== expected_result) begin
                error_count++;
                $display("[program-engine] FAIL: got=%0d expected=%0d",
                         program_result_signed, expected_result);
            end else begin
                $display("[program-engine] PASS: five inputs converted in parallel, four RNS instructions, one final CRT conversion, result=%0d",
                         program_result_signed);
            end
        end
    endtask
    task automatic run_operation_program(
        input integer length,
        input logic signed [15:0] initial_value
    );
        integer step;
        integer stage_failed;
        integer sequence_failed;
        integer operation_choice;
        integer signed operand_value;
        integer signed expected_value;
        integer signed candidate_value;
        logic signed [17:0] dut_value;
        logic signed [15:0] accumulator;
        logic [1:0] operation;
        begin
            program_count++;
            sequence_failed = 0;
            accumulator = initial_value;
            expected_value = initial_value;

            if (length == 0)
                program_zero_length++;
            else if (length < 10)
                program_1_to_9++;
            else if (length < 50)
                program_10_to_49++;
            else if (length < 100)
                program_50_to_99++;
            else
                program_100++;

            $display(
                "[program %0d] START: length=%0d initial=%0d",
                program_count, length, initial_value
            );

            for (step = 0; step < length; step++) begin
                operation_choice = $urandom_range(0, 3);

                case (operation_choice)
                    0: begin
                        operation = OpAdd;
                        operand_value = $signed($urandom_range(0, 200)) - 100;
                        candidate_value = expected_value + operand_value;
                    end
                    1: begin
                        operation = OpSub;
                        operand_value = $signed($urandom_range(0, 200)) - 100;
                        candidate_value = expected_value - operand_value;
                    end
                    2: begin
                        operation = OpMul;
                        operand_value = $signed($urandom_range(0, 4)) - 2;
                        candidate_value = expected_value * operand_value;
                    end
                    default: begin
                        operation = OpPassA;
                        operand_value = $signed($urandom_range(0, 200)) - 100;
                        candidate_value = expected_value;
                    end
                endcase

                // Keep every intermediate representable by the signed
                // 16-bit binary input used by the next dependent operation.
                if ((candidate_value < -32768) || (candidate_value > 32767)) begin
                    operation = OpPassA;
                    operand_value = 0;
                    candidate_value = expected_value;
                end

                drive_and_wait(
                    operation,
                    accumulator,
                    operand_value[15:0],
                    11,
                    dut_value,
                    stage_failed
                );

                if (stage_failed || (dut_value !== candidate_value)) begin
                    sequence_failed = 1;
                    $display(
                        "[program %0d] FAIL step=%0d/%0d op=%0s accumulator=%0d operand=%0d got=%0d expected=%0d",
                        program_count, step + 1, length, op_name(operation),
                        accumulator, operand_value, dut_value, candidate_value
                    );
                end

                accumulator = dut_value[15:0];
                expected_value = candidate_value;
            end

            if (sequence_failed) begin
                program_failed++;
                error_count++;
            end else begin
                program_passed++;
                $display(
                    "[program %0d] PASS: length=%0d final=%0d",
                    program_count, length, expected_value
                );
            end
        end
    endtask

    task automatic run_variable_length_programs;
        integer index;
        integer random_length;
        logic signed [15:0] initial_value;
        begin
            $display("[scenario] variable-length dependent operation programs");

            run_operation_program(0, 7);
            run_operation_program(1, -3);
            run_operation_program(10, 5);
            run_operation_program(25, -20);
            run_operation_program(50, 11);
            run_operation_program(100, -7);

            for (index = 0; index < 194; index++) begin
                random_length = $urandom_range(0, 100);
                initial_value = $signed($urandom_range(0, 200)) - 100;
                run_operation_program(random_length, initial_value);
            end
        end
    endtask

    task automatic drive_idle(input integer cycles);
        integer index;
        begin
            for (index = 0; index < cycles; index++) begin
                @(negedge clk);
                valid_in = 1'b0;
                op_sel = OpAdd;
                a_bin = 16'd0;
                b_bin = 16'd0;
            end
        end
    endtask

    task automatic run_directed_edges;
        integer op_index;
        begin
            $display("[scenario] directed arithmetic and boundary cases");

            drive_transaction(OpAdd, 0, 0, 0);
            drive_transaction(OpAdd, -1, 1, 0);
            drive_transaction(OpAdd, 32767, 1, 0);
            drive_transaction(OpAdd, -32768, -1, 0);
            drive_transaction(OpAdd, -12345, 23456, 0);

            drive_transaction(OpSub, 0, 0, 0);
            drive_transaction(OpSub, 0, 1, 0);
            drive_transaction(OpSub, 0, -1, 0);
            drive_transaction(OpSub, -32768, 32767, 0);
            drive_transaction(OpSub, 32767, -32768, 0);

            drive_transaction(OpMul, 0, -32768, 0);
            drive_transaction(OpMul, 1, -32768, 0);
            drive_transaction(OpMul, -1, -1, 0);
            drive_transaction(OpMul, -2, 3, 0);
            drive_transaction(OpMul, -32768, 32767, 0);

            drive_transaction(OpPassA, 0, -1, 0);
            drive_transaction(OpPassA, 1, 123, 0);
            drive_transaction(OpPassA, -1, 0, 0);
            drive_transaction(OpPassA, -32768, 0, 0);
            drive_transaction(OpPassA, 32767, 0, 0);
            drive_transaction(OpPassA, 63, 0, 0);
            drive_transaction(OpPassA, 64, 0, 0);

            for (op_index = 0; op_index < 4; op_index++)
                drive_transaction(op_index[1:0], -32768, -32768, 0);
        end
    endtask

    task automatic run_cross_coverage;
        integer op_index;
        integer a_category;
        integer b_category;
        begin
            $display("[scenario] constrained operand-bin cross coverage");
            for (op_index = 0; op_index < 4; op_index++) begin
                for (a_category = 0; a_category < OperandBinCount; a_category++) begin
                    for (b_category = 0; b_category < OperandBinCount; b_category++) begin
                        drive_transaction(
                            op_index[1:0],
                            random_from_bin(a_category),
                            random_from_bin(b_category),
                            1
                        );
                    end
                end
            end
        end
    endtask

    task automatic run_constrained_random(input integer count);
        integer index;
        integer constraint_kind;
        logic [1:0] op;
        logic signed [15:0] a;
        logic signed [15:0] b;
        begin
            $display("[scenario] %0d constrained-random transactions", count);
            for (index = 0; index < count; index++) begin
                constraint_kind = $urandom_range(2, 9);
                op = $urandom_range(0, 3);
                a = $signed($urandom);
                b = $signed($urandom);

                case (constraint_kind)
                    2: begin
                        a = $signed($urandom);
                        b = a;
                    end
                    3: begin
                        a = -$signed($urandom_range(1, 32768));
                        b = $urandom_range(0, 32767);
                    end
                    4: begin
                        a = $urandom_range(0, 32767);
                        b = -$signed($urandom_range(1, 32768));
                    end
                    5: begin
                        if ($urandom_range(0, 1) == 0)
                            a = 0;
                        else
                            b = 0;
                    end
                    6: begin
                        case ($urandom_range(0, 7))
                            0: a = -32768;
                            1: a = -32767;
                            2: a = -1;
                            3: a = 0;
                            4: a = 1;
                            5: a = 63;
                            6: a = 64;
                            default: a = 32767;
                        endcase
                    end
                    7: begin
                        op = OpMul;
                        a = -$signed($urandom_range(16384, 32768));
                        b = $urandom_range(16384, 32767);
                    end
                    8: begin
                        op = OpSub;
                        a = -$signed($urandom_range(1, 32768));
                        b = $urandom_range(0, 32767);
                    end
                    default: begin
                        op = OpAdd;
                        if ($urandom_range(0, 1) == 0) begin
                            a = $urandom_range(20000, 32767);
                            b = $urandom_range(20000, 32767);
                        end else begin
                            a = -$signed($urandom_range(20000, 32768));
                            b = -$signed($urandom_range(20000, 32768));
                        end
                    end
                endcase

                drive_transaction(op, a, b, constraint_kind);

                if ($urandom_range(0, 4) == 0)
                    drive_idle($urandom_range(1, 3));
            end
        end
    endtask

    task automatic report_coverage;
        integer index;
        integer op_index;
        integer a_category;
        integer b_category;
        integer op_covered;
        integer a_covered;
        integer b_covered;
        integer cross_covered;
        integer relation_covered;
        integer scenario_covered;
        integer residue_covered;
        integer special_covered;
        integer total_covered;
        integer total_bins;
        integer coverage_percent;
        begin
            op_covered = 0;
            a_covered = 0;
            b_covered = 0;
            cross_covered = 0;
            relation_covered = 0;
            scenario_covered = 0;
            residue_covered = 0;
            special_covered = 0;

            for (index = 0; index < 4; index++)
                if (op_hits[index] > 0) op_covered++;
            for (index = 0; index < OperandBinCount; index++) begin
                if (a_bin_hits[index] > 0) a_covered++;
                if (b_bin_hits[index] > 0) b_covered++;
            end
            for (op_index = 0; op_index < 4; op_index++)
                for (a_category = 0; a_category < OperandBinCount; a_category++)
                    for (b_category = 0; b_category < OperandBinCount; b_category++)
                        if (op_a_b_cross[op_index][a_category][b_category] > 0)
                            cross_covered++;
            for (index = 0; index < 3; index++)
                if (relation_hits[index] > 0) relation_covered++;
            for (index = 0; index < ScenarioBinCount; index++)
                if (scenario_hits[index] > 0) scenario_covered++;
            for (index = 0; index < 9; index++)
                if (residue_edge_hits[index] > 0) residue_covered++;
            for (index = 0; index < 8; index++)
                if (special_hits[index] > 0) special_covered++;

            total_covered = op_covered + a_covered + b_covered + cross_covered
                          + relation_covered + scenario_covered + residue_covered
                          + special_covered;
            total_bins = 4 + 6 + 6 + 144 + 3 + ScenarioBinCount + 9 + 8;
            coverage_percent = (100 * total_covered) / total_bins;

            $display("[coverage] operations: %0d/4 bins", op_covered);
            $display("[coverage] operand A categories: %0d/6 bins", a_covered);
            $display("[coverage] operand B categories: %0d/6 bins", b_covered);
            $display("[coverage] operation x A x B cross: %0d/144 bins", cross_covered);
            $display("[coverage] A/B relationships: %0d/3 bins", relation_covered);
            $display("[coverage] constraint scenarios: %0d/%0d bins",
                     scenario_covered, ScenarioBinCount);
            $display("[coverage] residue edge values: %0d/9 bins", residue_covered);
            $display("[coverage] arithmetic special cases: %0d/8 bins", special_covered);
            $display(
                "[coverage-detail] signed_add_overflow=%0d sub_negative=%0d sub_equal=%0d mul_zero=%0d mul_identity=%0d mul_wrap=%0d mul_no_wrap=%0d pass_a=%0d",
                special_hits[0], special_hits[1], special_hits[2], special_hits[3],
                special_hits[4], special_hits[5], special_hits[6], special_hits[7]
            );
            $display("[coverage] TOTAL: %0d/%0d bins = %0d%%",
                     total_covered, total_bins, coverage_percent);

            if (op_covered != 4 || a_covered != 6 || b_covered != 6 ||
                cross_covered != 144 || relation_covered != 3 ||
                scenario_covered != ScenarioBinCount || residue_covered != 9 ||
                special_covered != 8) begin
                error_count++;
                $display("[coverage] FAIL: one or more required bins were not covered");
            end else begin
                $display("[coverage] PASS: all required functional bins were covered");
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin : test_sequence
        integer index;
        transaction_count = 0;
        checked_count = 0;
        error_count = 0;
        cycle_count = 0;
        valid_in = 1'b0;
        op_sel = OpAdd;
        a_bin = 16'd0;
        b_bin = 16'd0;
        program_load_valid = 1'b0;
        program_load_values = 128'd0;
        program_instruction_valid = 1'b0;
        program_instruction_op = OpAdd;
        program_destination = 3'd0;
        program_source_a = 3'd0;
        program_source_b = 3'd0;
        program_convert_valid = 1'b0;
        program_convert_source = 3'd0;
        reset_n = 1'b0;

        for (index = 0; index < 4; index++) op_hits[index] = 0;
        for (index = 0; index < 4; index++) begin
            op_checked[index] = 0;
            op_failed[index] = 0;
        end
        for (index = 0; index < OperandBinCount; index++) begin
            a_bin_hits[index] = 0;
            b_bin_hits[index] = 0;
        end
        for (index = 0; index < 3; index++) relation_hits[index] = 0;
        for (index = 0; index < ScenarioBinCount; index++) scenario_hits[index] = 0;
        for (index = 0; index < 9; index++) residue_edge_hits[index] = 0;
        for (index = 0; index < 8; index++) special_hits[index] = 0;
        for (integer op_i = 0; op_i < 4; op_i++)
            for (integer a_i = 0; a_i < OperandBinCount; a_i++)
                for (integer b_i = 0; b_i < OperandBinCount; b_i++)
                    op_a_b_cross[op_i][a_i][b_i] = 0;

        random_test_count = 100;
        if (!$value$plusargs("RANDOM_TESTS=%d", random_test_count))
            random_test_count = 100;

        seed = 32'h5eed1234;
        if (!$value$plusargs("SEED=%d", seed))
            seed = 32'h5eed1234;
        seed_dummy = $urandom(seed);
        chain_count = 0;
        chain_passed = 0;
        chain_failed = 0;
        program_count = 0;
        program_passed = 0;
        program_failed = 0;
        program_zero_length = 0;
        program_1_to_9 = 0;
        program_10_to_49 = 0;
        program_50_to_99 = 0;
        program_100 = 0;
        last_checked_id = 0;
        last_checked_failed = 0;
        last_checked_signed = 0;
        last_checked_r63 = 0;
        last_checked_r64 = 0;
        last_checked_r65 = 0;

        $display("[config] seed=%0d random_tests=%0d latency=%0d",
                 seed, random_test_count, DutLatency);
        $display("[timing] DUT clock period: 10 ns");
        $display("[timing] DUT transaction latency: %0d cycles = %0d ns",
                 DutLatency, DutLatency * 10);
        $display("[timing] DUT streaming throughput: up to 1 transaction/cycle");
        $display("[timing] golden model: combinational, zero simulated-time latency");

        repeat (4) @(negedge clk);
        reset_n = 1'b1;
        drive_idle(2);

        run_directed_edges();
        drive_idle(2);
        run_cross_coverage();
        drive_idle(3);
        run_constrained_random(random_test_count);
        drive_idle(DutLatency + 2);
        run_chained_sequences();
        drive_idle(DutLatency + 2);
        run_variable_length_programs();
        drive_idle(DutLatency + 2);
        run_parallel_input_program();
        drive_idle(DutLatency + 5);

        if (expected_bin_q.size() != 0) begin
            error_count++;
            $display("[scoreboard] FAIL: %0d expected transactions were not observed",
                     expected_bin_q.size());
        end

        report_coverage();

        if (error_count == 0) begin
            $display(
                "[scoreboard-summary] PASS: driven=%0d checked=%0d mismatches=0 pending=%0d",
                transaction_count, checked_count, expected_bin_q.size()
            );
            $display(
                "[scoreboard-summary] ADD: tested=%0d passed=%0d failed=%0d",
                op_checked[OpAdd], op_checked[OpAdd] - op_failed[OpAdd],
                op_failed[OpAdd]
            );
            $display(
                "[scoreboard-summary] SUBTRACT: tested=%0d passed=%0d failed=%0d",
                op_checked[OpSub], op_checked[OpSub] - op_failed[OpSub],
                op_failed[OpSub]
            );
            $display(
                "[scoreboard-summary] MULTIPLY: tested=%0d passed=%0d failed=%0d",
                op_checked[OpMul], op_checked[OpMul] - op_failed[OpMul],
                op_failed[OpMul]
            );
            $display(
                "[scoreboard-summary] PASS_A: tested=%0d passed=%0d failed=%0d",
                op_checked[OpPassA], op_checked[OpPassA] - op_failed[OpPassA],
                op_failed[OpPassA]
            );
            $display(
                "[scoreboard-summary] CHAINS (A+B)*C+D: tested=%0d passed=%0d failed=%0d",
                chain_count, chain_passed, chain_failed
            );
            $display(
                "[scoreboard-summary] PROGRAMS (0-100 ops): tested=%0d passed=%0d failed=%0d",
                program_count, program_passed, program_failed
            );
            $display(
                "[scoreboard-summary] PROGRAM LENGTHS: zero=%0d one_to_nine=%0d ten_to_49=%0d fifty_to_99=%0d hundred=%0d",
                program_zero_length, program_1_to_9, program_10_to_49,
                program_50_to_99, program_100
            );
            $display("[result] PASS: %0d/%0d transactions checked with no mismatches",
                     checked_count, transaction_count);
            $finish;
        end else begin
            $display(
                "[scoreboard-summary] FAIL: driven=%0d checked=%0d errors=%0d pending=%0d",
                transaction_count, checked_count, error_count, expected_bin_q.size()
            );
            $display("[scoreboard-summary] ADD: tested=%0d passed=%0d failed=%0d",
                     op_checked[OpAdd], op_checked[OpAdd] - op_failed[OpAdd],
                     op_failed[OpAdd]);
            $display("[scoreboard-summary] SUBTRACT: tested=%0d passed=%0d failed=%0d",
                     op_checked[OpSub], op_checked[OpSub] - op_failed[OpSub],
                     op_failed[OpSub]);
            $display("[scoreboard-summary] MULTIPLY: tested=%0d passed=%0d failed=%0d",
                     op_checked[OpMul], op_checked[OpMul] - op_failed[OpMul],
                     op_failed[OpMul]);
            $display("[scoreboard-summary] PASS_A: tested=%0d passed=%0d failed=%0d",
                     op_checked[OpPassA], op_checked[OpPassA] - op_failed[OpPassA],
                     op_failed[OpPassA]);
            $display(
                "[scoreboard-summary] CHAINS (A+B)*C+D: tested=%0d passed=%0d failed=%0d",
                chain_count, chain_passed, chain_failed
            );
            $display(
                "[scoreboard-summary] PROGRAMS (0-100 ops): tested=%0d passed=%0d failed=%0d",
                program_count, program_passed, program_failed
            );
            $display(
                "[scoreboard-summary] PROGRAM LENGTHS: zero=%0d one_to_nine=%0d ten_to_49=%0d fifty_to_99=%0d hundred=%0d",
                program_zero_length, program_1_to_9, program_10_to_49,
                program_50_to_99, program_100
            );
            $fatal(1, "[result] FAIL: errors=%0d checked=%0d driven=%0d",
                   error_count, checked_count, transaction_count);
        end
    end

    initial begin : monitor_and_scoreboard
        logic [17:0] expected_bin;
        logic signed [17:0] expected_signed;
        logic [5:0] expected_r63;
        logic [5:0] expected_r64;
        logic [6:0] expected_r65;
        logic [1:0] expected_op;
        logic signed [15:0] expected_a;
        logic signed [15:0] expected_b;
        integer expected_id;
        integer expected_cycle;

        forever begin
            @(posedge clk);
            #1;
            cycle_count++;

            if (!reset_n) begin
                if (valid_out !== 1'b0) begin
                    error_count++;
                    $display("[scoreboard] FAIL: valid_out asserted during reset");
                end
            end else if ((expected_cycle_q.size() > 0) &&
                         (expected_cycle_q[0] == cycle_count)) begin
                expected_bin = expected_bin_q.pop_front();
                expected_signed = expected_signed_q.pop_front();
                expected_r63 = expected_r63_q.pop_front();
                expected_r64 = expected_r64_q.pop_front();
                expected_r65 = expected_r65_q.pop_front();
                expected_op = expected_op_q.pop_front();
                expected_a = expected_a_q.pop_front();
                expected_b = expected_b_q.pop_front();
                expected_id = expected_id_q.pop_front();
                expected_cycle = expected_cycle_q.pop_front();
                checked_count++;
                op_checked[expected_op]++;
                last_checked_id = expected_id;
                last_checked_signed = y_signed;
                last_checked_r63 = y63;
                last_checked_r64 = y64;
                last_checked_r65 = y65;
                last_checked_failed = 0;

                if (valid_out !== 1'b1) begin
                    error_count++;
                    op_failed[expected_op]++;
                    last_checked_failed = 1;
                    $display("[scoreboard] FAIL id=%0d cycle=%0d: valid_out=0",
                             expected_id, expected_cycle);
                end else if ((y_bin !== expected_bin) ||
                             (y_signed !== expected_signed) ||
                             (y63 !== expected_r63) ||
                             (y64 !== expected_r64) ||
                             (y65 !== expected_r65)) begin
                    error_count++;
                    op_failed[expected_op]++;
                    last_checked_failed = 1;
                    $display(
                        "[scoreboard] FAIL id=%0d %0s a=%0d b=%0d got_signed=%0d got=(%0d,%0d,%0d,%0d) expected_signed=%0d expected=(%0d,%0d,%0d,%0d)",
                        expected_id, op_name(expected_op), expected_a, expected_b,
                        y_signed, y_bin, y63, y64, y65,
                        expected_signed, expected_bin,
                        expected_r63, expected_r64, expected_r65
                    );
                end else begin
                    $display("[check %0d] PASS id=%0d %0s signed=%0d canonical=%0d residues=(%0d,%0d,%0d)",
                             checked_count, expected_id, op_name(expected_op),
                             y_signed, y_bin, y63, y64, y65);
                end
            end else if (valid_out !== 1'b0) begin
                error_count++;
                $display("[scoreboard] FAIL cycle=%0d: unexpected valid_out", cycle_count);
            end
        end
    end

endmodule

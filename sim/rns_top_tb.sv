`timescale 1ns/1ps

module rns_top_tb;

    localparam int unsigned ModN = 262080;
    localparam int unsigned DutLatency = 4;
    localparam int unsigned OperandBinCount = 6;
    localparam int unsigned ScenarioBinCount = 10;

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
            total_bins = 4 + 6 + 6 + 144 + 3 + 10 + 9 + 8;
            coverage_percent = (100 * total_covered) / total_bins;

            $display("[coverage] operations: %0d/4 bins", op_covered);
            $display("[coverage] operand A categories: %0d/6 bins", a_covered);
            $display("[coverage] operand B categories: %0d/6 bins", b_covered);
            $display("[coverage] operation x A x B cross: %0d/144 bins", cross_covered);
            $display("[coverage] A/B relationships: %0d/3 bins", relation_covered);
            $display("[coverage] constraint scenarios: %0d/10 bins", scenario_covered);
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
                scenario_covered != 10 || residue_covered != 9 ||
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

        random_test_count = 500;
        if (!$value$plusargs("RANDOM_TESTS=%d", random_test_count))
            random_test_count = 500;

        seed = 32'h5eed1234;
        if (!$value$plusargs("SEED=%d", seed))
            seed = 32'h5eed1234;
        seed_dummy = $urandom(seed);

        $display("[config] seed=%0d random_tests=%0d latency=%0d",
                 seed, random_test_count, DutLatency);

        repeat (4) @(negedge clk);
        reset_n = 1'b1;
        drive_idle(2);

        run_directed_edges();
        drive_idle(2);
        run_cross_coverage();
        drive_idle(3);
        run_constrained_random(random_test_count);
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

                if (valid_out !== 1'b1) begin
                    error_count++;
                    op_failed[expected_op]++;
                    $display("[scoreboard] FAIL id=%0d cycle=%0d: valid_out=0",
                             expected_id, expected_cycle);
                end else if ((y_bin !== expected_bin) ||
                             (y_signed !== expected_signed) ||
                             (y63 !== expected_r63) ||
                             (y64 !== expected_r64) ||
                             (y65 !== expected_r65)) begin
                    error_count++;
                    op_failed[expected_op]++;
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

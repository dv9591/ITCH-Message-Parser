`timescale 1 ns / 1 ps
module bytereceiver_tb;
    // Signals
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [7:0] data_in = 8'h00;
    logic data_found = 1'b0;
    logic done;

    // Scoreboard
    integer done_count = 0;
    int fail_count = 0;
    int model_count = 0;

    receiver dut (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .data_found(data_found),
        .done(done)
    );
    // 10 ns clock period
    always #5 clk = ~clk;
    
    // Pulse counter
    always @(posedge clk) begin
        if (done) begin
            done_count = done_count + 1;
        end
    end
    
    task do_reset;
    begin
        @(negedge clk);
        reset = 1'b1;
        data_found = 1'b0;
        data_in = 8'h00;
        @(negedge clk);
        @(negedge clk);
        reset = 1'b0;
        done_count = 0;
        model_count = 0;
    end
    endtask

    task send_byte(input [7:0] b);
        begin
        @(negedge clk);
        data_in = b;
        data_found = 1'b1;
        @(negedge clk);
        data_found = 1'b0;
        end
    endtask

    task idle(input integer n);
    begin
        data_found = 1'b0;
        repeat (n) @(negedge clk);
    end
    endtask

    task automatic check(input string test_name, input int expected);
        repeat (2) @(negedge clk); // letting last transmission settle
        assert (done_count == expected)
        else begin
            $error("%s: expected %0d pulses, got %0d", test_name, expected, done_count);
            fail_count = fail_count + 1;
        end
    endtask

    // Behavioral reference model of what the detector should complete
    logic [7:0] prev_byte = 8'h00;
    always @(posedge clk) begin
        if (reset) begin
            prev_byte <= 8'h00;
            model_count <= 0;
        end else if (data_found) begin
            if (prev_byte == 8'hAA && data_in == 8'h55)
                model_count <= model_count + 1;
            prev_byte <= data_in;
        end
    end

    // Timeout in case of infinite loop
    initial begin
        #200000;
        $fatal(1, "TIMEOUT: simulation ran too long");
    end

    // Test cases
    initial begin
        $dumpfile("bytereceiver_tb.vcd");
        $dumpvars(0, bytereceiver_tb);
        $display("Running bytereceiver tests...");

        // Test 1: Good path
        do_reset;
        send_byte (8'hAA);
        send_byte (8'h55);
        check("AA 55 -> detects", 1);

        // Test 2: Overlapping match
        do_reset;
        send_byte (8'hAA);
        send_byte (8'hAA);
        send_byte (8'h55);
        check("AA AA 55 -> detects", 1);

        // Test 3: Junk byte interruption
        do_reset;
        send_byte (8'hAA);
        send_byte (8'h12);
        send_byte (8'h55);
        check("AA 12 55 -> no detection", 0);

        // Test 4: Correct bytes, wrong order
        do_reset;
        send_byte (8'hAA);
        send_byte (8'h55);
        send_byte (8'hAA);
        send_byte (8'h55);
        check("AA 55 AA 55 -> detects twice", 2);

        // Test 5: Gap in stream: data_found gates transitions
        do_reset;
        send_byte (8'hAA);
        idle(3);
        send_byte(8'h55);
        check("AA <gap> 55 -> detects", 1);

        // Test 6: Garbage while data_found low must be ignored
        do_reset;
        send_byte (8'hAA);
        data_in = 8'h12; // will change, but valid stays low
        idle(3);
        send_byte(8'h55);
        check("AA <junk, valid low> 55 -> detects", 1);

        // Test 7: Reset mid-sequence
        do_reset;
        send_byte (8'hAA);
        do_reset;
        send_byte (8'h55);
        check("AA <reset> 55 -> no detection", 0);

        // Test 8: Junk stream test that should not trigger
        do_reset;
        send_byte (8'h21);
        send_byte (8'h12);
        send_byte (8'h10);
        send_byte (8'h67);
        check("21 12 10 67 -> no detection", 0);

        // 0x55 from IDLE should not arm anything
        do_reset;
        send_byte (8'h55);
        send_byte (8'hAA);
        check("55 AA -> no detection", 0);

        // Re-arm after a match, with a trailing 0x55
        do_reset;
        send_byte (8'hAA);
        send_byte (8'h55);
        send_byte (8'h55);
        check("AA 55 55 -> detects once", 1);

        // Stress test using reference model
        do_reset;
        repeat (500) begin
            case ($urandom_range(0,3))
                0: send_byte(8'hAA);
                1: send_byte(8'h55);
                default: send_byte($urandom_range(0,255));
            endcase
        end
        repeat (2) @(negedge clk);
        assert (done_count == model_count)
        else $error("random stream: DUT %0d, model %0d", done_count, model_count);
        
        // Summary

        $display("----------------------------");
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        $display("----------------------------");

        $finish;
    end

endmodule

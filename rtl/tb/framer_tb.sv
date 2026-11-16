`timescale 1ns/1ps
`default_nettype none

module framer_tb;
    
    parameter string VEC = "random_100";
    parameter int STREAM_BYTES = 3262;
    parameter int MSG_COUNT = 100;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic data_valid = 1'b0;
    logic [7:0] data_in = 8'h00;

    logic body_valid, msg_start, msg_last;
    logic [7:0] body_data;

    int msg_last_count = 0;
    int msg_start_count = 0;
    int body_byte_count = 0;

    logic [7:0] stream [0:STREAM_BYTES-1];

    framer dut (
        .clk(clk),
        .reset(reset),
        .data_valid(data_valid),
        .data_in(data_in),
        .body_valid(body_valid),
        .body_data(body_data),
        .msg_start(msg_start),
        .msg_last(msg_last)
    );

    always #5 clk = ~clk;

    // score
    always @(posedge clk) begin
        if (msg_last) msg_last_count++;
        if (msg_start) msg_start_count++;
        if (body_valid) body_byte_count++;
    end

    task automatic do_reset;
        begin
            @(negedge clk);
            reset = 1'b1;
            data_valid = 1'b0;
            data_in = 8'h00;
            @(negedge clk);
            @(negedge clk);
            reset = 1'b0;
            msg_last_count = 0;
            msg_start_count = 0;
            body_byte_count = 0;
        end
    endtask

    task automatic send_byte(input [7:0] b);
        begin
            @(negedge clk);
            data_valid = 1'b1;
            data_in = b;
            @(negedge clk);
            data_valid = 1'b0;
        end
    endtask

    task automatic send_byte_stalled(input logic [7:0] b);
        begin
            repeat ($urandom_range(0,3)) @(negedge clk);
            @(negedge clk);
            data_valid = 1'b1;
            data_in = b;
            @(negedge clk);
            data_valid = 1'b0;
        end
    endtask

    initial begin
        #500000;
        $fatal(1, "TIMEOUT");
    end

    initial begin
        $dumpfile("framer_tb.vcd");
        $dumpvars(0, framer_tb);
        $readmemh({"vectors/", VEC, ".hex"} stream);

        do_reset;

        for (int i = 0; i < STREAM_BYTES; i++) begin
            send_byte(stream[i]);
        end

        repeat (4) @(negedge clk);

        if (msg_last_count !== MSG_COUNT) begin
            $display("Expected %0d msg_last pulses, got %0d", 
            MSG_COUNT, msg_last_count);
            $fatal;
        end
        if (msg_start_count !== MSG_COUNT) begin
            $display("Expected %0d msg_start pulses, got %0d", 
            MSG_COUNT, msg_start_count);
            $fatal;
        end
        if (body_byte_count !== STREAM_BYTES - 2*MSG_COUNT) begin
            $display("Expected %0d body_valid pulses, got %0d", STREAM_BYTES - 2*MSG_COUNT, body_byte_count);
            $fatal;
        end
        
        $display("framer: %0d messages, %0d body bytes", msg_last_count, body_byte_count);
        $finish;
    end
endmodule
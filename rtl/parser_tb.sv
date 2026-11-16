`timescale 1ns/1ps
`default_nettype none

module parser_tb;
    
    parameter string VEC = "random_100";
    parameter int STREAM_BYTES = 3262;
    parameter int MSG_COUNT = 100;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic data_valid = 1'b0;
    logic [7:0] data_in = 8'h00;

    // connection between framer and parser
    logic body_valid, msg_start, msg_last;
    logic [7:0] body_data;

    // parser outputs
    logic msg_out_valid;
    logic [7:0] msg_out_type;
    logic [63:0] order_ref;
    logic side;
    logic [31:0] shares, price;

    // latency variables
    int last_byte_time;
    int latency_cycles;
    int latency_min = 999, latency_max = 0, latency_sum = 0, latency_n = 0;
    int cycles_per_message;

    // throughput variables
    int t_start, t_end;
    framer u_framer (
        .clk(clk),
        .reset(reset),
        .data_valid(data_valid),
        .data_in(data_in),
        .body_valid(body_valid),
        .body_data(body_data),
        .msg_start(msg_start),
        .msg_last(msg_last)
    );

    parser u_parser (
        .clk(clk),
        .reset(reset),
        .body_valid(body_valid),
        .body_data(body_data),
        .msg_start(msg_start),
        .msg_last(msg_last),
        .msg_out_valid(msg_out_valid),
        .msg_out_type(msg_out_type),
        .order_ref(order_ref),
        .side(side),
        .shares(shares),
        .price(price)
    );

    always #5 clk = ~clk;

    int out_count = 0;
    logic [7:0] expected_type [0:MSG_COUNT-1];
    logic [7:0] stream [0:STREAM_BYTES-1];
    logic [63:0] expected_ref [0:MSG_COUNT-1];
    logic expected_side [0:MSG_COUNT-1];
    logic [31:0] expected_shares [0:MSG_COUNT-1];
    logic [31:0] expected_price [0:MSG_COUNT-1];

    always @(posedge clk) begin
        if (msg_out_valid) begin
            if (msg_out_type !== expected_type[out_count]) begin
                $display("msg %0d: expected type %02h, got %02h", out_count, expected_type[out_count], msg_out_type);
                $fatal;
            end
            if (order_ref !== expected_ref[out_count]) begin
                $display("msg %0d: expected order_ref %016h, got %016h", out_count, expected_ref[out_count], order_ref);
                $fatal;
            end
            if (side !== expected_side[out_count]) begin
                $display("msg %0d: expected side %0b, got %0b", out_count, expected_side[out_count], side);
                $fatal;
            end
            if (shares !== expected_shares[out_count]) begin
                $display("msg %0d: expected shares %08h, got %08h", out_count, expected_shares[out_count], shares);
                $fatal;
            end
            if (price !== expected_price [out_count]) begin
                $display("msg %0d: expected price %08h, got %08h", out_count, expected_price[out_count], price);
                $fatal;
            end
            out_count = out_count + 1;
        end
    end

    always @(posedge clk) begin
        if (msg_last) begin
            last_byte_time = $time / 10;     // due to 10ns clock period
        end 
        if (msg_out_valid) begin
            latency_cycles = ($time / 10) - last_byte_time;
            if (latency_cycles < latency_min) latency_min = latency_cycles;
            if (latency_cycles > latency_max) latency_max = latency_cycles;
            latency_sum = latency_sum + latency_cycles;
            latency_n = latency_n + 1;
        end
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
            out_count = 0;
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
        #(STREAM_BYTES * 500);
        $fatal(1, "TIMEOUT");
    end

    initial begin
        $dumpfile("parser_tb.vcd");
        $dumpvars(0, parser_tb);
        $readmemh({"vectors/", VEC, ".hex"}, stream);
        $readmemh({"vectors/", VEC, ".types.hex"}, expected_type);
        $readmemh({"vectors/", VEC, ".ref.hex"}, expected_ref); 
        $readmemh({"vectors/", VEC, ".side.hex"}, expected_side);
        $readmemh({"vectors/", VEC, ".shares.hex"}, expected_shares);
        $readmemh({"vectors/", VEC, ".price.hex"}, expected_price);

        do_reset;

        t_start = $time / 10;
        for (int i = 0; i < STREAM_BYTES; i++) begin
            send_byte(stream[i]);
        end
        repeat (4) @(negedge clk);
        t_end = $time / 10;
        
        if (out_count != MSG_COUNT) begin
            $display("expected %0d messages out, got %0d", MSG_COUNT, out_count);
            $fatal;
        end

        $display("parser: %0d messages decoded", out_count);

        // clean pass latency numbers:
        $display("vectors counted for latency numbers: %0d", latency_n);
        $display("latency: min=%0d, max=%0d, avg=%.2f", latency_min, latency_max, latency_sum / real'(latency_n));

        $display("cycles per message: %.2f", real'(t_end - t_start) / (STREAM_BYTES));
        

        do_reset;
        for (int i = 0; i < STREAM_BYTES; i++) send_byte_stalled(stream[i]);
        repeat (4) @(negedge clk);

        if (out_count != MSG_COUNT) begin
            $display("stalled run: got %0d", out_count);
            $fatal;
        end

        $display("parser: %0d messages decoded (stalled run)", out_count);

        $finish;
    end
endmodule


    
    

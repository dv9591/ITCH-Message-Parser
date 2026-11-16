`timescale 1ns/1ps
`default_nettype none

module parser_edge_tb;
    
    parameter string VEC = "random_100";
    parameter int STREAM_BYTES = 188;
    parameter int MSG_COUNT = 4;

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
            out_count = out_count + 1;
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
        $dumpvars(0, parser_edge_tb);
        $readmemh({"vectors/", VEC, ".hex"}, stream);
        $readmemh({"vectors/", VEC, ".types.hex"}, expected_type);
        $readmemh({"vectors/", VEC, ".ref.hex"}, expected_ref); 

        do_reset;

        for (int i = 0; i < STREAM_BYTES; i++) begin
            send_byte(stream[i]);
        end

        repeat (4) @(negedge clk);

        if (out_count != MSG_COUNT) begin
            $display("expected %0d messages out, got %0d", MSG_COUNT, out_count);
            $fatal;
        end

        $display("parser: %0d messages decoded", out_count);

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


    
    

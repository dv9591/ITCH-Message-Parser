`timescale 1ns / 1ps
module counter_tb;

    reg clk = 0;
    reg reset = 0;
    reg load = 0;
    reg [7:0] data_in = 0;
    wire [7:0] count;
    wire done;

    counter dut ( 
        .clk(clk),
        .reset(reset),
        .load(load),
        .data_in(data_in),
        .count(count),
        .done(done)
    );

    always #5 clk = ~clk; // Generates clock: 10ns period

    initial begin
        $dumpfile("counter_tb.vcd");
        $dumpvars(0, counter_tb);
        $monitor("t=%0t  count=%3d  done=%b", $time, count, done);

        // Test case: resetting counter

        reset = 1; #20;
        reset = 0; #10;

        data_in = 8'd5; 
        load = 1; #10;
        load = 0;

        #200;
        $finish;
    end
endmodule

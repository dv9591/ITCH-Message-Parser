module counter ( 
    input clk,
    input reset,
    input load,
    input [7:0] data_in,
    output reg [7:0] count,
    output reg done
);
    // Begins counter logic
    always @(posedge clk) begin
        if (reset) begin
            count <= 8'b00000000; // Resets counter to 0
            done <= 1'b0; // Resets done signal
        end else if (load) begin
            count <= data_in;
            done <= 1'b0; // Resets done signal when loading new data
        end else if (count != 8'd0)begin
            count <= count - 8'd1; // Loads data_in and decrements by 1
            done <= (count == 8'd1); // Ensures that next cycle count is 0
        end
        else begin
            done <= 1'b1; // Sets done signal when count reaches 0
        end
    end
endmodule

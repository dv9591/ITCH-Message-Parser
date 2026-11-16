`timescale 1ns/1ps
`default_nettype none

module framer (
    input wire clk,
    input wire reset,
    input wire data_valid,
    input wire [7:0] data_in,
    output logic body_valid,
    output logic [7:0] body_data,
    output logic msg_start,
    output logic msg_last
);

typedef enum logic [1:0] {
    IDLE = 2'b00,
    LEN_LO = 2'b01,
    BODY = 2'b10
} state_t;

state_t state, next_state;

logic [7:0] length_hi;
logic [15:0] bytes_left;
logic first_body_byte;
logic [15:0] length_full;
logic length_is_zero;

assign length_full = {length_hi, data_in};
assign length_is_zero = (length_full == 16'b0);

// next-state logic
always_comb begin
    next_state = state;
    case (state)
        IDLE: if (data_valid) next_state = LEN_LO;
        LEN_LO: if (data_valid) begin 
            if (length_is_zero) begin
                next_state = IDLE;
            end
            else begin
                next_state = BODY;
            end
        end
        BODY: if (data_valid && (bytes_left == 16'd1)) next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// datapath registers
always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        length_hi <= 8'b0;
        bytes_left <= 16'b0;
        first_body_byte <= 1'b0;
    end
    else begin
        state <= next_state;
        if (data_valid) begin
            if (state == IDLE) begin
                length_hi <= data_in;
            end
            else if (state == LEN_LO) begin
                if (!length_is_zero) begin
                    bytes_left <= length_full;
                    first_body_byte <= 1'b1;
                end
            end
            else if (state == BODY) begin
                bytes_left <= bytes_left - 1;
                first_body_byte <= 1'b0;
            end
        end
    end
end
// outputs  
assign body_valid = (state == BODY) && data_valid;
assign body_data = data_in;
assign msg_start = first_body_byte && body_valid;
assign msg_last = (bytes_left == 16'd1) && (state == BODY) && data_valid;

endmodule
module receiver (
    input logic clk,
    input logic reset,
    input logic [7:0] data_in,
    input logic data_found,
    output logic done
);

typedef enum logic [1:0] {
    IDLE,
    AA_FOUND,
    DONE
} state_t;
state_t state, next_state;

always_comb begin
    next_state = state;
    case (state)
        IDLE: begin
            if (data_found && data_in == 8'hAA) 
                next_state = AA_FOUND;
        end
        AA_FOUND: begin
            if (data_found) begin
                if (data_in == 8'hAA) begin
                    next_state = AA_FOUND;
                end else if (data_in == 8'h55) begin
                    next_state = DONE;
                end else begin
                    next_state = IDLE;
                end
            end
        end
        DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

assign done = (state == DONE);


endmodule
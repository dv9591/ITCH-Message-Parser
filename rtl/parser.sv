`timescale 1ns/1ps
`default_nettype none

module parser (
    input wire clk,
    input wire reset,
    input wire body_valid,
    input wire [7:0] body_data,
    input wire msg_start,
    input wire msg_last,
    output logic msg_out_valid,
    output logic [7:0] msg_out_type,
    output logic [63:0] order_ref,
    output logic side,
    output logic [31:0] shares,
    output logic [31:0] price
);

logic [7:0] byte_idx;
logic [7:0] msg_type;
logic type_recognized;
logic skipping;

// Only valid on msg_start, otherwise don't care
assign type_recognized = (body_data == 8'h41) || (body_data == 8'h44) || (body_data == 8'h45);

always_ff @(posedge clk) begin
    if (reset) begin
        byte_idx <= 8'b0;
        msg_out_valid <= 1'b0;
        msg_out_type <= 8'b0;
        order_ref <= 64'b0;
        side <= 1'b0;
        shares <= 32'b0;
        price <= 32'b0;
        skipping <= 1'b0;
        msg_type <= 8'b0;
    end
    else begin
        msg_out_valid <= 1'b0;
        
        if (body_valid) begin
            if (msg_start) begin
                byte_idx <= 8'b1;
                msg_type <= body_data;
                skipping <= (!type_recognized);
                side <= 1'b0;
                shares <= 32'b0;
                price <= 32'b0;
            end else begin
                byte_idx <= byte_idx + 1;
                if (!skipping) begin
                    case (byte_idx)
                        8'd11, 8'd12, 8'd13, 8'd14, 8'd15, 8'd16, 8'd17, 8'd18: order_ref <= {order_ref[55:0], body_data};
                        8'd19: begin
                            case(msg_type) 
                                8'h41: side <= (body_data == 8'h42) ? 1'b0: 1'b1;
                                8'h45: shares <= {shares[23:0], body_data};
                            endcase
                        end
                        8'd20, 8'd21, 8'd22: begin
                            case(msg_type)
                                8'h41: shares <= {shares[23:0], body_data};
                                8'h45: shares <= {shares[23:0], body_data};
                            endcase
                        end
                        8'd23: begin
                            case(msg_type)
                                8'h41: shares <= {shares[23:0], body_data};
                            endcase
                        end
                        8'd32, 8'd33, 8'd34, 8'd35: begin
                            case(msg_type)
                                8'h41: price <= {price[23:0], body_data};
                            endcase
                        end
                    endcase
                end
            end
            if (msg_last) begin
                msg_out_valid <= !skipping;
                msg_out_type <= msg_type;
                skipping <= 1'b0;
            end
        end
    end
end

endmodule


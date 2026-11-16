`timescale 1ns / 1ps
`default_nettype none

module top (
    input wire clk,
    input wire reset,
    input wire data_valid,
    input wire [7:0] data_in,
    output logic msg_out_valid,
    output logic [7:0] msg_out_type,
    output logic [63:0] order_ref,
    output logic side,
    output logic [31:0] shares,
    output logic [31:0] price
);

logic body_valid, msg_start, msg_last;
logic [7:0] body_data;

framer u_framer (.*);
parser u_parser (.*);

endmodule
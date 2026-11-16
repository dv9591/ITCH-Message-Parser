#!/bin/bash
set -e
N=$1
iverilog -g2012 -Wall -o parser_tb.vvp \
    -P"parser_tb.VEC=\"random_${N}\"" \
    -Pparser_tb.STREAM_BYTES=$(awk 'END{print NR}' vectors/random_${N}.hex) \
    -Pparser_tb.MSG_COUNT=$N \
    rtl/framer.sv rtl/parser.sv rtl/parser_tb.sv
vvp parser_tb.vvp
# ITCH-Lite Message Parser

A streaming hardware feed handler in SystemVerilog. It ingests a binary exchange
protocol byte-by-byte, frames messages from a length prefix, and decodes order
fields with **1-cycle deterministic latency at 285 MHz** on a Xilinx Artix-7.

| | |
|---|---|
| **Fmax** | 285 MHz (post-implementation, Artix-7 `xc7a35ti`) |
| **Latency** | 1 cycle, last byte in → fields out, no jitter |
| **Throughput** | 1 byte/cycle → ~8.4M messages/sec |
| **Area** | 69 LUTs, 263 FFs, 0 BRAM |
| **Verification** | 10,000 random messages + directed edge cases, checked against an independent Python model |

Full measurements, the timing sweep, and the verification methodology are in
[`docs/results.md`](docs/results.md).

---

## What it does

The design implements a subset of **Nasdaq TotalView-ITCH 5.0** — a binary market-data
protocol in which every message is a fixed-length record behind a 2-byte big-endian
length prefix. Three message types are decoded: Add Order (`A`), Order Executed (`E`),
and Order Delete (`D`), which together cover the full lifecycle of a resting order.
All other types are consumed and discarded using the length prefix.

## Architecture

```
byte stream ──▶ [ framer ] ──▶ body bytes ──▶ [ parser ] ──▶ decoded fields
                                              msg_start/last
```

**`framer.sv`** owns message boundaries and nothing else. A three-state machine reads
the 2-byte length prefix, loads a countdown, and asserts `msg_last` on the final body
byte. It never inspects message contents, so it stays correct as message types are
added. A zero-length frame is discarded rather than entering the body state, which
would otherwise wrap the counter and desynchronize the stream.

**`parser.sv`** owns field extraction. It latches the message type on `msg_start`, then
uses a byte-position counter to select which register each arriving byte belongs to.
Fields are accumulated with a shift-and-append — `shares <= {shares[23:0], body_data}`
— so big-endian decoding falls out of arrival order for free, with no byte-swapping
logic. Notably the parser has **no state machine**: byte position and message type are
already in registers, so an FSM would only duplicate information that exists, and
introduce a second thing to keep in sync.

Both modules gate every state change on a `valid` signal, so an upstream producer can
stall at any point without the design losing sync. This is tested, not assumed.

## Deliberate simplifications

Scoped choices, each made for a reason rather than skipped:

- **Three message types.** Add / Execute / Delete is the minimal set covering an order's
  lifecycle. Order Replace (`U`) carries two order reference numbers and is more
  naturally handled as a delete-plus-add pair.
- **Four fields extracted** of eight present. `stock_locate`, `tracking_number`,
  `timestamp`, and `stock` are consumed but not registered — they do not affect
  top-of-book, and storing them would cost flip-flops for nothing.
- **No order book.** This decodes messages; it does not maintain book state. The order
  table and BBO tracker are the natural next stage.

## Repository layout

```
rtl/                SystemVerilog sources
  framer.sv           message framing from length prefix
  parser.sv           field extraction
  top.sv              synthesis wrapper
  constraints.xdc     clock constraint
  parser_tb.sv        integration testbench (framer + parser)
  parser_edge_tb.sv   directed edge-case testbench
  tb/framer_tb.sv     framer-only testbench
model/              Python reference model
  messages.py         ITCH message definitions
  encode.py           message object → bytes
  decode.py           bytes → message object
  generate.py         random stream + expected-value generation
  test_*.py           pytest suite
vectors/            generated test vectors and golden outputs
docs/results.md     synthesis, timing, and verification results
run.sh              simulate one vector size
```

## Running it

Requires Icarus Verilog 11+ and Python 3.12+.

```bash
python3 -m model.generate      # regenerate vectors and expected values
pytest model/                  # Python reference model tests
./run.sh 100                   # simulate (also: 1000, 10000)
```

The edge-case vector uses a separate testbench:

```bash
iverilog -g2012 -Wall -o parser_edge_tb.vvp \
    -P'parser_edge_tb.VEC="edge"' \
    -Pparser_edge_tb.STREAM_BYTES=188 \
    -Pparser_edge_tb.MSG_COUNT=4 \
    rtl/framer.sv rtl/parser.sv rtl/parser_edge_tb.sv
vvp parser_edge_tb.vvp
```

For synthesis: create a Vivado RTL project targeting `xc7a35ticsg324-1L`, add
`rtl/framer.sv`, `rtl/parser.sv`, `rtl/top.sv` and `rtl/constraints.xdc`, then run
synthesis followed by implementation. Post-synthesis timing is optimistic — read the
numbers from the implemented design.

## How it is verified

Expected values come from an **independently written Python implementation**, not from
reading the RTL back to itself. The encoder and decoder are validated against each
other by a round-trip property test, and one message was checked byte-by-byte against
the Nasdaq specification by hand to anchor the model to the actual protocol.

Every generated message is compared on all five output fields, across three vector
sizes, each run twice — once clean and once with randomly injected backpressure.
Directed vectors then cover what random generation cannot produce: unknown message
types and malformed zero-length frames, each followed by a valid message so the test
checks **resynchronization** rather than merely absence of a crash.

Two findings from that process are written up in `docs/results.md`: a directed vector
caught a real bug that 10,000 random messages could not, and the suite's original
SystemVerilog immediate assertions turned out not to execute under this Icarus build —
passing silently without performing a single comparison. Every check was rebuilt and
each one verified to fail when fed a deliberately corrupted expected value.

## Next

- Order table in block RAM, with a BBO tracker
- Order Replace (`U`)
- Wider datapath — the design is byte-rate limited, so 8 or 16 bytes per cycle is the
  path to an order-of-magnitude throughput increase, not a faster clock
- Deployment on hardware

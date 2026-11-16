# Results

Synthesis, timing, and verification results for the ITCH-lite message parser.

**Target device:** AMD/Xilinx Artix-7 `xc7a35ticsg324-1L` (Arty A7-35T)
**Toolchain:** Icarus Verilog 13.0 (simulation), Vivado (synthesis and implementation)
**Measured:** November 2026

---

## Summary

| Metric | Value |
|---|---|
| Maximum frequency (Fmax) | **285 MHz** |
| Output latency | **1 cycle** from last byte in to `msg_out_valid` (deterministic) |
| Throughput | 1 byte/cycle → ~34 cycles per 34-byte framed message |
| Sustained message rate | **~8.4M messages/sec** at 285 MHz |
| Slice LUTs | 69 (0.33% of device) |
| Slice registers | 263 (0.63% of device) |
| Block RAM | 0 |
| Inferred latches | 0 |

All figures are post-implementation (place-and-route), not post-synthesis estimates.

---

## Timing

Fmax was found by sweeping the clock constraint until timing failed, rather than
reporting the slack from a single arbitrary target. The tool optimizes to whatever
constraint it is given, so a loose constraint under-reports the achievable frequency.

| Constraint | Period | WNS | Result | Implied Fmax |
|---|---|---|---|---|
| 200 MHz | 5.000 ns | +0.780 ns | met | 237 MHz |
| 250 MHz | 4.000 ns | +0.492 ns | **met** | **285 MHz** |
| 285 MHz | 3.500 ns | −0.048 ns | failed (1 of 584 endpoints) | — |

The 4.000 ns run is the reported result. The 3.500 ns run failed by 48 ps on a single
endpoint, placing the true ceiling at ~282 MHz — within 1% of the 4.000 ns figure,
which confirms the sweep converged rather than stopping arbitrarily.

Hold timing was met at every constraint (WHS +0.122 ns at 4.000 ns), with no
failing endpoints.

### Critical paths

The critical path changed at each constraint, which is the most informative result
in this table:

| Constraint | Path | Delay | Logic / Route | Levels |
|---|---|---|---|---|
| 5.000 ns | `framer.first_body_byte` → `parser.shares[18]` | 3.438 ns | 18% / 82% | 1 |
| 4.000 ns | `parser.msg_type[6]` → `parser.shares[22]/CE` | 3.169 ns | 26% / 74% | 3 |
| 3.500 ns | `framer.bytes_left[3]` → `parser.msg_out_valid/R` | 3.043 ns | 29% / 71% | 3 |

Three different paths within ~400 ps of each other means **the design has no single
dominant bottleneck** — it is roughly balanced. There is no one register to pipeline
for an easy win.

Routing delay dominates in every case (71–82%). At 0.33% device utilization the
design is spread across a largely empty die, so wire delay between placed registers
outweighs the logic itself. On a fuller device, or with floorplanning constraints,
these paths would likely shorten.

---

## Resource utilization

| Resource | Used | Available | Utilization |
|---|---|---|---|
| Slice LUTs | 69 | 20,800 | 0.33% |
| Slice registers (FF) | 263 | 41,600 | 0.63% |
| LUT as memory | 0 | 9,600 | 0.00% |
| Register as latch | 0 | 41,600 | 0.00% |
| Block RAM | 0 | 50 | 0.00% |
| DSP | 0 | 90 | 0.00% |

The design is **register-dominated**: 263 flip-flops against 69 LUTs, a ratio of
roughly 4:1. This reflects what the parser does — it accumulates bytes into wide
field registers rather than computing on them. The largest contributors are
`order_ref` (64 bits), `shares` and `price` (32 bits each), and the framer's
`bytes_left` counter (16 bits).

**Zero inferred latches** confirms that `always_comb` and `always_ff` were used
correctly throughout; an accidental latch is the most common silent RTL bug and the
report rules it out.

LUT count rose from 60 to 72 across the constraint sweep as the tool duplicated
registers to reduce fanout — a standard timing optimization, visible in the 5.000 ns
critical path endpoint named `shares_reg[18]_lopt_replica`.

---

## Latency

Measured in simulation as the number of cycles from `msg_last` (the final byte of a
message entering the framer) to `msg_out_valid` asserting.

| Statistic | Cycles |
|---|---|
| Minimum | 1 |
| Maximum | 1 |
| Mean | 1.00 |
| Samples | 100 |

Minimum equal to maximum means latency is **deterministic** — it does not vary with
message type, field values, or position in the stream. For a market-data path,
predictable latency is often worth more than a lower average, since jitter
propagates into downstream decision timing.

Latency was measured on the unstalled run. Under randomly injected backpressure
(0–3 idle cycles per byte) the figure was unchanged, confirming that producer stalls
contribute to end-to-end delay but not to the design's own contribution.

---

## Throughput

The datapath accepts **one byte per clock cycle**. Framed message sizes are:

| Message type | Body | Framed (incl. 2-byte prefix) |
|---|---|---|
| Add Order (`A`) | 36 B | 38 B |
| Order Executed (`E`) | 31 B | 33 B |
| Order Delete (`D`) | 19 B | 21 B |

At an average of ~34 framed bytes per message, sustained throughput is ~34 cycles
per message, giving **~8.4M messages/sec at 285 MHz**.

### Known limitation

This design is **byte-rate limited, not logic limited**. The 1-cycle latency and the
285 MHz Fmax are both comfortably better than the rate at which bytes can enter the
pipeline. A production feed handler widens the datapath — processing 8 or 16 bytes
per cycle — so that a message is consumed in a handful of cycles rather than 34.
That restructuring, not a faster clock, is the path to an order-of-magnitude
throughput increase.

---

## Verification

All results below use `if`/`$display`/`$fatal` comparisons rather than SystemVerilog
immediate assertions. During development, `assert ... else $error(...)` was found not
to execute under this Icarus build, causing an entire suite to pass silently without
performing a single comparison. Every check in the current suite has been verified to
fail when fed a deliberately corrupted expected value.

### Reference model

Expected values are produced by an independent Python implementation
(`model/encode.py`, `model/decode.py`) written separately from the RTL. Encoder and
decoder are validated against each other by a round-trip property test
(`decode(encode(msg)) == msg`), and one message was verified byte-by-byte against the
Nasdaq TotalView-ITCH 5.0 specification by hand to anchor the model to the actual
protocol.

### Random vectors

Seeded pseudo-random message streams, each run twice — once clean, once with 0–3
randomly injected idle cycles per byte:

| Vector | Messages | Bytes | Result |
|---|---|---|---|
| `random_100` | 100 | 3,262 | pass |
| `random_1000` | 1,000 | 32,107 | pass |
| `random_10000` | 10,000 | 323,457 | pass |

Every message is checked on all five output fields: `msg_out_type`, `order_ref`,
`side`, `shares`, `price`.

Streams are semantically coherent as well as structurally valid — executes and
deletes only reference order IDs that were previously added.

### Directed edge cases

Random generation cannot produce malformed or unhandled input, so these paths are
covered by a hand-built vector (`vectors/edge.hex`):

| Case | Expectation | Result |
|---|---|---|
| Unknown message type (`P`, 44 B) | consumed, no output emitted | pass |
| Unknown message type (`Q`, 20 B) | consumed, no output emitted | pass |
| Zero-length frame | discarded, no output emitted | pass |
| Valid message after each of the above | decodes correctly, stream stays in sync | pass |

Every malformed frame in this vector is followed by a valid message, so the test
checks **resynchronization**, not merely absence of a crash. A single byte lost on a
discarded frame would corrupt the next length prefix and desynchronize everything
after it.

This vector found a real bug: `msg_out_valid` was asserted for unrecognized message
types because the skip flag gated field extraction but not the output pulse. The
10,000-message random suite could not have caught it, since the generator emits only
recognized types.

### Framer-level checks

| Check | Expectation |
|---|---|
| `msg_last` pulse count | equals message count |
| `msg_start` pulse count | equals message count |
| `body_valid` byte count | equals total bytes − 2 per message |

The third is the sharpest: it confirms the two length-prefix bytes per message are
consumed and not forwarded, which a message count alone would not detect.

---

## Reproducing these results

```bash
python3 -m model.generate              # regenerate vectors and expected values
./run.sh 100                           # simulate (also: 1000, 10000)
```

Vivado: create an RTL project targeting `xc7a35ticsg324-1L`, add `rtl/framer.sv`,
`rtl/parser.sv`, and `rtl/top.sv`, and a constraints file containing:

```tcl
create_clock -period 4.000 -name clk [get_ports clk]
```

Run synthesis followed by implementation; read WNS from Report Timing Summary and
resource counts from Report Utilization. Post-synthesis timing is optimistic and
should not be reported.

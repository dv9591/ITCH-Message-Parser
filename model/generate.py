import random
import struct
from model.messages import AddOrder, OrderExecuted, OrderDelete, Side
from model.encode import encode, frame

def random_message(rng: random.Random, order_refs: list):
    """Pick a random message type and fill it with plausible values."""
    kind = rng.choice(['A', 'A', 'E', 'D']) # bias towards add orders

    timestamp = rng.randrange(0, 86_400_000_000_000)
    stock_locate = rng.randrange(1,100)

    if kind == 'A' or not order_refs:
        ref = rng.randrange(1, 2**32)
        order_refs.append(ref)
        return AddOrder(
            stock_locate, 0, timestamp, ref,
            rng.choice([Side.BUY, Side.SELL]),
            rng.randrange(1, 10_000),
            'AAPL',
            rng.randrange(1_0000, 1000_0000),
        )

    ref = rng.choice(order_refs)
    if kind == 'E':
        return OrderExecuted(
            stock_locate, 0, timestamp, ref,
            rng.randrange(1, 10_000), rng.randrange(1, 2**32)
        )
    order_refs.remove(ref)
    return OrderDelete(
        stock_locate, 0, timestamp, ref
    )

def generate(n: int, seed: int = 42):
    rng = random.Random(seed)
    order_refs = []
    return [random_message(rng, order_refs) for _ in range(n)]

def side_of(m):
    if isinstance(m, AddOrder):
        return 0 if m.buy_sell_indicator == Side.BUY else 1
    return 0

def shares_of(m):
    if isinstance(m, AddOrder):
        return m.shares
    if isinstance(m, OrderExecuted):
        return m.executed_shares
    return 0

def price_of(m):
    return m.price if isinstance(m, AddOrder) else 0

def write_edge_case_vector():
    """Manually built stream exercising the skip path and the zero-length guard"""
    parts = []
    expected = [] #(type, order_ref) for any messages that should come out

    def add(msg):
        parts.append(frame(msg))
        expected.append((ord(msg.MSG_TYPE), msg.order_ref_num))

    def add_raw(body: bytes):
        """Frame arbitrary bytes - used for unknown types"""
        parts.append(struct.pack('>H', len(body)) + body)
    # Building the edge case vectors:

    # 1. Normal message, to know to start synced
    add(AddOrder(1, 0, 1000, 111, Side.BUY, 100, 'AAPL', 1234500))

    # 2. An unknown type 'P' (trade message) - expected to be skipped
    add_raw(b'P' + bytes(43))

    # 3. Normal message after skip to prove the parser resyncs
    add(OrderDelete(1, 0, 2000, 111))

    # 4. Zero-length frame - should be distracted by the guard
    parts.append(struct.pack('>H', 0))

    # 5. Normal message after zero-length guard to prove parser recovers
    add(AddOrder(1, 0, 3000, 222, Side.SELL, 50, 'AAPL', 999900))

    # 6. Another unknown type, with a different length
    add_raw(b'Q' + bytes(19))

    # 7. Final normal message
    add(OrderDelete(1, 0, 4000, 222))

    stream = b"".join(parts)
    # write the stream to vectors/edge.hex, expected to be vectors/edge.types.hex and vectors/edge.ref.hex
    with open("vectors/edge.hex", "w") as f:
        for byte in stream:
            f.write(f"{byte:02x}\n")
    with open("vectors/edge.types.hex", "w") as f:
        for t, _ in expected:
            f.write(f"{t:02x}\n")
    with open ("vectors/edge.ref.hex", "w") as f:
        for _, ref in expected:
            f.write(f"{ref:016x}\n")
    print(f"edge: {len(expected)} messages expected, len{(stream)} bytes")

if __name__ == '__main__':
    import csv, pathlib

    pathlib.Path("vectors").mkdir(exist_ok=True)
    for n in (100,1000,10000):
        msgs = generate(n)

        with open(f"vectors/random_{n}.bin", "wb") as f:
            for m in msgs:
                f.write(frame(m))

        with open(f"vectors/random_{n}.golden.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["index", "offset", "msg_type", "order_ref", "side", "shares", "price"])
            offset = 0
            for i, m in enumerate(msgs):
                if isinstance(m, AddOrder):
                    w.writerow([i, offset, 0x41, m.order_ref_num,
                                0 if m.buy_sell_indicator == Side.BUY else 1,
                                m.shares, m.price])
                elif isinstance(m, OrderExecuted):
                    w.writerow([i, offset, 0x45, m.order_ref_num, 0, m.executed_shares, 0])
                else: 
                    w.writerow([i, offset, 0x44, m.order_ref_num, 0, 0, 0])
                offset += len(frame(m))
        print(f"wrote vectors/random_{n}.bin ({sum(len(frame(m)) for m in msgs)} bytes)")
        
        stream = b"".join(frame(m) for m in msgs)

        with open(f"vectors/random_{n}.hex", "w") as f:
            for byte in stream:
                f.write(f"{byte:02x}\n")
        print(f"random_{n}: {len(msgs)} messages, {len(stream)} bytes")

        with open(f"vectors/random_{n}.types.hex", "w") as f:
            for m in msgs:
                f.write(f"{ord(m.MSG_TYPE):02x}\n")
        with open (f"vectors/random_{n}.ref.hex", "w") as f:
            for m in msgs:
                f.write(f"{m.order_ref_num:016x}\n")
        with open(f"vectors/random_{n}.side.hex", "w") as f:
            for m in msgs:
                f.write(f"{side_of(m):01x}\n")
        with open(f"vectors/random_{n}.shares.hex", "w") as f:
            for m in msgs:
                f.write(f"{shares_of(m):08x}\n")
        with open(f"vectors/random_{n}.price.hex", "w") as f:
            for m in msgs:
                f.write(f"{price_of(m):08x}\n")

        write_edge_case_vector()



def test_generated_stream_decodes():
    from model.decode import decode, unframe
    msgs = generate(100)
    for m in msgs:
        assert decode(encode(m)) == m

def test_deterministic():
    assert generate(50, seed=7) == generate(50, seed=7)



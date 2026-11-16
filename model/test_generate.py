from model.messages import AddOrder, OrderExecuted, OrderDelete
from model.encode import encode, frame
from model.decode import decode, unframe
from model.generate import generate

def test_deterministic():
    assert generate(50, seed=7) == generate(50, seed=7)

def test_different_seeds_differ():
    assert generate(50, seed=7) != generate(50, seed=8)

def test_all_round_trip():
    for m in generate(500):
        assert decode(encode(m)) == m

def test_first_message_is_add():
    assert isinstance(generate(10)[0], AddOrder)

def test_refs_exist_before_use():
    """Every execute/delete must reference an order that was added earlier"""
    live = set()
    for i, m in enumerate(generate(1000)):
        if isinstance(m, AddOrder):
            live.add(m.order_ref_num)
        else:
            assert m.order_ref_num in live, f"message {i} references unknown order"
            if isinstance(m, OrderDelete):
                live.remove(m.order_ref_num)

def test_stream_parses_sequentially():
    """Walk the framed byte stream in same way that hardware will"""
    msgs = generate(200)
    stream = b"".join(frame(m) for m in msgs)

    pos = 0
    recovered = []
    while pos < len(stream):
        length = int.from_bytes(stream[pos:pos+2], "big")
        body = stream[pos+2:pos+2+length]
        recovered.append(decode(body))
        pos += 2 + length

    assert recovered == msgs


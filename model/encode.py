import struct
from model.messages import AddOrder, OrderExecuted, OrderDelete, Side, MessageType

def encode_order_delete(msg: OrderDelete) -> bytes:
    return (
        b'D'
        + struct.pack('>HH', msg.stock_locate, msg.tracking_number)
        + encode_timestamp(msg.timestamp)
        + struct.pack('>Q', msg.order_ref_num)
    )

def encode_order_executed(msg: OrderExecuted) -> bytes:
    return (
        b'E'
        + struct.pack('>HH', msg.stock_locate, msg.tracking_number)
        + encode_timestamp(msg.timestamp)
        + struct.pack('>Q', msg.order_ref_num)
        + struct.pack('>IQ', msg.executed_shares, msg.match_number)
    )

def encode_add_order(msg: AddOrder) -> bytes:
    return (
        b'A'
        + struct.pack('>HH', msg.stock_locate, msg.tracking_number)
        + encode_timestamp(msg.timestamp)
        + struct.pack('>Q', msg.order_ref_num)
        + (b'B' if msg.buy_sell_indicator == Side.BUY else b'S')
        + struct.pack('>I', msg.shares)
        + msg.stock.ljust(8).encode('ascii') # padding stock to 8 bytes
        + struct.pack('>I', msg.price)
    )
def encode_timestamp(ts: int) -> bytes:
    """6 byte big-endian nanoseconds since midnight"""
    return struct.pack('>Q', ts)[2:]

def encode(msg) -> bytes:
    if isinstance(msg, AddOrder):       return encode_add_order(msg)
    if isinstance(msg, OrderExecuted):  return encode_order_executed(msg)
    if isinstance(msg, OrderDelete):    return encode_order_delete(msg)
    raise ValueError(f"Unsupported message type: {type(msg)}")

def frame(msg) -> bytes:
    """Framing message with 2 byte length prefix"""
    body = encode(msg)
    return struct.pack('>H', len(body)) + body

if __name__ == "__main__":
    # Manual test case
    msg = OrderDelete(1, 0, 123456789, 8472913)
    data = encode_order_delete(msg)
    print(f"length: {len(data)} (expected 19)")
    print(f"hex: {data.hex(' ')}")

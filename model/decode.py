import struct
from model.messages import AddOrder, OrderExecuted, OrderDelete, Side, MessageType

def decode_timestamp(data: bytes) -> int:
    """6 bytes big-endian -> int. Pad to 8 and then unpack"""
    return struct.unpack('>Q', b'\x00\x00' + data)[0]

def decode_order_delete(data: bytes) -> OrderDelete:
    stock_locate, tracking_number = struct.unpack_from('>HH', data, 1)
    timestamp = decode_timestamp(data[5:11])
    order_ref_num, = struct.unpack_from('>Q', data, 11)
    return OrderDelete(stock_locate, tracking_number, timestamp, order_ref_num)

def decode_order_executed(data: bytes) -> OrderExecuted:
    stock_locate, tracking_number = struct.unpack_from('>HH', data, 1)
    timestamp = decode_timestamp(data[5:11])
    order_ref_num, = struct.unpack_from('>Q', data, 11)
    executed_shares, match_number = struct.unpack_from('>IQ', data, 19)
    return OrderExecuted(stock_locate, tracking_number, timestamp, order_ref_num, executed_shares, match_number)

def decode_add_order(data: bytes) -> AddOrder:
    stock_locate, tracking_number = struct.unpack_from('>HH', data, 1)
    timestamp = decode_timestamp(data[5:11])
    order_ref_num, = struct.unpack_from('>Q', data, 11)
    side = Side(chr(data[19]))
    shares, = struct.unpack_from('>I', data, 20)
    stock = data[24:32].decode('ascii').rstrip()
    price, = struct.unpack_from('>I', data, 32)
    return AddOrder(stock_locate, tracking_number, timestamp, order_ref_num, side, shares, stock, price)

def unframe(data: bytes) -> bytes:
    """Remove 2 byte length prefix"""
    length, = struct.unpack_from('>H', data, 0)
    return data[2:2+length]

DECODERS = {
    MessageType.ADD_ORDER: decode_add_order,
    MessageType.ORDER_EXECUTED: decode_order_executed,
    MessageType.ORDER_DELETE: decode_order_delete,
}
def decode(data: bytes):
    msg_type = MessageType(chr(data[0]))
    return DECODERS[msg_type](data)

    



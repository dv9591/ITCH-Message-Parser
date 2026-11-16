from model.messages import AddOrder, OrderExecuted, OrderDelete, Side
from model.encode import encode
from model.decode import decode

def test_round_trip_delete():
    msg = OrderDelete(1, 0, 123456789, 8472913)
    assert decode(encode(msg)) == msg

def test_round_trip_executed():
    msg = OrderExecuted(1, 0, 123456789, 8472913, 100, 12345678)
    assert decode(encode(msg)) == msg

def test_round_trip_add():
    msg = AddOrder(1, 0, 123456789, 8472913, Side.BUY, 100, 'AAPL', 1234500)
    assert decode(encode(msg)) == msg



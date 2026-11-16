from model.messages import AddOrder, OrderExecuted, OrderDelete, Side
from model.encode import encode, frame
from model.decode import decode, unframe

def test_add_order_equality():
    a = AddOrder(1, 0, 123456789, 8472913, Side.BUY, 100, 'AAPL', 1234500)
    b = AddOrder(1, 0, 123456789, 8472913, Side.BUY, 100, 'AAPL', 1234500)
    assert a == b, "Both AddOrder instances should be equal"

def test_order_executed_equality():
    c = OrderExecuted(1, 0, 123456789, 8472913, 100, 12345678)
    d = OrderExecuted(1, 0, 123456789, 8472913, 100, 12345678)
    assert c == d, "Both OrderExecuted instances should be equal"

def test_order_delete_equality():
    e = OrderDelete(1, 0, 123456789, 8472913)
    f = OrderDelete(1, 0, 123456789, 8472913)
    assert e == f, "Both OrderDelete instances should be equal"

def test_different_types_not_equal():
    a = AddOrder(1, 0, 123456789, 8472913, Side.BUY, 100, 'AAPL', 1234500)
    c = OrderExecuted(1, 0, 123456789, 8472913, 100, 12345678)
    e = OrderDelete(1, 0, 123456789, 8472913)
    assert a != c
    assert c != e

def test_frame_round_trip():
    msg = OrderDelete(1, 0, 123456789, 8472913)
    assert unframe(frame(msg)) == encode(msg), "Framing and unframing should return original encoded messge"
    
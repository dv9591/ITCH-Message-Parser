"ITCH 5.0 MESSAGE DEFINITIONS - BYTE PARSER PROJECT"

from dataclasses import dataclass
from enum import Enum

class MessageType(str, Enum):
    ADD_ORDER = 'A'
    ORDER_EXECUTED = 'E'
    ORDER_DELETE = 'D'

class Side (str, Enum):
    BUY = 'B'
    SELL = 'S'

@dataclass
class AddOrder:
    "ITCH 5.0 - 'A' MESSAGE - a new resting order has been added to the book -36 bytes"
    stock_locate: int           # offset: 1, 2 bytes
    tracking_number: int        # offset: 3, 2 bytes
    timestamp: int              # offset: 5, 6 bytes
    order_ref_num: int          # offset: 11, 8 bytes
    buy_sell_indicator: Side    # offset: 19, 1 byte
    shares: int                 # offset: 20, 4 bytes
    stock: str                  # offset: 24, 8 bytes
    price: int                  # offset: 32, 4 bytes

    MSG_TYPE = MessageType.ADD_ORDER
    LENGTH = 36      # Message body only, excludes 2 length frame length prefix

@dataclass
class OrderExecuted:
   "ITCH 5.0 - 'E' MESSAGE - an order has been executed - 31 bytes"
   stock_locate: int            # offset: 1, 2 bytes
   tracking_number: int         # offset: 3, 2 bytes
   timestamp: int               # offset: 5, 6 bytes
   order_ref_num: int           # offset: 11, 8 bytes
   executed_shares: int         # offset: 19, 4 bytes
   match_number: int            # offset: 23, 8 bytes


   MSG_TYPE = MessageType.ORDER_EXECUTED
   LENGTH = 31


@dataclass
class OrderDelete:
   "ITCH 5.0 - 'D' MESSAGE - an order has been deleted - 19 bytes"
   stock_locate: int            # offset: 1, 2 bytes
   tracking_number: int         # offset: 3, 2 bytes
   timestamp: int               # offset: 5, 6 bytes
   order_ref_num: int           # offset: 11, 8 bytes


   MSG_TYPE = MessageType.ORDER_DELETE
   LENGTH = 19

MESSAGE_CLASSES = {
    MessageType.ADD_ORDER: AddOrder,
    MessageType.ORDER_EXECUTED: OrderExecuted,
    MessageType.ORDER_DELETE: OrderDelete,
}
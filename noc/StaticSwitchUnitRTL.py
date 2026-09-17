"""PyOCN switch semantics with statically indexed packet selection.

The original switch uses PyMTL's dynamically indexed Mux. After packed-array
conversion that becomes a variable part-select of the entire input packet
bus. Decode the same Encoder output against constant indices instead, while
retaining the original arbitration and val/rdy behavior.
"""

from pymtl3 import Component, clog2, update
from pymtl3.stdlib.primitive import Encoder, RoundRobinArbiterEn

from ..lib.basic.val_rdy.ifcs import RecvIfcRTL, SendIfcRTL


class StaticSwitchUnitRTL(Component):

  def construct(s, PacketType, num_inports=5):
    s.num_inports = num_inports
    s.sel_width = clog2(num_inports)

    s.recv = [RecvIfcRTL(PacketType) for _ in range(num_inports)]
    s.send = SendIfcRTL(PacketType)

    s.arbiter = RoundRobinArbiterEn(num_inports)
    # The original arbiter advances on a request even under output backpressure.
    s.arbiter.en //= 1
    s.encoder = Encoder(num_inports, s.sel_width)
    s.encoder.in_ //= s.arbiter.grants

    for i in range(num_inports):
      s.recv[i].val //= s.arbiter.reqs[i]

    @update
    def up_send_msg():
      # With no grant, Encoder outputs zero. Preserve input zero's message even
      # when send.val is low; selecting only valid/granted inputs would change it.
      s.send.msg @= s.recv[0].msg
      for i in range(1, num_inports):
        if s.encoder.out == i:
          s.send.msg @= s.recv[i].msg

    @update
    def up_send_val():
      s.send.val @= s.arbiter.grants > 0

    @update
    def up_get_en():
      for i in range(num_inports):
        s.recv[i].rdy @= s.send.rdy & (s.encoder.out == i)

  def line_trace(s):
    return "{}(){}".format("|".join(str(port) for port in s.recv), s.send)

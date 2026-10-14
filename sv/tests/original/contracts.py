"""Narrow, explicit acceptance rules for reset/invalid-payload differences.

These rules do not change stimulus, active ready/valid, or valid payloads.
Every other output, including reset-cycle handshakes, remains compared.
"""


def contract_for(case, meta):
  rules = {
    32: ('cgra_controller', ['recv_from_ctrl_ring_pkt.rdy'], 'sv/NOC_HANDSHAKES.md'),
    39: ('tile_flexible_fu_configurable', ['recv_opt.rdy'], 'sv/ARITHMETIC_BOUNDARIES.md'),
    72: ('scalar_exclusive_div', [], 'sv/ARITHMETIC_BOUNDARIES.md'),
    128: ('cgra_static_const_queue', ['send_const.val'], 'sv/STATIC_MEMORY_API.md'),
  }
  for case_id in range(137, 144):
    rules[case_id] = ('cgra_dma_engine', ['dma_cmd.rdy'], 'sv/MEMORY_BOUNDARIES.md')
  assert case['id'] in rules, 'No reviewed contract for this original case'
  module, zero, document = rules[case['id']]
  assert meta['module'] == module
  for path in zero:
    assert any(p['path'] == path and p['direction'] == 'output' for p in meta['ports'])
  return dict(name='valid_payload_and_explicit_reset', reset_zero=zero,
    activity='one_prologue_control' if case['id']==39 else 'valid_output_payload',
    invalid_payload='ignored only when matching channel valid is zero',
    all_other_outputs='strictly compared, including reset cycles', document=document)

import copy
import importlib.util
from pathlib import Path
import unittest

SV=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('control_program',SV/'tools/cgra_program.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)


def document(cols=2,rows=2,**parameters):
  return dict(schema=1,top='system',parameters=dict(CTRL_NETWORK=1,CTRL_MULTICAST=1,**parameters),
      architectures=[dict(cols=cols,rows=rows)])


def normalized(cols=2,rows=2,**parameters):
  return p.configuration.normalize(document(cols,rows,**parameters))


class ControlTools(unittest.TestCase):
  def test_profiles_rejected(self):
    for changes in [dict(CTRL_NETWORK=3),dict(CTRL_NETWORK=0),dict(NOC_LEGACY_PYTHON=1),
                    dict(HAS_DMA=1),dict(HAS_IM2COL=1)]:
      d=document();d['parameters'].update(changes)
      with self.subTest(changes=changes),self.assertRaises(p.ConfigError):p.configuration.normalize(d)
    for variant in ['context','streaming']:
      d=document();d['variant']=variant
      with self.subTest(variant=variant),self.assertRaises(p.ConfigError):p.configuration.normalize(d)
    d=document();d['top']='multi';d['parameters'].update(MULTI_COLS=2,MULTI_ROWS=2)
    with self.assertRaises(p.ConfigError):p.configuration.normalize(d)

  def test_native_numbers_are_distinct(self):
    self.assertEqual(set(p.ABI['commands'].values()),set(range(59)))
    self.assertEqual(p.COMMANDS['CTRL_MASK_WORD'],59)
    self.assertEqual(p.COMMANDS['CONFIG_MULTICAST'],60)

  def test_mask_beyond_one_data_word(self):
    c=normalized(2,17)
    doc=dict(schema=1,steps=[dict(kind='config_multicast',tiles=[0,31,32,33],address=2,ctrl=dict(operation='ADD'))])
    _,encoded,_=p.compile_program(c,doc)
    packets=[p.unpack(p.layouts(c)['host'],x) for x in encoded]
    self.assertEqual([x['payload']['cmd'] for x in packets],[59,59,60])
    self.assertEqual([x['payload']['data']['payload'] for x in packets[:2]],[(1<<31)|1,3])
    expanded=p.expand_packets(c,encoded)
    self.assertEqual([x['dst'] for x in expanded],[0,31,32,33])
    self.assertTrue(all(x['payload']['cmd']==3 and x['payload']['ctrl_addr']==2 for x in expanded))

  def test_absent_tiles_empty_duplicate_and_disabled(self):
    c=normalized(2,3,MAX_COLS=4,MAX_ROWS=3)
    for tiles in [[],[6],[0,0],[-1],[True]]:
      doc=dict(schema=1,steps=[dict(kind='config_multicast',tiles=tiles,address=0,ctrl=dict(operation='ADD'))])
      with self.subTest(tiles=tiles),self.assertRaises(p.ConfigError):p.compile_program(c,doc)
    d=document();d['parameters']['CTRL_MULTICAST']=0;c=p.configuration.normalize(d)
    with self.assertRaises(p.ConfigError):p.multicast_packets(c,[0,1],0,dict(operation='ADD'))

  def test_matching_heads_preserve_same_address_overwrites(self):
    c=normalized()
    writes=[dict(tile=t,address=0,ctrl=dict(operation=op)) for t,op in
        [(0,'ADD'),(1,'MUL'),(0,'SUB'),(1,'SUB'),(2,'ADD'),(2,'INC')]]
    doc=dict(schema=1,steps=[dict(kind='config_batch',multicast=True,writes=writes)])
    _,encoded,_=p.compile_program(c,doc)
    actual={t:[] for t in range(4)}
    for packet in p.expand_packets(c,encoded):actual[packet['dst']].append(packet['payload']['ctrl']['operation'])
    self.assertEqual(actual,{0:[2,4],1:[7,4],2:[2,3],3:[]})
    self.assertEqual(sum(p.unpack(p.layouts(c)['host'],x)['payload']['cmd']==60 for x in encoded),2)

  def test_no_merge_across_ordered_commands(self):
    c=normalized();writes=[dict(tile=t,address=0,ctrl=dict(operation='ADD')) for t in [0,1]]
    doc=dict(schema=1,steps=[dict(kind='config_batch',multicast=True,writes=writes),
      dict(kind='constants',tile=0,values=[7]),dict(kind='command',tile=0,cmd='LAUNCH'),
      dict(kind='barrier',completions=1),dict(kind='config_batch',multicast=True,writes=writes)])
    _,encoded,barriers=p.compile_program(c,doc)
    expanded=p.expand_packets(c,encoded)
    self.assertEqual([x['payload']['cmd'] for x in expanded if x['dst']==0],[3,13,0,3])
    self.assertEqual(len(barriers),1)
    host=p.layouts(c)['host']
    self.assertEqual(p.unpack(host,encoded[barriers[0]['before_packet']-1])['payload']['cmd'],0)
    self.assertEqual(p.unpack(host,encoded[barriers[0]['before_packet']])['payload']['cmd'],59)

  def test_wire_mask_validation(self):
    c=normalized(2,17)
    def packet(cmd,word=0,data=0):return p.host_command(c,cmd,data=p.data_value(data,0),address=word,
        control=dict(operation='ADD'))
    cases=[ [packet('CONFIG_MULTICAST')],
      [packet('CTRL_MASK_WORD',1,1)],
      [packet('CTRL_MASK_WORD',0,1),packet('CONFIG_MULTICAST')],
      [packet('CTRL_MASK_WORD',0,1),packet('CTRL_MASK_WORD',1,4)],
      [packet('CTRL_MASK_WORD',0,0),packet('CTRL_MASK_WORD',1,0),packet('CONFIG_MULTICAST')]]
    for packets in cases:
      with self.subTest(packets=packets),self.assertRaises(p.ConfigError):
        p.compile_program(c,dict(schema=1,packets=packets))

  def test_unicast_capability_checks(self):
    c=normalized(2,3,MAX_COLS=4,MAX_ROWS=3)
    host=p.layouts(c)['host']
    for packet in [dict(dst=6,payload=dict(cmd=3,ctrl=dict(operation=2))),
                   dict(dst=0,payload=dict(cmd=1)),
                   dict(dst=0,payload=dict(cmd=32)),
                   dict(dst=0,payload=dict(cmd=49)),
                   dict(dst=0,payload=dict(cmd=52)),
                   dict(dst=0,payload=dict(cmd=3,ctrl_addr=7,ctrl=dict(operation=2)))]:
      cc=copy.deepcopy(c)
      if packet['payload'].get('ctrl_addr')==7:cc['parameters']['CTRL_DEPTH']=6
      with self.subTest(packet=packet),self.assertRaises(p.ConfigError):
        p.compile_program(cc,dict(schema=1,packets=[packet]))


if __name__=='__main__':unittest.main()

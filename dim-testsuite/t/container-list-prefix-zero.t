# ITOUDP-5168: "list containers 0.0.0.0/0" used to fail with an SQL syntax
# error, in any layer3domain. Ancestor lookups at prefix 0 must return nothing,
# not a broken query.
$ ndcli create layer3domain two type vrf rd 0:2

$ ndcli list containers layer3domain default 0.0.0.0/0
ERROR - No containers matching '0.0.0.0/0' exist in layer3domain default
$ ndcli list containers layer3domain two 0.0.0.0/0
ERROR - No containers matching '0.0.0.0/0' exist in layer3domain two

$ ndcli create container 10.0.0.0/8 layer3domain default
INFO - Creating container 10.0.0.0/8 in layer3domain default
$ ndcli create container 10.0.0.0/8 layer3domain two
INFO - Creating container 10.0.0.0/8 in layer3domain two

$ ndcli list containers layer3domain default 0.0.0.0/0
WARNING - 0.0.0.0/0 rounded to 10.0.0.0/8 because no ipblock exists at 0.0.0.0/0 with status Container
layer3domain: default
10.0.0.0/8 (Container)
  10.0.0.0/8 (Available)
$ ndcli list containers layer3domain two 0.0.0.0/0
WARNING - 0.0.0.0/0 rounded to 10.0.0.0/8 because no ipblock exists at 0.0.0.0/0 with status Container
layer3domain: two
10.0.0.0/8 (Container)
  10.0.0.0/8 (Available)
$ ndcli list containers layer3domain default ::/0
ERROR - No containers matching '::/0' exist in layer3domain default

$ ndcli create container 0.0.0.0/0 layer3domain two
INFO - Creating container 0.0.0.0/0 in layer3domain two
$ ndcli list containers layer3domain two 0.0.0.0/0
layer3domain: two
0.0.0.0/0 (Container)
  0.0.0.0/5 (Available)
  8.0.0.0/7 (Available)
  10.0.0.0/8 (Container)
    10.0.0.0/8 (Available)
  11.0.0.0/8 (Available)
  12.0.0.0/6 (Available)
  16.0.0.0/4 (Available)
  32.0.0.0/3 (Available)
  64.0.0.0/2 (Available)
  128.0.0.0/1 (Available)

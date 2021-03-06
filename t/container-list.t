$ ndcli create container 10.0.0.0/8
INFO - Creating container 10.0.0.0/8 in layer3domain default
$ ndcli list containers
10.0.0.0/8 (Container)
  10.0.0.0/8 (Available)

$ ndcli create layer3domain one type vrf rd 0:1
$ ndcli create container 10.0.0.0/8
ERROR - A layer3domain is needed
$ ndcli create container 10.0.0.0/8 layer3domain one
INFO - Creating container 10.0.0.0/8 in layer3domain one
$ ndcli create container 11.0.0.0/8 layer3domain one
INFO - Creating container 11.0.0.0/8 in layer3domain one
$ ndcli list containers
ERROR - A layer3domain is needed
$ ndcli list containers layer3domain default
10.0.0.0/8 (Container)
  10.0.0.0/8 (Available)

$ ndcli list containers layer3domain one
10.0.0.0/8 (Container)
  10.0.0.0/8 (Available)
11.0.0.0/8 (Container)
  11.0.0.0/8 (Available)
